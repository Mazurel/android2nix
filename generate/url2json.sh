#!/usr/bin/env bash

#
# This script takes a deps.list file and builds a Nix expression
# that can be used by maven-repo-builder.nix to produce a path to
# a local Maven repository.
#

# This defines URLs of Maven repos we know about and use.

if [ "$REPOS_FILE" == "" ]; then
    declare -a REPOS=(
	# As many repos as I know
	"https://repo.maven.apache.org/maven2"
	"https://dl.google.com/dl/android/maven2"
	"https://plugins.gradle.org/m2"
	"https://jitpack.io"
	"https://repo1.maven.org/maven2"
	"https://plugins.gradle.org/m2/"
    )
else
    readarray -t REPOS < $REPOS_FILE
fi

function nix_fetch() {
    nix-prefetch-url --print-path --type sha256 "${1}" 2>/dev/null
}

function get_nix_path() { echo "${1}" | tail -n1; }
function get_nix_sha() { echo "${1}" | head -n1; }
function get_sha1() { sha1sum "${1}" | cut -d' ' -f1; }

function match_repo_url() {
    for REPO_URL in "${REPOS[@]}"; do
        if [[ "$1" == "${REPO_URL}"* ]]; then
            echo "${REPO_URL}"
            return
        fi
    done
    echo " ! Failed to match a repo for: ${1}" >&2
    exit 1
}

if [[ -z "${1}" ]]; then
    echo "Required argument not given!" >&2
    exit 1
fi

POM_URL=${1}
# Drop the POM extension
OBJ_REL_URL=${POM_URL%.pom}

REPO_URL=$(match_repo_url "${OBJ_REL_URL}")

# Get the relative path without full URL
OBJ_REL_NAME="${OBJ_REL_URL#${REPO_URL}/}"

declare -a POSSIBLE_EXTS=(
    "pom"
    "jar"
    "aar"
    "signature"
    "zip"
    "apk"
)

ANY_FOUND="n"

for EXT in "${POSSIBLE_EXTS[@]}"; do

    CURRENT_URL="${OBJ_REL_URL}.${EXT}"

    FETCHED_OBJ=$(nix_fetch "$CURRENT_URL")

    [[ ! ${?} -eq 0 ]] && continue

    OBJ_PATH=$(get_nix_path "${FETCHED_OBJ}")

    echo -en "${CLR} - Nix entry for: ${OBJ_REL_NAME}.${EXT}\r" >&2
    
    OBJ_SHA256=$(get_nix_sha "${FETCHED_OBJ}")
    OBJ_SHA1=$(get_sha1 "${OBJ_PATH}")

    if [[ $ANY_FOUND == "y" ]]; then
	echo -n ","
    else
	ANY_FOUND="y"
	# Print common part
	echo -ne "
     {
       \"path\": \"${OBJ_REL_NAME}\",
       \"host\": \"${REPO_URL}\","
    fi
    echo -ne "
       \"$EXT\": {
         \"sha1\": \"${OBJ_SHA1}\",
         \"sha256\": \"${OBJ_SHA256}\"
       }"
done

if [ "$ANY_FOUND" == "n" ]; then
    echo "Didn't found any compatible extension for $OBJ_REL_URL" >&2
    exit 1
fi

echo -e "\n     },"
