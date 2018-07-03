#!/bin/bash

set -eo pipefail

( set -eo pipefail
  cd tests
  make
)

docker run -ti \
  -v"$(pwd):$(pwd)" -w "$(pwd)" \
  -e MODE="$MODE" \
  lsstsw-testenv:latest bash -lc ./tests/acceptance.sh

# vim: tabstop=2 shiftwidth=2 expandtab
