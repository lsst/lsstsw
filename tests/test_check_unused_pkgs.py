import pytest
import sys
import os
import json

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'bin'))
from check_unused_pkgs import main, build_conda_index, build_lsst_index, scan_imports, classify_imports, transitive_closure, classify_packages, format_report


def test_main_exits_without_conda_prefix(monkeypatch):
    monkeypatch.delenv("CONDA_PREFIX", raising=False)
    monkeypatch.setattr("sys.argv", ["check_unused_pkgs.py"])
    with pytest.raises(SystemExit) as exc:
        main()
    assert exc.value.code != 0


def _write_meta(meta_dir, filename, data):
    (meta_dir / filename).write_text(json.dumps(data))


def test_build_conda_index_import_mapping(tmp_path):
    meta_dir = tmp_path / "conda-meta"
    meta_dir.mkdir()
    _write_meta(meta_dir, "numpy-1.24.0-py311h.json", {
        "name": "numpy", "version": "1.24.0",
        "depends": ["python >=3.9"],
        "files": [
            "lib/python3.11/site-packages/numpy/__init__.py",
            "lib/python3.11/site-packages/numpy/core/__init__.py",
        ]
    })
    _write_meta(meta_dir, "pillow-9.5.0-py311h.json", {
        "name": "pillow", "version": "9.5.0",
        "depends": ["python >=3.9"],
        "files": ["lib/python3.11/site-packages/PIL/__init__.py"]
    })
    _write_meta(meta_dir, "libgcc-12.0-h.json", {
        "name": "libgcc", "version": "12.0",
        "depends": [],
        "files": ["lib/libgcc_s.so.1"]
    })

    import_to_pkg, _, pkg_versions, pkg_has_python = build_conda_index(str(tmp_path))

    assert import_to_pkg["numpy"] == {"numpy"}
    assert import_to_pkg["PIL"] == {"pillow"}
    assert pkg_has_python["numpy"] is True
    assert pkg_has_python["pillow"] is True
    assert pkg_has_python["libgcc"] is False
    assert pkg_versions == {"numpy": "1.24.0", "pillow": "9.5.0", "libgcc": "12.0"}


def test_build_conda_index_dep_graph(tmp_path):
    meta_dir = tmp_path / "conda-meta"
    meta_dir.mkdir()
    _write_meta(meta_dir, "scipy-1.11.0-py311h.json", {
        "name": "scipy", "version": "1.11.0",
        "depends": [
            "numpy >=1.20,<2", "python >=3.9",
            "__glibc >=2.17", "python_abi 3.11.* *_cp311"
        ],
        "files": ["lib/python3.11/site-packages/scipy/__init__.py"]
    })

    _, pkg_deps, _, _ = build_conda_index(str(tmp_path))

    # Virtual packages must be excluded; real deps kept
    assert set(pkg_deps["scipy"]) == {"numpy", "python"}


def test_build_conda_index_skips_private_and_metadata(tmp_path):
    meta_dir = tmp_path / "conda-meta"
    meta_dir.mkdir()
    _write_meta(meta_dir, "somelib-1.0-py311h.json", {
        "name": "somelib", "version": "1.0",
        "depends": [],
        "files": [
            "lib/python3.11/site-packages/somelib/__init__.py",
            "lib/python3.11/site-packages/_private/__init__.py",
            "lib/python3.11/site-packages/somelib-1.0.dist-info/RECORD",
            "lib/python3.11/site-packages/somelib.egg-info/PKG-INFO",
            "lib/python3.11/site-packages/easy-install.pth",
        ]
    })

    import_to_pkg, _, _, _ = build_conda_index(str(tmp_path))

    assert "somelib" in import_to_pkg
    assert "_private" not in import_to_pkg
    assert "somelib-1.0.dist-info" not in import_to_pkg
    assert "somelib.egg-info" not in import_to_pkg
    assert "easy-install.pth" not in import_to_pkg


def test_build_lsst_index(tmp_path):
    # Standard LSST layout: build/<pkg>/python/lsst/<subpkg>/
    (tmp_path / "afw" / "python" / "lsst" / "afw").mkdir(parents=True)
    (tmp_path / "pipe_base" / "python" / "lsst" / "pipe").mkdir(parents=True)
    # Non-LSST package with __init__.py — should appear as bare name
    non_lsst = tmp_path / "felis_pkg" / "python" / "felis"
    non_lsst.mkdir(parents=True)
    (non_lsst / "__init__.py").write_text("")
    # Directory without __init__.py — should NOT appear
    (tmp_path / "other" / "python" / "notlsst").mkdir(parents=True)

    packages = build_lsst_index(str(tmp_path))

    assert "lsst" in packages        # bare "lsst" for depfinder collapse
    assert "lsst.afw" in packages
    assert "lsst.pipe" in packages
    assert "felis" in packages
    assert "notlsst" not in packages


def test_build_lsst_index_empty(tmp_path):
    (tmp_path / "somepkg").mkdir()
    assert build_lsst_index(str(tmp_path)) == set()


def test_scan_imports_collects_required_and_questionable(tmp_path):
    (tmp_path / "mod.py").write_text(
        "import numpy\n"
        "import os\n"
        "try:\n"
        "    import scipy\n"
        "except ImportError:\n"
        "    pass\n"
    )
    (tmp_path / "sub").mkdir()
    (tmp_path / "sub" / "other.py").write_text("import astropy\n")

    imports = scan_imports(str(tmp_path))

    assert "numpy" in imports    # required
    assert "scipy" in imports    # questionable
    assert "astropy" in imports  # required in subdirectory
    assert "os" not in imports   # builtin — excluded


def test_scan_imports_ignores_non_python(tmp_path):
    (tmp_path / "README.md").write_text("# not python")
    (tmp_path / "data.json").write_text("{}")
    assert scan_imports(str(tmp_path)) == set()


def test_classify_imports():
    import_to_pkg = {
        "numpy": {"numpy"},
        "PIL": {"pillow"},
        "sklearn": {"scikit-learn"},
        "lsst": {"lsst-ts-xml"},  # conda maps bare "lsst" to this; must be overridden
    }
    # stack_packages includes bare "lsst" (as build_lsst_index now produces)
    stack_packages = {"lsst", "lsst.afw", "lsst.pipe"}
    imports = {
        "numpy",           # → conda numpy
        "PIL",             # → conda pillow (name differs)
        "lsst",            # → LSST stack (bare, depfinder collapse — NOT lsst-ts-xml)
        "lsst.afw",        # → LSST stack (exact prefix match)
        "lsst.afw.image",  # → LSST stack (sub-module match)
        "lsst.pipe.base",  # → LSST stack (sub-module match)
        "unknown_mod",     # → unmapped
    }

    directly_required, lsst_imports, unmapped = classify_imports(
        imports, import_to_pkg, stack_packages
    )

    assert directly_required == {"numpy", "pillow"}
    assert lsst_imports == {"lsst", "lsst.afw", "lsst.afw.image", "lsst.pipe.base"}
    assert unmapped == {"unknown_mod"}
    assert "lsst-ts-xml" not in directly_required  # "lsst" must NOT map to conda
    assert "scikit-learn" not in directly_required  # sklearn not in imports


def test_transitive_closure_simple():
    pkg_deps = {"a": ["b", "c"], "b": ["d"], "c": [], "d": [], "e": ["f"], "f": []}
    result = transitive_closure({"a"}, pkg_deps)
    assert result == {"a", "b", "c", "d"}
    assert "e" not in result


def test_transitive_closure_handles_cycles():
    pkg_deps = {"a": ["b"], "b": ["a", "c"], "c": []}
    result = transitive_closure({"a"}, pkg_deps)
    assert result == {"a", "b", "c"}


def test_transitive_closure_unknown_dep_included():
    # Deps pointing to packages not in pkg_deps (e.g. virtual or missing)
    # are included in visited so BFS terminates
    pkg_deps = {"a": ["b", "ghost"], "b": []}
    result = transitive_closure({"a"}, pkg_deps)
    assert "a" in result
    assert "b" in result
    assert "ghost" in result


def test_classify_packages():
    all_required = {"numpy", "libgcc"}
    pkg_versions = {
        "numpy": "1.24",
        "pillow": "9.5",
        "libgcc": "12.0",
        "alsa-lib": "1.2",
    }
    pkg_has_python = {
        "numpy": True,
        "pillow": True,
        "libgcc": False,
        "alsa-lib": False,
    }

    definitely_unused, possibly_unused = classify_packages(
        all_required, pkg_versions, pkg_has_python
    )

    assert ("pillow", "9.5") in definitely_unused
    assert ("alsa-lib", "1.2") in possibly_unused
    # Required packages must not appear in either list
    assert not any(p == "numpy" for p, _ in definitely_unused)
    assert not any(p == "numpy" for p, _ in possibly_unused)
    assert not any(p == "libgcc" for p, _ in possibly_unused)


def test_format_report_structure():
    report = format_report(
        definitely_unused=[("alabaster", "1.0.0"), ("alembic", "1.18.4")],
        possibly_unused=[("alsa-lib", "1.2.15")],
        unmapped={"some_mod"},
        lsst_count=5,
        total_pkgs=100,
    )

    assert "=== Definitely Unused" in report
    assert "alabaster" in report
    assert "1.0.0" in report
    assert "alembic" in report
    assert "=== Possibly Unused" in report
    assert "alsa-lib" in report
    assert "=== Unmapped imports" in report
    assert "some_mod" in report
    assert "Summary:" in report
    assert "100 packages total" in report
    assert "2 definitely unused" in report
    assert "1 possibly unused" in report
    assert "1 unmapped imports" in report
    assert "5 LSST stack imports (skipped)" in report


def _extract_section(output, title):
    after = output.split(title, 1)[1]
    next_header = after.find("\n===")
    return after if next_header == -1 else after[:next_header]


def test_main_integration(tmp_path, monkeypatch, capsys):
    # --- conda-meta setup ---
    meta_dir = tmp_path / "conda-meta"
    meta_dir.mkdir()
    _write_meta(meta_dir, "numpy-1.24.0-py311h.json", {
        "name": "numpy", "version": "1.24.0",
        "depends": ["python", "openblas"],
        "files": ["lib/python3.11/site-packages/numpy/__init__.py"]
    })
    _write_meta(meta_dir, "pillow-9.5.0-py311h.json", {
        "name": "pillow", "version": "9.5.0",
        "depends": [],
        "files": ["lib/python3.11/site-packages/PIL/__init__.py"]
    })
    _write_meta(meta_dir, "libgcc-12.0-h.json", {
        "name": "libgcc", "version": "12.0",
        "depends": [],
        "files": ["lib/libgcc_s.so.1"]
    })
    _write_meta(meta_dir, "python-3.11.0-h.json", {
        "name": "python", "version": "3.11.0",
        "depends": [],
        "files": ["bin/python3.11"]
    })
    _write_meta(meta_dir, "openblas-0.3.21-h.json", {
        "name": "openblas", "version": "0.3.21",
        "depends": [],
        "files": ["lib/libopenblas.so.0"]
    })

    # --- build tree setup ---
    build_dir = tmp_path / "build"
    (build_dir / "afw" / "python" / "lsst" / "afw").mkdir(parents=True)
    (build_dir / "mystack" / "python").mkdir(parents=True)
    (build_dir / "mystack" / "python" / "module.py").write_text(
        "import numpy\nimport lsst.afw\n"
    )

    monkeypatch.setenv("CONDA_PREFIX", str(tmp_path))
    monkeypatch.setattr(
        "sys.argv", ["check_unused_pkgs.py", "--build-dir", str(build_dir)]
    )

    main()

    output = capsys.readouterr().out
    # pillow is a Python package with no importer → definitely unused
    definitely_section = _extract_section(output, "=== Definitely Unused")
    possibly_section = _extract_section(output, "=== Possibly Unused")
    assert "pillow" in definitely_section
    assert "libgcc" in possibly_section
    assert "numpy" not in definitely_section
    assert "Summary:" in output
    # openblas is a transitive dep of numpy (not directly imported) → must NOT be unused
    assert "openblas" not in possibly_section


def test_main_writes_to_file(tmp_path, monkeypatch):
    meta_dir = tmp_path / "conda-meta"
    meta_dir.mkdir()
    _write_meta(meta_dir, "numpy-1.24.0-py311h.json", {
        "name": "numpy", "version": "1.24.0",
        "depends": [],
        "files": ["lib/python3.11/site-packages/numpy/__init__.py"]
    })

    build_dir = tmp_path / "build"
    build_dir.mkdir()

    output_file = tmp_path / "report.txt"
    monkeypatch.setenv("CONDA_PREFIX", str(tmp_path))
    monkeypatch.setattr(
        "sys.argv",
        ["check_unused_pkgs.py", "--build-dir", str(build_dir), "--output", str(output_file)]
    )

    main()

    assert output_file.exists()
    content = output_file.read_text()
    assert "=== Definitely Unused" in content
    assert "Summary:" in content
    assert content.endswith("\n")


def test_build_conda_index_handles_so_extensions(tmp_path):
    meta_dir = tmp_path / "conda-meta"
    meta_dir.mkdir()
    _write_meta(meta_dir, "greenlet-2.0.2-py311h.json", {
        "name": "greenlet", "version": "2.0.2",
        "depends": [],
        "files": [
            "lib/python3.11/site-packages/greenlet.cpython-311-x86_64-linux-gnu.so",
            "lib/python3.11/site-packages/greenlet/__init__.py",
        ]
    })

    import_to_pkg, _, _, pkg_has_python = build_conda_index(str(tmp_path))

    assert import_to_pkg.get("greenlet") == {"greenlet"}
    assert "greenlet.cpython-311-x86_64-linux-gnu.so" not in import_to_pkg
    assert pkg_has_python["greenlet"] is True


def test_build_conda_index_namespace_packages_dont_overwrite(tmp_path):
    # Multiple conda packages contributing to the same top-level namespace
    # (sphinxcontrib-*, backports.*, zope.*) must all be retained — earlier
    # versions overwrote, leaving every namespace co-tenant but the last
    # alphabetically marked unused.
    meta_dir = tmp_path / "conda-meta"
    meta_dir.mkdir()
    _write_meta(meta_dir, "sphinxcontrib-applehelp-2.0.0-py.json", {
        "name": "sphinxcontrib-applehelp", "version": "2.0.0", "depends": [],
        "files": ["lib/python3.11/site-packages/sphinxcontrib/applehelp/__init__.py"]
    })
    _write_meta(meta_dir, "sphinxcontrib-htmlhelp-2.1.0-py.json", {
        "name": "sphinxcontrib-htmlhelp", "version": "2.1.0", "depends": [],
        "files": ["lib/python3.11/site-packages/sphinxcontrib/htmlhelp/__init__.py"]
    })
    _write_meta(meta_dir, "sphinxcontrib-jsmath-1.0.1-py.json", {
        "name": "sphinxcontrib-jsmath", "version": "1.0.1", "depends": [],
        "files": ["lib/python3.11/site-packages/sphinxcontrib/jsmath/__init__.py"]
    })

    import_to_pkg, _, _, _ = build_conda_index(str(tmp_path))

    # All three contributors recoverable from the bare namespace
    assert import_to_pkg["sphinxcontrib"] == {
        "sphinxcontrib-applehelp",
        "sphinxcontrib-htmlhelp",
        "sphinxcontrib-jsmath",
    }
    # Sub-namespace keys also registered for disambiguation when available
    assert import_to_pkg["sphinxcontrib.applehelp"] == {"sphinxcontrib-applehelp"}
    assert import_to_pkg["sphinxcontrib.htmlhelp"] == {"sphinxcontrib-htmlhelp"}
    assert import_to_pkg["sphinxcontrib.jsmath"] == {"sphinxcontrib-jsmath"}


def test_classify_imports_namespace_pulls_all_contributors():
    # Top-level 'sphinxcontrib' import (depfinder collapses dotted forms)
    # must mark every contributor required, not just one.
    import_to_pkg = {
        "sphinxcontrib": {"sphinxcontrib-applehelp", "sphinxcontrib-htmlhelp"},
        "sphinxcontrib.applehelp": {"sphinxcontrib-applehelp"},
        "sphinxcontrib.htmlhelp": {"sphinxcontrib-htmlhelp"},
    }
    directly_required, _, _ = classify_imports(
        {"sphinxcontrib"}, import_to_pkg, set()
    )
    assert directly_required == {"sphinxcontrib-applehelp", "sphinxcontrib-htmlhelp"}


def test_classify_imports_dotted_falls_back_to_top_level():
    # Even if depfinder ever emits a dotted form, an unknown sub should
    # fall back to the namespace-level mapping rather than going to unmapped.
    import_to_pkg = {
        "sphinxcontrib": {"sphinxcontrib-applehelp", "sphinxcontrib-htmlhelp"},
    }
    directly_required, _, unmapped = classify_imports(
        {"sphinxcontrib.applehelp"}, import_to_pkg, set()
    )
    assert directly_required == {"sphinxcontrib-applehelp", "sphinxcontrib-htmlhelp"}
    assert unmapped == set()
