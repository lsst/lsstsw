#!/bin/bash

#
# Config file with environment variables used by ~lsstsw builder
#

# top-level products
# shellcheck disable=SC2034
PRODUCTS='lsst_sims lsst_distrib qserv_distrib dax_webserv'

# set it to nonempty to prevent versiondb from being pushed upstream
# unless you're the automated LSST software account
if [[ $USER != 'lsstsw' || $(hostname --fqdn) != 'lsst-dev.ncsa.illinois.edu' ]]; then
    # shellcheck disable=SC2034
    NOPUSH=1
fi

#
# the settings below should rarely need changing
#

# path to the root of the lsstsw checkout
# relative to <lsstsw>/etc/
LSSTSW=$(cd "$(dirname "$BASH_SOURCE")/.."; pwd)

# the location of source repositories
# shellcheck disable=SC2034
REPOSFILE_URL='https://raw.githubusercontent.com/lsst/lsstsw/master/etc/repos.yaml'
# shellcheck disable=SC2034
REPOSFILE=${LSSTSW}/etc/repos.yaml

# location of the build directory
LSSTSW_BUILD_DIR=${LSSTSW_BUILD_DIR:-${LSSTSW}/build}

# location of the version repository (it should be a clone of git@github.com:lsst/versiondb.git)
# shellcheck disable=SC2034
VERSIONDB=${LSSTSW}/versiondb

# location of exclusions.txt file for 'lsst-build prepare' command
# shellcheck disable=SC2034
EXCLUSIONS=${LSSTSW}/etc/exclusions.txt

#
# exported variables
#

# repository path for 'eups distrib create'
# shellcheck disable=SC2016
export EUPSPKG_REPOSITORY_PATH=${LSSTSW_BUILD_DIR}/'$PRODUCT'

# location of the EUPS stack
export EUPS_PATH=${LSSTSW}/stack

# use 'package' for public releases, use 'git' for development releases
export EUPSPKG_SOURCE=${EUPSPKG_SOURCE:-git}

# the location of the distribution server
export EUPS_PKGROOT=${LSSTSW}/distserver/production
