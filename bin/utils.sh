#!/bin/bash
# shellcheck disable=SC2034

#
# Collection of fuctions used by ~lsstsw builder
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


# expand reference depending parameters
expand_ref() {
  # parameter $1 is ENVREF
  local envref=$1

  echo "-------- Working on reference ${envref}"

  # Create safe directory name from git ref
  FIXED_ENVREF=${envref//[.\/]/-}

  if [[ $FIXED_ENVREF != '' ]]; then
    # (try to) get latest branch SHA1 and assign it to LSST_SPLENV_REF
    # if the REF is not a branch (or a tag), the reftip will be empty
    rawreftip=$(git ls-remote https://github.com/lsst/scipipe_conda_env.git ${envref})
    reftip=${rawreftip:0:7}
    reftype=$( echo "$rawreftip" | cut -f 2 -d ' ' | cut -f 2 -d'/' )
    if [ "$reftip" == '' ] || [ "$reftype" == 'tags' ]; then
        # the provided ref is not a branch
        LSST_SPLENV_REF="${envref}"
        # Defining environment name based on the provided fixed reference
        LSST_CONDA_ENV_NAME="${SPLENV_BASE_NAME}-${FIXED_ENVREF}"
        ENV_FOLDER="${FIXED_ENVREF}"
    else
        # the provided ref is a branch
        LSST_SPLENV_REF="$reftip"
        # Defining environment name based on branch and SHA1 from the tip of the branch
        LSST_CONDA_ENV_NAME="${SPLENV_BASE_NAME}-${FIXED_ENVREF}.${LSST_SPLENV_REF}"
        ENV_FOLDER="${FIXED_ENVREF}/${reftip}"
    fi
  else
    # in case no ref is given as parameter, attach the default SHA-1 to $SPLENV_BASE_NAME (lsst-scipipe)
    LSST_CONDA_ENV_NAME=${LSST_CONDA_ENV_NAME:-"${SPLENV_BASE_NAME}-${LSST_SPLENV_REF}"}
    ENV_FOLDER="${LSST_SPLENV_REF}"
  fi

  echo "Reference                  ${LSST_SPLENV_REF}"
  echo "Environment Name           ${LSST_CONDA_ENV_NAME}"
  echo "Environemnt local folder   ${ENV_FOLDER}"

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
deploy_env() {
  echo "---------------------  Deploying environment for git reference: ${LSST_SPLENV_REF}"

  local conda_bleedfile="conda3_bleed-${pkg_postfix}.yml"
  local conda_lockfile="conda-${pkg_postfix}.lock"

  local env_file="${LSSTSW}/env/${ENV_FOLDER}/${conda_bleedfile}"
  local lock_file="${LSSTSW}/env/${ENV_FOLDER}/${conda_lockfile}"

  cd "$LSSTSW"
  # conda environment reference
  local env_url="https://raw.githubusercontent.com/lsst/scipipe_conda_env/${LSST_SPLENV_REF}/etc/"

  if [[ $deploy_mode == "bleed" ]]; then
    echo "::: conda environment file: ${env_file}"
  else
    echo "::: conda lock file: ${lock_file}"
  fi

  cd env
  if [ -e "${env_file}" ]; then
    echo "::: conda environment file already present"
  else
    # if a branch or tag is provided, store the environment yaml inside the corresponding subfolder
    mkdir -p "${env_file%/*}"
    $CURL "${CURL_OPTS[@]}" -# -L \
       "${env_url}/${conda_bleedfile}" \
       --output "${env_file}"
  fi

  if [ -e "${lock_file}" ]; then
    echo "::: conda lock file already present"
  else
    # if a branch or tag is provided, store the environment yaml inside the corresponding subfolder
    mkdir -p "${lock_file%/*}"
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
    if [[ $deploy_mode == "bleed" ]]; then
      ARGS=()
      ARGS+=('env' 'update')
      ARGS+=('--name' "$LSST_CONDA_ENV_NAME")
      ARGS+=("--file" "$env_file")
    else
      ARGS=()
      ARGS+=('create')
      ARGS+=('--name' "$LSST_CONDA_ENV_NAME")
      ARGS+=('-y')
      ARGS+=("--file" "$lock_file")
    fi

    # disable the conda install progress bar when not attached to a tty. Eg.,
    # when running under CI
    if [[ ! -t 1 ]]; then
      ARGS+=("--quiet")
    fi

    conda "${ARGS[@]}"
    echo "Cleaning conda environment..."
    conda clean -y -a > /dev/null
    echo "done"
  )

  # intentionally outside of a lockfile subshell
  echo "Activating environment ${LSST_CONDA_ENV_NAME}"
  # shellcheck disable=SC1091
  conda activate "${LSST_CONDA_ENV_NAME}"

  (
    # configure alt conda channel(s)
    if [[ -n $LSST_CONDA_CHANNELS ]]; then
      # remove any previously configured non-default channels
      # XXX allowed to fail
      conda config --env --remove-key channels 2>/dev/null || true

      for c in $LSST_CONDA_CHANNELS; do
        conda config --env --add channels "$c"
      done

      conda config --env --set channel_priority strict
      echo "-------- show ------------------------------------------"
      conda config --show
      echo "-------- end show  -------------------------------------"
    fi
  )

  # check if eups is not already installed, and install it from conda
  #if ! command -v eups > /dev/null; then
  #  echo "Instaling eups from conda-forge in the active environment"
  #  conda install -y eups
  #fi

  conda deactivate

  echo "-------------------------------------------------------------."
  cd "${LSSTSW}"

}
