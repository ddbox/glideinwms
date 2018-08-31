#!/bin/sh

function help_msg {
  #filename="$(basename $0)"
  cat << EOF
$filename [options] TEST_FILES
  Runs the unit tests on TEST_FILES files in glidinwms/unittests/
$filename -a [other options]
  Run the unit tests on all the files in glidinwms/unittests/ named test_*
Runs unit tests and exit the results to standard output. Failed tests will cause also a line starting with ERROR:
  -q          Just print the unit test output
  -h          print this message
  -a          run on all unit tests (see above)
  -c          generate a coverage report while running unit tests
EOF
}

filename="$(basename $0)"
VERBOSE=yes
COVERAGE=no

while getopts ":hqac" option
do
  case "${option}"
  in
  h) help_msg; exit 0;;
  q) VERBOSE='';;
  a) LIST_FILES=yes;;
  c) COVERAGE=yes;;
  : ) echo "$filename: illegal option: -$OPTARG requires an argument" 1>&2; help_msg 1>&2; exit 1;;
  *) echo "$filename: illegal option: -$OPTARG" 1>&2; help_msg 1>&2; exit 1;;
  \?) echo "$filename: illegal option: -$OPTARG" 1>&2; help_msg 1>&2; exit 1;;
  esac
done

shift $((OPTIND-1))
# f) BRANCHES_FILE=$OPTARG;;


# Script setup
WORKSPACE=`pwd`
export GLIDEINWMS_SRC=$WORKSPACE/glideinwms


if [ ! -e  $GLIDEINWMS_SRC/build/jenkins/utils.sh ]; then
    echo "ERROR: $GLIDEINWMS_SRC/build/jenkins/utils.sh not found!"
    echo "script running in `pwd`, expects a git managed glideinwms subdirectory"
    echo "exiting"
    exit 1
fi

if ! source $GLIDEINWMS_SRC/build/jenkins/utils.sh ; then
    echo "ERROR: $GLIDEINWMS_SRC/build/jenkins/utils.sh contains errors!"
    echo "exiting"
    exit 1
fi


if [ "x$VIRTUAL_ENV" = "x" ]; then
    setup_python_venv $WORKSPACE
fi

cd $GLIDEINWMS_SRC/unittests
SOURCES="${GLIDEINWMS_SRC},${GLIDEINWMS_SRC}/factory/"
SOURCES="${SOURCES},${GLIDEINWMS_SRC}/factory/tools,${GLIDEINWMS_SRC}/frontend"
SOURCES="${SOURCES},${GLIDEINWMS_SRC}/frontend/tools,${GLIDEINWMS_SRC}/install"
SOURCES="${SOURCES},${GLIDEINWMS_SRC}/install/services,${GLIDEINWMS_SRC}/lib"
SOURCES="${SOURCES},${GLIDEINWMS_SRC}/tools,${GLIDEINWMS_SRC}/tools/lib"


# Example file lists (space separated list)
files="test_frontend.py"
files="test_frontend_element.py"
files="test_frontend.py test_frontend_element.py"

if [ -n "$LIST_FILES" ]; then
    files_list="$(ls test_*py)"
else
    files_list=$@
fi

[ "$COVERAGE" = "yes" ] && coverage erase

for file in $files_list ; do
    [ -n "$VERBOSE" ] && echo "TESTING ==========> $file"
    if [ -n "$VERBOSE" ]; then
        if [ "$COVERAGE" = "yes" ]; then
            coverage run  --source="${SOURCES}" --omit="test_*.py"  -a $file || log_nonzero_rc "$file" $?
        else
            ./$file || log_nonzero_rc "$file" $?
        fi
    else
        if [ "$COVERAGE" = "yes" ]; then
            coverage run  --source="${SOURCES}" --omit="test_*.py"  -a $file 
        else
            ./$file
        fi
    fi
done

CURR_BRANCH=$(git rev-parse --abbrev-ref HEAD)
BR_NO_SLASH=$(echo ${CURR_BRANCH} | sed -e 's/\//_/g')

if [ "$COVERAGE" = "yes" ]; then
    coverage report > ${WORKSPACE}/coverage.report.${BR_NO_SLASH}
    coverage html
    mv htmlcov ${WORKSPACE}/htmlcov.${BR_NO_SLASH}
fi

