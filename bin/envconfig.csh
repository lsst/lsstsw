# setup lsstsw environment
#
# source this file from your ~/.cshrc

set cmd=($_)        # possibly blank, but can't be parsed as $_
set nonPathLsof=/usr/sbin/lsof
set BUILD_ID = ""

if ( ! "$?1" ) then
  if ( "$1" == "-h" ) then
    echo "Usage: source bin/envconfig.csh [-i] [-n] [-b] [-h]" 
    echo
    echo "    -i          interactive, choose from a list of available environments"
    echo "    -n NAME     activate the environment NAME"
    echo "    -b bXXXX    activate the environment used for the build with id bXXXX"
    echo "    -h          show this message"
    echo
    exit
  else if ( "$1" == "-i" ) then
    echo "Interactive mode..."
  else if ( "$1" == "-n" ) then

    if ( "$2" != "" ) then
      set LSST_CONDA_ENV_NAME="$2"
    else
      echo No environment name provided. Use -h option to see usage.
      exit 1
    endif

  else if ( "$1" == "-b" ) then
    if ( "$2" != "" ) then
      set BUILD_ID="$2"
    else
      echo No build number provided. Use-h option to see usage.
      exit 1
    endif
  else
    echo "Wrong parameter "$1". Use -h option to see usage."
    exit 1
  endif
endif

if ( "$?0" ) then        # direct execution
  set source=$0
else if ( "$#cmd" >= 3 ) then        # direct sourcing
  set source=${cmd[2]}
else if ({ (which lsof >& /dev/null) }) then        # indirect sourcing
  set source=`lsof +p $$ | grep -oE /.\*setup.csh`
else if (-f "$nonPathLsof" ) then        # as above; lsof not always on path
  set source=`$nonPathLsof +p $$ | grep -oE /.\*setup.csh`
endif
unset cmd
unset nonPathLsof

if ( "$?source" ) then
  set LSSTSW=`dirname $source`
  set LSSTSW=`cd $LSSTSW/.. && pwd`
endif
unset source

if ( ! "$?LSSTSW" ) then
  echo "error: could not figure out LSSTSW directory"
  echo '  you can specify the directory by setting $LSSTW in your ~/.cshrc'
  exit 1
endif

if ( ! -f "$LSSTSW/eups/current/bin/setups.csh" ) then
  echo "error: eups not found in $LSSTSW/eups/current"
  echo "  you may need to [re]run bin/deploy to [re]deploy EUPS."
  exit 1
endif

setenv PATH "$LSSTSW/lfs/bin:$PATH"
setenv PATH "$LSSTSW/bin:$PATH"
rehash

source "$LSSTSW/miniconda/etc/profile.d/conda.csh"

setenv MANPATH "$LSSTSW/lfs/share/man:"

if ( $BUILD_ID != "" ) then
  echo "Retriving environment information from build" $BUILD_ID
  if ( -f "build/builds/${BUILD_ID}.env" ) then
    set LSST_CONDA_ENV_NAME=`grep 'environment_name' build/builds/"${BUILD_ID}".env | cut -f 2 -d ' '`
    echo "Activating environment $LSST_CONDA_ENV_NAME"
  else
    echo "No build found with id ${BUILD_ID}"
    exit 1
  endif
endif

if ( "$1" == "-i" ) then
  # get the list of available environments
  set env_list= ( `conda env list | grep -v "^#" | grep -v "^ " | grep -v "^base" | awk '{print $1}'` )
  echo
  @ i = 0
  @ nenvs = $#env_list 
  echo "Found" $nenvs "environment(s):"
  while ( $i < $nenvs )
    @ i++
    echo "Env." $i":" $env_list[$i]
  end
  echo
  echo "Choose Environment [1-"$nenvs"] (0 or return to EXIT)"
  set eid = 0
  set eid = $<
  echo
  if ( $eid == "" ) then
    echo "Exit."
    exit
  endif
  if ( $eid == 0 ) then
    echo "Exit."
    exit
  endif
  if ( $eid > $nenvs ) then
    echo "No envirinoment" $eid "available."
    exit
  endif
  echo "Activating environment" $env_list[$eid]
  set LSST_CONDA_ENV_NAME = ( $env_list[$eid] ) 
endif

if ( ! $?LSST_SPLENV_REF) then
   set LSST_SPLENV_REF=`cat $LSSTSW/etc/settings.cfg.sh | grep LSST_SPLENV_REF | awk '{print substr($0,36,7)}'`
endif

if ( ! $?SPLENV_BASE_NAME) then
   set SPLENV_BASE_NAME=`cat $LSSTSW/etc/settings.cfg.sh | grep SPLENV_BASE_NAME | awk -F '"' '{print $2}'`
endif

if ( ! $?LSST_CONDA_ENV_NAME ) then
  set LSST_CONDA_ENV_NAME="lsst-scipipe-$LSST_SPLENV_REF"
endif

conda activate "$LSST_CONDA_ENV_NAME"

source "$LSSTSW/eups/current/bin/setups.csh"

# definition EUPS_PATH depending on the environment:
# including the last 7 characters of the environment name
set env_ref = `echo $LSST_CONDA_ENV_NAME | awk '{print substr($0, length($0) - 6)}'`
set EUPS_PATH="$LSSTSW/stack/$env_ref"
echo "EUPS_PATH defined to ${EUPS_PATH}"

setup -r "$LSSTSW/lsst_build"

unset LSSTSW

echo "notice: lsstsw tools have been set up."

# vim: tabstop=2 shiftwidth=2 expandtab
