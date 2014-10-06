# setup lsstsw environment
#
# source this file from your ~/.bashrc
#
LSSTSW=${LSSTSW:-$HOME}

if [[ ! -f $LSSTSW/eups/current/bin/setups.sh ]]; then
    echo "error: eups not found in $LSSTSW/eups/current" 1>&2
    echo "verify \$LSSTSW points to the directory where lsstsw has been cloned," 1>&2
    echo "  or rerun bin/deploy to redeploy EUPS." 1>&2
    return
fi

export PATH="$LSSTSW/anaconda/bin:$PATH"
export PATH="$LSSTSW/lfs/bin:$PATH"
export PATH="$LSSTSW/bin:$PATH"

export MANPATH="$LSSTSW/lfs/share/man:"

. $LSSTSW/eups/current/bin/setups.sh

setup -r $LSSTSW/lsst_build

echo "notice: lsstsw tools have been set up."
