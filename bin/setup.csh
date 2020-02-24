# setup lsstsw environment
#
# source this file from your ~/.cshrc

echo "=========================="
echo "bin/setup.csh is deprecated"
echo "Please use bin/envconfig.csh"
echo "=========================="

set cmd=($_)        # possibly blank, but can't be parsed as $_
set nonPathLsof=/usr/sbin/lsof

if ( $?0 ) then        # direct execution
  set source=$0
else if ( $#cmd >= 3 ) then        # direct sourcing
  set source=${cmd[2]}
else if ({ (which lsof >& /dev/null) }) then        # indirect sourcing
  set source=`lsof +p $$ | grep -oE /.\*setup.csh`
else if (-f $nonPathLsof ) then        # as above; lsof not always on path
  set source=`$nonPathLsof +p $$ | grep -oE /.\*setup.csh`
endif
unset cmd
unset nonPathLsof

if ( $?source ) then
  set LSSTSW=`dirname $source`
  set LSSTSW=`cd $LSSTSW/.. && pwd`
endif
unset source

if ( ! $?LSSTSW ) then
  echo "error: could not figure out LSSTSW directory"
  echo '  you can specify the directory by setting $LSSTW in your ~/.cshrc'
  exit 1
endif

echo "Sourcing bin/envconfig.csh instead"
echo
source "$LSSTSW/bin/envconfig.csh"

