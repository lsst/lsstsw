# shellcheck shell=bash
#
# Collection of functions used by ~lsstsw builder
#


print_error() {
  >&2 echo -e "$@"
}


fail() {
  local code=${2:-1}
  [[ -n $1 ]] && print_error "$1"
  exit "$code"
}


config_curl() {
  # Prefer system curl; user-installed ones sometimes behave oddly
  if [[ -x /usr/bin/curl ]]; then
    CURL=${CURL:-/usr/bin/curl}
  else
    CURL=${CURL:-curl}
  fi

  # disable curl progress meter unless running under a tty -- this is intended to
  # reduce the amount of console output when running under CI
  CURL_OPTS=('-#')
  if [[ ! -t 1 ]]; then
    CURL_OPTS=('-sS')
  fi

  # curl will exit 0 on 404 without the fail flag
  CURL_OPTS+=('--fail')
}


# funcion to identify the platform
discover_platform() {
  case $(uname -s) in
    Linux*)
      case $(uname -m) in
        x86_64)
          # shellcheck disable=SC2034
          ana_platform='Linux-x86_64'
          pkg_postfix='linux-64'
          ;;
        aarch64)
          # shellcheck disable=SC2034
          ana_platform='Linux-aarch64'
          pkg_postfix='linux-aarch64'
          ;;
      esac
      ;;
    Darwin*)
      case $(uname -m) in
        x86_64)
          # shellcheck disable=SC2034
          ana_platform='MacOSX-x86_64'
          pkg_postfix='osx-64'
          ;;
	arm64)
          # shellcheck disable=SC2034
          ana_platform='MacOSX-arm64'
          pkg_postfix='osx-arm64'
          ;;
        *)
          fail "Cannot install miniconda: unsupported Darwin arch $(uname -m)"
          ;;
      esac
      ;;
    *)
      fail "Cannot install miniconda: unsupported platform $(uname -s)"
      ;;
  esac
}


# function used to deploy environment
deploy_scipipe_env() {
  echo "---------------------  Deploying environment from scipipe_conda_env, git reference: ${LSST_SPLENV_REF}"

  local conda_lockfile="conda-${pkg_postfix}.lock"

  local lock_file="${LSSTSW}/env/${ENVREF}/${conda_lockfile}"

  # conda environment reference
  local env_url="https://raw.githubusercontent.com/lsst/scipipe_conda_env/${ENVREF}/etc/"

  echo "::: conda lock file: ${lock_file}"

  if [ -e "${lock_file}" ]; then
    echo "::: conda lock file already present"
  else
    # if a branch or tag is provided, store the environment yaml inside the corresponding subfolder
    mkdir -p "${lock_file%/*}"
    echo "${env_url}/${conda_lockfile}"
    $CURL "${CURL_OPTS[@]}" -# -L \
       "${env_url}/${conda_lockfile}" \
       --output "${lock_file}"
  fi

  (
    # Install packages on which the stack is known to depend

    # conda may leave behind lock files from an uncompleted package
    # installation attempt.  These need to be cleaned up before [re]attempting
    # to install packages.
    conda clean -y --all
    ARGS=()
    ARGS+=('create')
    ARGS+=('--name' "$LSST_CONDA_ENV_NAME")
    ARGS+=('-y')
    ARGS+=("--file" "$lock_file")
    # when running under CI
    if [[ ! -t 1 ]]; then
      ARGS+=("--quiet")
    fi
    run conda "${ARGS[@]}"

    echo "Cleaning conda environment..."
    conda clean -y -a > /dev/null
    echo "done"
  )

}


run() {
  if [[ $DRYRUN == true ]]; then
    echo "$@"
  elif [[ $DEBUG == true ]]; then
    (set -x; "$@")
  else
    if [[ $VERBOSE == true ]]; then
      echo "[- -]" "$@"
    fi
    "$@"
  fi
}


print_settings() {
  local vars=(
    BUILD
    DISTRIBTAG
    DEBUG
    LSSTSW
    LSSTSW_BUILD_DIR
  )

  # print env vars prefixed with ^EUPS
  IFS=" " read -r -a eups_vars <<< "${!EUPS@}"
  vars+=("${eups_vars[@]}")

  for i in "${vars[@]}"
  do
    echo "${i}: ${!i}"
  done
}


fetch_repos.yaml() {
  local ref=${1:-main}
  local output_file=${2:-$REPOSFILE}
  local repo=${3:-$REPOSFILE_REPO}

  local baseurl="https://raw.githubusercontent.com/${repo}/${ref}"
  local output_dir
  output_dir=$(dirname "$output_file")

  if $CURL "${CURL_OPTS[@]}" -f -L "${baseurl}/etc/repos.yaml" -o "$output_file"; then
    return 0
  fi

  echo "HTTPS download failed; falling back to git clone of ${repo}@${ref}"

  (
    cd "$output_dir" || exit 1

    # Clone into same directory but with unique PID to only copy repos.yaml
    local clone_dir=".repos_clone_$$"

    if git clone --depth 1 --branch "$ref" "https://github.com/${repo}.git" "$clone_dir"; then
      if [ -f "${clone_dir}/etc/repos.yaml" ]; then
        cp "${clone_dir}/etc/repos.yaml" "$output_file"
        echo "repos.yaml successfully retrieved via git clone"
      fi
      rm -rf "$clone_dir"
    else
      echo "git clone fallback failed for ${repo}@${ref}" >&2
      return 1
    fi
  )
}
