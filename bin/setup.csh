# setup lsstsw environment
#
# source this file from your location of <lsstsw>
#
# relative to <lsstsw>/bin/
setenv LSSTSW `pwd`

if ( ! -f $LSSTSW/eups/current/bin/setups.csh ) then
    echo "error: eups not found in $LSSTSW/eups/current" 1>&2
    echo "  you may need to [re]run bin/deploy to [re]deploy EUPS." 1>&2
    exit 1
endif

setenv PATH "$LSSTSW/miniconda/bin:$PATH"
setenv PATH "$LSSTSW/lfs/bin:$PATH"
setenv PATH "$LSSTSW/bin:$PATH"
rehash

setenv MANPATH "$LSSTSW/lfs/share/man:"

source $LSSTSW/eups/current/bin/setups.csh

setup -r $LSSTSW/lsst_build

echo "notice: lsstsw tools have been set up."
