#!/bin/bash

# setup lsstsw environment
#
# source this file from your ~/.bashrc or ~/.zshrc
#
# relative to <lsstsw>/bin/

echo "=========================="
echo "bin/setup.sh is deprecated"
echo "Please use bin/envconfig"
echo "=========================="

if [[ -z $ZSH_NAME ]]; then
  LSSTSW=$(cd "$(dirname "${BASH_SOURCE[0]}")/.."; pwd) || return 1
else
  LSSTSW=$(cd "$(dirname "$0")/.."; pwd) || return 1
fi

echo "Sourcing bin/envconfig instead"
# shellcheck disable=SC1090
source "${LSSTSW}/bin/envconfig"

