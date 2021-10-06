# This script patches build.gradle and settings.gradle files to use
# our local version of Maven dependencies instead of fetching them.
{ stdenv, writeScript, runtimeShell }:
let
  patch-build-gradle = writeScript "patch-build-gradle" ''
    #!${runtimeShell}
    # Source setup.sh for substituteInPlace
    source ${stdenv}/setup

    function patchMavenSource() {
      grep "$source" $1 > /dev/null && \
        substituteInPlace $1 --replace "$2" "$3" 2>/dev/null
    }

    gradleFile="$1"

    # TODO: Consider using just `maven` in the future
    localMavenRepos='mavenLocal()'

    # Some of those find something, some don't, that's fine.
    patchMavenSource "$gradleFile" 'mavenCentral()'                       "$localMavenRepos"
    patchMavenSource "$gradleFile" 'google()'                             "$localMavenRepos"
    patchMavenSource "$gradleFile" 'jcenter()'                            "$localMavenRepos"
    patchMavenSource "$gradleFile" 'maven { url "https://jitpack.io" }'   "$localMavenRepos"
    patchMavenSource "$gradleFile" 'maven { url 'https://plugins.gradle.org/m2/' }'   "$localMavenRepos"
  '';

  patch-settings-gradle = writeScript "patch-settings-gradle" ''
    #!${runtimeShell}
    SETTINGS_COPY="$(cat $1)"

    # Enable plugin lookup inside local maven repo
    echo "
    pluginManagement {
       repositories {
         mavenLocal()
       }
    }" > $1

    echo "$SETTINGS_COPY" >> $1
  '';
in
writeScript "patch-maven-srcs" (
  ''
    #!${runtimeShell}

    find . -name "build.gradle" -exec ${patch-build-gradle} {} \;
    [ -f settings.gradle ] && ${patch-settings-gradle} settings.gradle || echo ""
  ''
)
