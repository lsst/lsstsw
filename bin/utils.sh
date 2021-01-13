#!/bin/bash
# shellcheck disable=SC2034

#
# Collection of functions used by ~lsstsw builder
#


print_error() {
  >&2 echo -e "$@"
}


fail() {
  local code=${2:-1}
  [[ -n $1 ]] && print_error "$1"
  # shellcheck disable=SC2086
  exit $code
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
      ana_platform='Linux-x86_64'
      pkg_postfix='linux-64'
      ;;
    Darwin*)
      ana_platform='MacOSX-x86_64'
      pkg_postfix='osx-64'
      ;;
    *)
      fail "Cannot install miniconda: unsupported platform $(uname -s)"
      ;;
  esac
}


# function used to deploy environment
deploy_scipipe_env() {
  echo "---------------------  Deploying environment from scipipe_conda_env, git reference: ${LSST_SPLENV_REF}"

  local conda_bleedfile="conda3_bleed-${pkg_postfix}.yml"
  local conda_lockfile="conda-${pkg_postfix}.lock"

  local lock_file="${LSSTSW}/env/${ENVREF}/${conda_lockfile}"

  cd "$LSSTSW" || return
  # conda environment reference
  local env_url="https://raw.githubusercontent.com/lsst/scipipe_conda_env/${ENVREF}/etc/"

  # shellcheck disable=SC2154
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
    conda "${ARGS[@]}"

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

  for i in ${vars[*]}
  do
    echo "${i}: ${!i}"
  done
}


fetch_repos.yaml() {
  local ref=${1:-master}
  local output_file=${2:-$REPOSFILE}
  local repo=${3:-$REPOSFILE_REPO}

  local baseurl="https://raw.githubusercontent.com/${repo}/${ref}"

  $CURL "${CURL_OPTS[@]}" \
    -L \
    "${baseurl}/etc/repos.yaml" \
    -o "$output_file"
}
