# setup lsstsw environment
#
# source this file from your ~/.bashrc
#
LSSTSW=${LSSTSW:-$HOME}

export PATH="$LSSTSW/anaconda/bin:$PATH"
export PATH="$LSSTSW/lfs/bin:$PATH"
export PATH="$LSSTSW/bin:$PATH"

export MANPATH="$LSSTSW/lfs/share/man:"

. $LSSTSW/eups/bin/setups.sh

setup -r $LSSTSW/lsst_build

echo "notice: lsstsw tools have been set up."
