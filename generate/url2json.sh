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
    IFS="\n" declare -a REPOS=$(cat "$REPOS_FILE")
fi

function nix_fetch() {
    nix-prefetch-url --print-path --type sha256 "${1}" 2>/dev/null
}

function get_nix_path() { echo "${1}" | tail -n1; }
function get_nix_sha() { echo "${1}" | head -n1; }
function get_sha1() { sha1sum "${1}" | cut -d' ' -f1; }

# Assumes REPOS from repos.sh is available
function match_repo_url() {
    for REPO_URL in "${REPOS[@]}"; do
        if [[ "$1" = ${REPO_URL}* ]]; then
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

echo -en "${CLR} - Nix entry for: ${1##*/}\r" >&2

REPO_URL=$(match_repo_url "${OBJ_REL_URL}")

if [[ -z "${REPO_URL}" ]]; then
    echo "\r\n ? REPO_URL: ${REPO_URL}" >&2
fi
# Get the relative path without full URL
OBJ_REL_NAME="${OBJ_REL_URL#${REPO_URL}/}"

OBJ_NIX_FETCH_OUT=$(nix_fetch "${OBJ_REL_URL}.jar")
# Dependency might be a JAR or an AAR
if [[ ${?} -eq 0 ]]; then
    # Some deps have only a POM, nor JAR or AAR
    OBJ_TYPE="jar"
    OBJ_PATH=$(get_nix_path "${OBJ_NIX_FETCH_OUT}")
    OBJ_SHA256=$(get_nix_sha "${OBJ_NIX_FETCH_OUT}")
    OBJ_SHA1=$(get_sha1 "${OBJ_PATH}")
else
    OBJ_NIX_FETCH_OUT=$(nix_fetch "${OBJ_REL_URL}.aar")
    if [[ ${?} -eq 0 ]]; then
        OBJ_TYPE="aar"
        OBJ_PATH=$(get_nix_path "${OBJ_NIX_FETCH_OUT}")
        OBJ_SHA256=$(get_nix_sha "${OBJ_NIX_FETCH_OUT}")
        OBJ_SHA1=$(get_sha1 "${OBJ_PATH}")
    else
        OBJ_TYPE="pom"
    fi
fi

# Sometimes dependencies may contain .signature files
# Ex. org/codehaus/mojo/signature/java16/1.1/java16-1.1
SIG_NIX_FETCH_OUT=$(nix_fetch "${OBJ_REL_URL}.signature")
if [[ ${?} -eq 0 ]]; then
    SIG_OBJ_PATH=$(get_nix_path "${SIG_NIX_FETCH_OUT}")
    SIG_OBJ_SHA256=$(get_nix_sha "${SIG_NIX_FETCH_OUT}")
    SIG_OBJ_SHA1=$(get_sha1 "${SIG_OBJ_PATH}")
fi

# Both JARs and AARs have a POM
POM_NIX_FETCH_OUT=$(nix_fetch "${OBJ_REL_URL}.pom")
POM_PATH=$(get_nix_path "${POM_NIX_FETCH_OUT}")
if [[ -z "${POM_PATH}" ]]; then
    echo " ! Failed to fetch: ${OBJ_REL_URL}.pom" >&2
    exit 1
fi
POM_SHA256=$(get_nix_sha "${POM_NIX_FETCH_OUT}")
POM_SHA1=$(get_sha1 "${POM_PATH}")

# Format into a Nix attrset entry
echo -ne "
  {
    \"path\": \"${OBJ_REL_NAME}\",
    \"host\": \"${REPO_URL}\",
    \"type\": \"${OBJ_TYPE}\","
if [[ -n "${POM_SHA256}" ]]; then
    echo -n "
    \"pom\": {
      \"sha1\": \"${POM_SHA1}\",
      \"sha256\": \"${POM_SHA256}\"
    }";
    if [[ -n "${OBJ_SHA256}" || -n "${SIG_OBJ_SHA256}" ]]; then
	echo -n ","
    fi
fi
if [[ -n "${OBJ_SHA256}" ]]; then
    echo -n "
    \"jar\": {
      \"sha1\": \"${OBJ_SHA1}\",
      \"sha256\": \"${OBJ_SHA256}\"
    }";[[ -n "${SIG_OBJ_SHA256}" ]] && echo -n ","
fi
if [[ -n "${SIG_OBJ_SHA256}" ]]; then
    echo -n "
    \"signature\": {
      \"sha1\": \"${SIG_OBJ_SHA1}\",
      \"sha256\": \"${SIG_OBJ_SHA256}\"
    }"
fi
echo -e "\n  },"
