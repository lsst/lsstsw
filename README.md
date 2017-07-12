LSST Distribution Server Account
================================

[![Build Status](https://travis-ci.org/lsst/lsstsw.png)](https://travis-ci.org/lsst/lsstsw)

**`repos.yaml` has been migrated to [`lsst/repos`](https://github.com/lsst/repos).**

For a guide to using `lsstsw`, see:

http://developer.lsst.io/en/latest/build-ci/lsstsw.html

*Note: this directory is git managed.*

Structure
---------

path       | description
:----------|:-----------------------------------------------------------------
miniconda  | Anaconda Python distribution
bin        | software distribution binaries (rebuild, publish)
build      | directory where builds take place
distserver | EUPS distribution server directory
etc        | configuration files live here
eups       | local installation of EUPS
lfs        | local installation of various packages, e.g. git (lfs stands for "Linux from Scratch")
lsst_build | lsst_build software tools directory (separately git managed)
README     | the file you're reading
stack      | the EUPS software stack into which successfully built packages are installed
var        | contains lock files and log files
versiondb  | version database used by lsst_build to assign +N versions (separately git managed)

The most important directories to know about are etc (config files), stack
(the built software directory), and distserver (the distribution server
directory).

Initialization
--------------

Source bin/setup.sh to add anaconda, EUPS, git, etc. onto the path, and to
setup lsst_build tools (typically source it from ~/.bashrc).

Release workflow
----------------

Typical release workflow:

  * run `rebuild`, run acceptance checks until satisfied
  * git-tag the packages using mass-tag with the release tag
  * rerun `rebuild` with the tags
  * run `publish current`
