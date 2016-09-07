# setup lsstsw environment
#
# source this file from your ~/.bashrc
#
# relative to <lsstsw>/bin/
setenv LSSTSW `pwd` #=$(cd "$(dirname "$BASH_SOURCE")/.."; pwd)

setenv PYTHONUSERBASE /Users/dreiss/lsstsw/miniconda

if ( ! -f $LSSTSW/eups/current/bin/setups.csh ) then
    echo "error: eups not found in $LSSTSW/eups/current" 1>&2
    echo "  you may need to [re]run bin/deploy to [re]deploy EUPS." 1>&2
    return
endif

setenv PATH "$LSSTSW/miniconda/bin:$PATH"
setenv PATH "$LSSTSW/lfs/bin:$PATH"
setenv PATH "$LSSTSW/bin:$PATH"
rehash

setenv MANPATH "$LSSTSW/lfs/share/man:"
setenv DYLD_LIBRARY_PATH "."

source $LSSTSW/eups/current/bin/setups.csh

setup -r $LSSTSW/lsst_build

echo "notice: lsstsw tools have been set up."
