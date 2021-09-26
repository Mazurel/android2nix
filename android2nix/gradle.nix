# This derivation creates gradle wrapper that uses
# local maven repository, created by `android2nix.generate`
# and can be used for declarative android apks building.
{ stdenv
, pkgs
, lib
, config
, writeScriptBin
, android2nix
  # User specified
, androidComposition
, deps # deps.json path
, jdk ? pkgs.jdk
, gradlePkg ? pkgs.gradle
, enableParallelBuilding ? true
}:
let
  inherit (lib)
    toLower optionalString makeLibraryPath
    makeBinPath foldl optional
  ;

  latestBuildTools = foldl
    (acc: tools: if builtins.compareVersions acc.version tools.version == -1 then tools else acc)
    { version = ""; }
    androidComposition.build-tools;

  getBuildToolsBin = build-tools:
    "${build-tools}/libexec/android-sdk/build-tools/${build-tools.version}";
in
writeScriptBin "gradle" ''
  export PATH="${makeBinPath (with pkgs; [ jdk bash gradlePkg unzip file gnumake ])}$PATH"
  export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${makeLibraryPath [ pkgs.zlib ]}

  export ANDROID_SDK_ROOT="${androidComposition.androidsdk}/libexec/android-sdk"
  export ANDROID_NDK_ROOT="$ANDROID_SDK_ROOT/ndk-bundle"
  export JAVA_HOME="${jdk}"

  # Fixes issue with failing to load libnative-platform.so
  export GRADLE_USER_HOME=$(mktemp -d)
  export ANDROID_SDK_HOME=$(mktemp -d)

  ${gradlePkg}/bin/gradle \
            ${optionalString enableParallelBuilding "--parallel"} \
            --console=plain \
            --offline --stacktrace \
            -Dorg.gradle.java.home="${jdk}" \
            -Dorg.gradle.daemon=false \
            -Dmaven.repo.local='${android2nix.mkLocalMavenRepo deps}' \
            -Dorg.gradle.project.android.aapt2FromMavenOverride=${getBuildToolsBin latestBuildTools}/aapt2 \
            $@
''
