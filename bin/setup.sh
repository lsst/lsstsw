#!/bin/bash

# setup lsstsw environment
#
# source this file from your ~/.bashrc or ~/.zshrc
#
# relative to <lsstsw>/bin/
if [[ -z $ZSH_NAME ]]; then
  LSSTSW=$(cd "$(dirname "${BASH_SOURCE[0]}")/.."; pwd) || return 1
  SUFFIX=sh
else
  LSSTSW=$(cd "$(dirname "$0")/.."; pwd) || return 1
  SUFFIX=zsh
fi

if [[ ! -f "$LSSTSW/eups/current/bin/setups.$SUFFIX" ]]; then
  echo "error: eups not found in $LSSTSW/eups/current" 1>&2
  echo "  you may need to [re]run bin/deploy to [re]deploy EUPS." 1>&2
  return
fi

export PATH="$LSSTSW/miniconda/bin:$PATH"
export PATH="$LSSTSW/lfs/bin:$PATH"
export PATH="$LSSTSW/bin:$PATH"

export MANPATH="$LSSTSW/lfs/share/man:"

# shellcheck disable=SC1090
. "$LSSTSW/eups/current/bin/setups.$SUFFIX"

setup -r "$LSSTSW/lsst_build"

echo "notice: lsstsw tools have been set up."

# vim: tabstop=2 shiftwidth=2 expandtab
