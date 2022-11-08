#!/bin/bash
# shellcheck disable=SC2034

#
# Config file with environment variables used by ~lsstsw builder
#

# scipipe-conda-env reference
LSST_SPLENV_REF=${LSST_SPLENV_REF:-5.0.0}
SPLENV_BASE_NAME="lsst-scipipe"
LSST_SPLENV_REPO=${LSST_SPLENV_REPO:-https://github.com/lsst/scipipe_conda_env.git}

# top-level products
PRODUCTS='lsst_distrib qserv_distrib dax_webserv'

# change to ssh+git if push is needed
VERSIONDB_REPO=${VERSIONDB_REPO:-https://github.com/lsst/versiondb.git}
# do not set this to true unless you're the automated LSST software account
VERSIONDB_PUSH=${VERSIONDB_PUSH:-false}

#
# the settings below should rarely need changing
#

# path to the root of the lsstsw checkout
# relative to <lsstsw>/etc/
if [[ -n "$BASH_VERSION" ]]; then
  LSSTSW=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." || true; pwd)
else
  LSSTSW=$(cd "$(dirname "$0")/.." || true; pwd)
fi

# the location of source repositories
REPOSFILE_REPO=${REPOSFILE_REPO:-lsst/repos}
REPOSFILE=${REPOSFILE:-${LSSTSW}/etc/repos.yaml}

# location of the build directory
LSSTSW_BUILD_DIR=${LSSTSW_BUILD_DIR:-${LSSTSW}/build}

# location of the version repository (it should be a clone of git@github.com:lsst/versiondb.git)
VERSIONDB=${LSSTSW}/versiondb

# location of exclusions.txt file for 'lsst-build prepare' command
EXCLUSIONS=${LSSTSW}/etc/exclusions.txt

#
# exported variables
#

# repository path for 'eups distrib create'
export EUPSPKG_REPOSITORY_PATH="${LSSTSW_BUILD_DIR}/\$PRODUCT"

# use 'package' for public releases, use 'git' for development releases
export EUPSPKG_SOURCE=${EUPSPKG_SOURCE:-git}

# the location of the distribution server
export EUPS_PKGROOT=${EUPS_PKGROOT:-${LSSTSW}/distserver/production}

# defining where the miniconda is installed
miniconda_path="${LSSTSW}/miniconda"
