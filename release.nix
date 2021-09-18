{ stdenv
, pkgs
, lib
, config
, callPackage
, patch-maven-source
, deps
, src
, gradlePkg
,
...
}:
let
  inherit (lib)
    toLower optionalString stringLength assertMsg
    makeLibraryPath checkEnvVarSet elem
    ;

  # These will be abstracted out to builder
  pname = "briar";

  buildNumber = 9999;
  gradleOpts = null;
  # Used to detect end-to-end builds
  androidAbiInclude = "armeabi-v7a;arm64-v8a;"; # getConfig "android.abi-include" "armeabi-v7a;arm64-v8a;x86";
  # Keystore can be provided via config and extra-sandbox-paths.
  # If it is not we use an ad-hoc one generated with default password.
  keystorePath = pkgs.callPackage ./keystore.nix {};

  androidComposition = pkgs.callPackage ./android.nix {};

  baseName = "android";
  name = "${pname}-build-${baseName}";

  # There are only two types of Gradle build targets: pr and release
  gradleBuildType = "assembleDebug";
in
stdenv.mkDerivation rec {
  inherit name src;

  buildInputs = with pkgs; [ nodejs jdk ];
  nativeBuildInputs = with pkgs; [ bash gradle unzip ]
  ++ lib.optionals stdenv.isDarwin [ file gnumake ];

  # custom env variables derived from config
  ANDROID_APK_SIGNED = "true"; # getConfig "android.apk-signed" "true";
  ANDROID_ABI_SPLIT = "false"; # getConfig "android.abi-split" "false";
  ANDROID_ABI_INCLUDE = androidAbiInclude;

  # Android SDK/NDK for use by Gradle
  ANDROID_SDK_ROOT = "${androidComposition.androidsdk}/libexec/android-sdk";
  ANDROID_NDK_ROOT = "${ANDROID_SDK_ROOT}/ndk-bundle";

  JAVA_HOME = "${pkgs.jdk}";

  GRADLE_OPTS =
    "-Dorg.gradle.project.android.aapt2FromMavenOverride=${androidComposition.androidsdk}/libexec/android-sdk/build-tools/30.0.3/aapt2";

  # Used by the Android Gradle build script in android/build.gradle

  phases = [
    "unpackPhase"
    "secretsPhase"
    "keystorePhase"
    "buildPhase"
    "checkPhase"
    "installPhase"
  ];

  unpackPhase = ''
    cp -ar $src/. ./
    chmod u+w -R ./
    runHook postUnpack
  '';


  # TODO: Handle the case of the folder using ./android
  postUnpack = ''
    # Copy android/ directory
    mkdir -p build
    chmod -R +w .

    # Patch build.gradle to use local repo
    ${patch-maven-source} ./build.gradle
  '';

  # if secretsFile is not set we use generate keystore
  secretsPhase =
    #    if (secretsFile != "") then ''
    #    source "${secretsFile}"
    #    ${checkEnvVarSet "KEYSTORE_ALIAS"}
    #    ${checkEnvVarSet "KEYSTORE_PASSWORD"}
    #    ${checkEnvVarSet "KEYSTORE_KEY_PASSWORD"}
    #  ''
    #    else
    keystorePath.shellHook;

  # if keystorePath is set copy it into build directory
  keystorePhase =
    assert assertMsg (keystorePath != null) "keystorePath has to be set!";
    ''
      export KEYSTORE_PATH="$PWD/status-im.keystore"
      cp -a --no-preserve=ownership "${keystorePath}" "$KEYSTORE_PATH"
    '';
  buildPhase = let
    adhocEnvVars = optionalString stdenv.isLinux
      "LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${makeLibraryPath [ pkgs.zlib ]}";
  in
    assert ANDROID_ABI_SPLIT != null && ANDROID_ABI_SPLIT != "";
    assert stringLength ANDROID_ABI_INCLUDE > 0;
    ''
      # Fixes issue with failing to load libnative-platform.so
      export GRADLE_USER_HOME=$(mktemp -d)
      export ANDROID_SDK_HOME=$(mktemp -d)

      ${adhocEnvVars} ${gradlePkg}/bin/gradle \
        ${toString gradleOpts} \
        --console=plain \
        --offline --stacktrace \
        -Dorg.gradle.daemon=false \
        -Dmaven.repo.local='${deps}' \
        -Dorg.gradle.project.android.aapt2FromMavenOverride=${androidComposition.androidsdk}/libexec/android-sdk/build-tools/30.0.3/aapt2 \
        -PversionCode=${toString buildNumber} \
        ${gradleBuildType} \
        || exit 1
    '';
  installPhase = ''
    mkdir -p $out
    find . -name "*.apk" -exec cp {} $out/ \;
  '';
}
