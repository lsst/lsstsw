#!/usr/bin/env python3
"""Audit the active rubin-env conda environment for unused packages."""

import argparse
import json
import os
import re
import sys
from collections import deque
from pathlib import Path


SITE_PKG_RE = re.compile(r'lib/python[^/]+/site-packages/([^/]+)')
VIRTUAL_PKG_PREFIXES = ('__', 'python_abi')


def build_conda_index(conda_prefix):
    """Parse conda-meta JSONs and return (import_to_pkg, pkg_deps, pkg_versions, pkg_has_python).

    import_to_pkg: {python_import_name: set[conda_pkg_name]}
                   Sets, not single values, because namespace packages
                   (sphinxcontrib-*, backports.*, zope.*, ...) have many
                   conda packages contributing to the same top-level dir.
    pkg_deps:      {conda_pkg_name: [direct_dep_pkg_names]}
    pkg_versions:  {conda_pkg_name: version_string}
    pkg_has_python:{conda_pkg_name: bool}
    """
    meta_dir = Path(conda_prefix) / "conda-meta"
    import_to_pkg = {}
    pkg_deps = {}
    pkg_versions = {}
    pkg_has_python = {}

    for json_path in sorted(meta_dir.glob("*.json")):
        with open(json_path) as f:
            data = json.load(f)

        name = data["name"]
        pkg_versions[name] = data.get("version", "")

        has_python = False
        for file_path in data.get("files", []):
            m = SITE_PKG_RE.match(file_path)
            if not m:
                continue
            import_name = m.group(1)
            if import_name.endswith(".py"):
                import_name = import_name[:-3]
            elif "." in import_name and import_name.endswith((".so", ".pyd")):
                import_name = import_name.split(".")[0]
            if (import_name.startswith("_")
                    or import_name.endswith((".dist-info", ".egg-info", ".pth"))):
                continue
            has_python = True
            import_to_pkg.setdefault(import_name, set()).add(name)

            # Also register namespace.subpackage so dotted forms like
            # 'sphinxcontrib.applehelp' map to the correct specific conda
            # package when depfinder emits them.
            parts = file_path.split("/")
            if len(parts) >= 5:
                sub = parts[4]
                if (not sub.startswith("_")
                        and not sub.endswith((".py", ".so", ".pyd",
                                              ".dist-info", ".egg-info", ".pth"))):
                    import_to_pkg.setdefault(f"{import_name}.{sub}", set()).add(name)

        pkg_has_python[name] = has_python

        deps = []
        for dep_str in data.get("depends", []):
            dep_name = dep_str.split()[0]
            if dep_name.startswith(VIRTUAL_PKG_PREFIXES):
                continue
            deps.append(dep_name)
        pkg_deps[name] = deps

    return import_to_pkg, pkg_deps, pkg_versions, pkg_has_python


def build_lsst_index(build_dir):
    """Return set of package names/prefixes belonging to the build-tree stack.

    Includes:
    - "lsst" (bare) when any lsst subpackages exist, because depfinder collapses
      all lsst.* imports down to the single token "lsst"
    - "lsst.X" for each subdirectory under build/*/python/lsst/
    - Top-level name for any non-lsst package under build/*/python/<name>/__init__.py
    """
    packages = set()
    build_path = Path(build_dir)
    if not build_path.is_dir():
        return packages
    for pkg_dir in build_path.iterdir():
        python_path = pkg_dir / "python"
        if not python_path.is_dir():
            continue
        for sub in python_path.iterdir():
            if not sub.is_dir():
                continue
            if sub.name == "lsst":
                for lsst_sub in sub.iterdir():
                    if lsst_sub.is_dir():
                        packages.add("lsst")  # depfinder collapses lsst.* → "lsst"
                        packages.add(f"lsst.{lsst_sub.name}")
            elif (sub / "__init__.py").exists():
                packages.add(sub.name)
    return packages


def scan_imports(build_dir):
    """Walk build_dir, return set of all required+questionable import names."""
    from depfinder.inspection import get_imported_libs

    imports = set()
    skipped = 0
    for root, dirs, files in os.walk(build_dir):
        dirs[:] = [d for d in dirs if not d.startswith(".")]
        for fname in files:
            if not fname.endswith(".py"):
                continue
            filepath = os.path.join(root, fname)
            try:
                code = Path(filepath).read_text(errors="replace")
                info = get_imported_libs(code).describe()
            except Exception:
                skipped += 1
                continue
            imports.update(info.get("required", set()))
            imports.update(info.get("questionable", set()))
    if skipped:
        print(f"Warning: skipped {skipped} files due to parse errors", file=sys.stderr)
    return imports


def classify_imports(imports, import_to_pkg, stack_packages):
    """Partition imports into (directly_required conda pkgs, lsst_imports, unmapped).

    Stack-package check runs before the conda lookup so that "lsst" (which
    depfinder emits for every lsst.* import) is caught here rather than being
    mapped to whichever conda package happens to own a lsst/ namespace entry.

    directly_required: set of conda package names
    lsst_imports:      set of import strings matched to build-tree stack packages
    unmapped:          set of import strings with no known source
    """
    directly_required = set()
    lsst_imports = set()
    unmapped = set()

    for imp in imports:
        if any(imp == pkg or imp.startswith(pkg + ".") for pkg in stack_packages):
            lsst_imports.add(imp)
        elif imp in import_to_pkg:
            directly_required.update(import_to_pkg[imp])
        elif (top := imp.split(".", 1)[0]) in import_to_pkg:
            # Depfinder usually collapses dotted imports to top-level. If a
            # namespace (e.g. 'sphinxcontrib') has multiple conda contributors,
            # mark them all required — we can't tell from a top-level import
            # which sub was actually used, so over-approximate.
            directly_required.update(import_to_pkg[top])
        else:
            unmapped.add(imp)

    return directly_required, lsst_imports, unmapped


def transitive_closure(seeds, pkg_deps):
    """Return all packages reachable from seeds via pkg_deps (BFS)."""
    visited = set()
    queue = deque(seeds)
    while queue:
        pkg = queue.popleft()
        if pkg in visited:
            continue
        visited.add(pkg)
        for dep in pkg_deps.get(pkg, []):
            if dep not in visited:
                queue.append(dep)
    return visited


def classify_packages(all_required, pkg_versions, pkg_has_python):
    """Return (definitely_unused, possibly_unused) as sorted lists of (name, version) tuples.

    definitely_unused: has Python site-packages content, not required
    possibly_unused:   no Python content (C libs etc.), not required
    """
    definitely_unused = []
    possibly_unused = []

    for pkg, version in sorted(pkg_versions.items()):
        if pkg in all_required:
            continue
        if pkg_has_python.get(pkg, False):
            definitely_unused.append((pkg, version))
        else:
            possibly_unused.append((pkg, version))

    return sorted(definitely_unused), sorted(possibly_unused)


def format_report(definitely_unused, possibly_unused, unmapped, lsst_count, total_pkgs):
    """Render the three-section audit report as a string."""
    lines = []

    lines.append("=== Definitely Unused (Python packages, no importer found) ===")
    for pkg, ver in sorted(definitely_unused):  # defensive sort; inputs may not be pre-sorted
        lines.append(f"  {pkg:<45} {ver}")
    lines.append("")

    lines.append("=== Possibly Unused (non-Python / unverifiable) ===")
    for pkg, ver in sorted(possibly_unused):
        lines.append(f"  {pkg:<45} {ver}")
    lines.append("")

    lines.append("=== Unmapped imports (depfinder found these but no conda package matched) ===")
    for imp in sorted(unmapped):
        lines.append(f"  {imp}")
    lines.append("")

    lines.append(
        f"Summary: {total_pkgs} packages total"
        f" | {len(definitely_unused)} definitely unused"
        f" | {len(possibly_unused)} possibly unused"
        f" | {len(unmapped)} unmapped imports"
        f" | {lsst_count} LSST stack imports (skipped)"
    )

    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(
        description="Audit rubin-env for unused conda packages."
    )
    parser.add_argument(
        "--build-dir", default="./build",
        help="Path to lsstsw build/ directory (default: ./build)"
    )
    parser.add_argument(
        "--output", default="-",
        help="Output file path, or - for stdout (default: -)"
    )
    args = parser.parse_args()

    conda_prefix = os.environ.get("CONDA_PREFIX")
    if not conda_prefix:
        print(
            "Error: $CONDA_PREFIX is not set. Activate the rubin-env first.",
            file=sys.stderr
        )
        sys.exit(1)

    build_path = Path(args.build_dir)
    if not build_path.is_dir():
        print(f"Error: build directory not found: {args.build_dir}", file=sys.stderr)
        sys.exit(1)

    meta_dir = Path(conda_prefix) / "conda-meta"
    if not meta_dir.is_dir():
        print(
            f"Error: {conda_prefix}/conda-meta not found. "
            "Is CONDA_PREFIX pointing to a conda environment?",
            file=sys.stderr
        )
        sys.exit(1)

    print(f"Scanning imports in {args.build_dir} ...", file=sys.stderr)
    imports = scan_imports(args.build_dir)

    print("Indexing conda-meta...", file=sys.stderr)
    import_to_pkg, pkg_deps, pkg_versions, pkg_has_python = build_conda_index(conda_prefix)

    print("Indexing LSST build tree...", file=sys.stderr)
    stack_packages = build_lsst_index(args.build_dir)

    print("Classifying imports...", file=sys.stderr)
    directly_required, lsst_imports, unmapped = classify_imports(
        imports, import_to_pkg, stack_packages
    )

    print("Computing transitive closure...", file=sys.stderr)
    all_required = transitive_closure(directly_required, pkg_deps)

    print("Classifying packages...", file=sys.stderr)
    definitely_unused, possibly_unused = classify_packages(
        all_required, pkg_versions, pkg_has_python
    )

    report = format_report(
        definitely_unused=definitely_unused,
        possibly_unused=possibly_unused,
        unmapped=unmapped,
        lsst_count=len(lsst_imports),
        total_pkgs=len(pkg_versions),
    )

    if args.output == "-":
        print(report)
    else:
        Path(args.output).write_text(report + "\n")
        print(f"Report written to {args.output}", file=sys.stderr)


if __name__ == "__main__":
    main()
