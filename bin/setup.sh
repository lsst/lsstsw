# setup lsstsw environment
#
# source this file from your ~/.bashrc
#
ROOT=${ROOT:-$HOME}

export PATH="$ROOT/anaconda/bin:$PATH"
export PATH="$ROOT/lfs/bin:$PATH"
export PATH="$ROOT/bin:$PATH"

export MANPATH="$ROOT/lfs/share/man:"

. $ROOT/eups/bin/setups.sh

setup -r $ROOT/lsst_build

echo "notice: lsstsw tools have been set up."
