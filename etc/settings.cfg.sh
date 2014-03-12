#
# Config file with environment variables used by ~lsstsw builder
#

# set to nonempty to prevent versiondb from being pushed upstream (useful for debugging)
# NOPUSH=1

# top-level products
export PRODUCTS="lsst_distrib git anaconda"

# use 'package' for public releases, use 'git' for development releases
export EUPSPKG_SOURCE=git

# the location of the distribution server
export EUPS_PKGROOT=/lsst/distserver/production

# the location of source repositories
BASE='git://git.lsstcorp.org/LSST'
export REPOSITORY_PATTERN="$BASE/DMS/%(product)s.git|$BASE/DMS/devenv/%(product)s.git|$BASE/DMS/testdata/%(product)s.git|$BASE/external/%(product)s.git"

# location of the build directory
export BUILDDIR=$HOME/build

# repository path for 'eups distrib create'
export EUPSPKG_REPOSITORY_PATH="$BUILDDIR"/'$PRODUCT'

# location of the EUPS stack
export EUPS_PATH=$HOME/stack

# location of the version repository (it should be a clone of git@git.lsstcorp.org/LSST/DMS/devenv/versiondb.git)
export VERSIONDB=$HOME/versiondb

# location of exclusions.txt file for 'lsst-build prepare' command
export EXCLUSIONS=$HOME/etc/exclusions.txt
