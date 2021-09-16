#!/usr/bin/env bash

# Stop on any failures, including in pipes
set -e
set -o pipefail

if [[ -z "${IN_NIX_SHELL}" ]]; then
    echo "Remember to call 'make shell'!"
    exit 1
fi

# Default parameters that can be overrided by parsing
JOBS=1

# Parse arguments
while [[ ! "$@" == "" ]]; do
    case "$1" in
	--root-dir)
	    shift
	    GIT_ROOT="$1"
	    ;;
	--nested-in-android)
	    NESTED_IN_ANDROID="y"
	    ;;
	--task)
	    shift
	    GEN_TASK="$1"
	    ;;
	--repos-file)
	    shift
	    # We need to export it so that it will be available to url2json.sh
	    export REPOS_FILE="$(realpath $1)"
	    ;;
	--jobs|-j)
	    shift
	    JOBS=$1
	--help|-h)
	    echo "$0 [-(-h)elp] [--root-dir <directory>] [--nested-in-android] [--task <task>] [--repos-file <repos.txt>] [-(-j)obs <n>]"
	    echo ""
	    echo "ARGUMENTS:"
	    echo "    --root-dir - Specify directory which will be treated as root of your project"
	    echo ""
	    echo "    --nested-in-android - If this flag is set then android folder in the root of your project will be used. Otherwise, treat root of the project as android folder"
	    echo ""
	    echo "    --task - Runs specified task, availabe tasks are:"
	    echo "           * gen_proj_list"
	    echo "           * gen_deps_list"
	    echo "           * gen_deps_urls"
	    echo "           * gen_deps_json"
	    echo "             by default all of them are run from the top to bottom"
	    echo ""
	    echo "    --repos-file - txt file that contains list of maven repos to use"
	    echo ""
	    echo "    -(-j)obs - Number of parallel jobs (used when possible)"
	    echo ""
	    echo "    -(-h)elp - Show this menu"
	    echo ""
	    echo "NOTES:"
	    echo "This script loads additional dependencies (that aren't automatically loaded) from `additional-deps.list` file that has the same structure as `deps.list`. It assumes that this file is avaible in PWD."
	    exit
	    ;;
    esac
    shift
done


# Load root of the android project
[ "$GIT_ROOT" == "" ] && \
    GIT_ROOT=$(cd "${BASH_SOURCE%/*}" && git rev-parse --show-toplevel)

CUR_DIR=$(pwd)
AWK_SCRIPT="$(dirname $(realpath "$0"))/gradle_parser.awk"


# Pasted here from https://github.com/status-im/status-react/blob/develop/scripts/colors.sh
# Colors
export YLW='\033[1;33m'
export RED='\033[0;31m'
export GRN='\033[0;32m'
export BLD='\033[1m'
export RST='\033[0m'

# Clear line
export CLR='\033[2K'

# Output and input files
ADDITIONAL_DEPS_LIST="$CUR_DIR/additional-deps.list"
PROJ_LIST="$CUR_DIR/proj.list"
DEPS_LIST="$CUR_DIR/deps.list"
DEPS_URLS="$CUR_DIR/deps.urls"
DEPS_JSON="$CUR_DIR/deps.json"

# Raise limit of file descriptors
ulimit -n 16384

# These functions used used to be files
function get_deps() {
    # Run the gradle command for a project:
    # - ':buildEnvironment' to get build tools
    # - ':dependencies' to get direct deps limited those by
    #   implementation config to avoid test dependencies
    DEPS=("${@}")
    local -a BUILD_DEPS
    local -a NORMAL_DEPS
    local -a ANDROID_DEPS
    for i in "${!DEPS[@]}"; do
	# BUILD_DEPS[${i}]="${DEPS[${i}]}:buildEnvironment"
	NORMAL_DEPS[${i}]="${DEPS[${i}]}:dependencies"
	# ANDROID_DEPS[${i}]="${DEPS[${i}]}:androidDependencies"
    done

    # And clean up the output by:
    # - keep only lines that start with \--- or +---
    # - drop lines that end with (*) or (n) but don't start with (+)
    # - drop lines that refer to a project
    # - drop entries starting with `status-im:` like `status-go`
    # - drop entries that aren't just the name of the dependency
    # - extract the package name and version, ignoring version range indications,
    #   such as in `com.google.android.gms:play-services-ads:[15.0.1,16.0.0) -> 15.0.1`

    ./gradlew --no-daemon --console plain \
	"${NORMAL_DEPS[@]}" \
	"${ANDROID_DEPS[@]}" \
	"${BUILD_DEPS[@]}" \
	| awk -f ${AWK_SCRIPT}

    # Load additional deps if they exist
    [ -f "$ADDITIONAL_DEPS_LIST" ] && cat $ADDITIONAL_DEPS_LIST
}

function get_projects() {
    ./gradlew projects --no-daemon --console plain 2>&1 \
	| grep "Project ':" \
	| sed -E "s;^.--- Project '\:([@_a-zA-Z0-9\-]+)';\1;"
}

# Generate list of Gradle sub-projects.
function gen_proj_list() {
    get_projects | sort -u -o ${PROJ_LIST}
    echo -e "Found ${GRN}$(wc -l < ${PROJ_LIST})${RST} sub-projects..."
}

# Check each sub-project in parallel, the ":" is for local deps.
function gen_deps_list() {
    PROJECTS=$(cat ${PROJ_LIST})
    get_deps ":" ${PROJECTS[@]} | sort -uV -o ${DEPS_LIST}
    echo -e "${CLR}Found ${GRN}$(wc -l < ${DEPS_LIST})${RST} direct dependencies..."
}

# Find download URLs for each dependency.
function gen_deps_urls() {
    GO_MAVEN_RESOLVER_ARGS=""
    [ -f "$REPOS_FILE" ] && \
	GO_MAVEN_RESOLVER_ARGS="$GO_MAVEN_RESOLVER_ARGS -reposFile $REPOS_FILE"

    cat ${DEPS_LIST} | go-maven-resolver $GO_MAVEN_RESOLVER_ARGS | sort -uV -o ${DEPS_URLS}
    echo -e "${CLR}Found ${GRN}$(wc -l < ${DEPS_URLS})${RST} dependency URLs..."
}

# Generate the JSON that Nix will consume.
function gen_deps_json() {
    # Open the Nix attribute set.
    echo -n "[" > ${DEPS_JSON}

    # Format URLs into a Nix consumable file.
    URLS=$(cat ${DEPS_URLS})
    parallel --will-cite --keep-order \
        url2json.sh \
	--jobs $JOBS \
        ::: ${URLS} \
        >> ${DEPS_JSON}

    # Drop tailing comma on last object, stupid JSON
    sed -i '$ s/},/}/' ${DEPS_JSON}

    # Close the Nix attribute set
    echo "]" >> ${DEPS_JSON}
}

# ------------------------------------------------------------------------------
echo "Regenerating Nix files..."

# Gradle needs to be run in 'android' subfolder
[ "$NESTED_IN_ANDROID" == "y" ] && cd $GIT_ROOT/android || cd $GIT_ROOT

# Stop gradle daemons to avoid locking
./gradlew --stop >/dev/null

# Run proper tasks

if [ ! "$GEN_TASK" == "" ]; then
    echo Running "$GEN_TASK" ...
    
    $GEN_TASK
else
    # Run each stage in order
    
    echo Running stages ...

    echo Genereating project lists ...
    gen_proj_list

    echo Generating deps lists ...
    gen_deps_list

    echo Generating deps urls ...
    gen_deps_urls

    echo Generating deps json ...
    gen_deps_json

    REL_DEPS_JSON=$(realpath --relative-to=${PWD} ${DEPS_JSON})
    echo -e "${CLR}Generated Nix deps file: ${REL_DEPS_JSON#../}"
    echo -e "${GRN}Done${RST}"
fi
