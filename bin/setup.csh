# setup lsstsw environment
#
# source this file from your ~/.cshrc
#
# possibly blank, but can't be parsed as $_
set cmd=($_)
if ( $?0 ) then
    set source=$0
else if ( $#cmd >= 3 ) then
    set source=`pwd`/${cmd[2]}
else if (-f /usr/sbin/lsof ) then
    set source=`/usr/sbin/lsof +p $$ | grep -oE /.\*setup.csh`
endif

if ( $?source ) then
    set LSSTSW=`dirname $source`
    set LSSTSW=`dirname $LSSTSW`
endif

if ( ! $?LSSTSW ) then
    echo "error: could not figure out LSSTSW directory"
    echo '  you can specify the directory by setting $LSSTW in your ~/.cshrc'
    exit 1
endif

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
