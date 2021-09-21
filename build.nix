{ stdenv
, pkgs
, lib
, config
, patch-maven-source
, local-maven-repo
, androidComposition
  # User specified
, src
, pname
, gradlePkg ? pkgs.gradle
, enableParallelBuilding ? true
, buildType ? "assembleDebug"
, gradleOpts ? null
, nestedInAndroid ? false
, ...
}:
let
  inherit (lib)
    toLower optionalString stringLength assertMsg
    makeLibraryPath checkEnvVarSet elem foldl
    ;

  # Keystore can be provided via config and extra-sandbox-paths.
  # If it is not we use an ad-hoc one generated with default password.
  keystorePath = pkgs.callPackage ./keystore.nix {};

  latestBuildTools = foldl
    (acc: tools: if builtins.compareVersions acc.version tools.version == -1 then tools else acc)
    { version = ""; }
    androidComposition.build-tools;

  getBuildToolsBin = build-tools:
    "${build-tools}/libexec/android-sdk/build-tools/${build-tools.version}/";

  name = "${pname}-${buildType}-android";
in
stdenv.mkDerivation rec {
  inherit name src;

  buildInputs = with pkgs; [ nodejs jdk ];
  nativeBuildInputs = with pkgs; [ bash gradlePkg unzip ]
  ++ lib.optionals stdenv.isDarwin [ file gnumake ];

  # Android SDK/NDK for use by Gradle
  ANDROID_SDK_ROOT = "${androidComposition.androidsdk}/libexec/android-sdk";
  ANDROID_NDK_ROOT = "${ANDROID_SDK_ROOT}/ndk-bundle";

  JAVA_HOME = "${pkgs.jdk}";

  # Used by the Android Gradle build script in android/build.gradle

  phases = [
    "unpackPhase"
    "secretsPhase"
    "keystorePhase"
    "preBuildPatchPhase"
    "buildPhase"
    "installPhase"
    "signPhase"
  ];

  unpackPhase = ''
    cp -ar $src/. ./
    chmod u+w -R ./
    runHook postUnpack
  '';


  # TODO: Handle the case of the folder using ./android
  postUnpack = ''
    # Copy android/ directory
    ${optionalString nestedInAndroid "cd android"}    

    mkdir -p build
    chmod -R +w .

    # Patch build.gradle to use local repo
    ${patch-maven-source} ./build.gradle
  '';

  # if secretsFile is not set we use generate keystore
  secretsPhase =
    keystorePath.shellHook;

  # if keystorePath is set copy it into build directory
  keystorePhase =
    ''
      export KEYSTORE_PATH="$PWD/${pname}.keystore"
      cp -a --no-preserve=ownership "${keystorePath}" "$KEYSTORE_PATH"
    '';

  preBuildPatchPhase = ''
    # This ensures that plugins use local maven repo
    ${optionalString nestedInAndroid "cd android"}

    SETTINGS_COPY="$(cat settings.gradle)"

    echo "
    pluginManagement {
       repositories {
         mavenLocal()
       }
    }" > settings.gradle

    echo "$SETTINGS_COPY" >> settings.gradle
  '';

  buildPhase = let
    adhocEnvVars = optionalString stdenv.isLinux
      "LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${makeLibraryPath [ pkgs.zlib ]}";
  in
    ''
      # Fixes issue with failing to load libnative-platform.so
      export GRADLE_USER_HOME=$(mktemp -d)
      export ANDROID_SDK_HOME=$(mktemp -d)

      ${optionalString nestedInAndroid "cd android"}

      ${adhocEnvVars} ${gradlePkg}/bin/gradle \
        ${toString gradleOpts} \
        ${optionalString enableParallelBuilding "--parallel"} \
        --console=plain \
        --offline --stacktrace \
        -Dorg.gradle.daemon=false \
        -Dmaven.repo.local='${local-maven-repo}' \
        -Dorg.gradle.project.android.aapt2FromMavenOverride=${androidComposition.androidsdk}/libexec/android-sdk/build-tools/30.0.3/aapt2 \
        ${buildType} \
        || exit 1
    '';

  installPhase = ''
    mkdir -p $out
    find . -name "*.apk" -exec cp {} $out/ \;
  '';

  signPhase = ''
    cd $out

    for APK in $(find . -name "*.apk"); do
        BASENAME=$(basename $APK .apk)
        
         ${getBuildToolsBin latestBuildTools}/apksigner sign \
                                --verbose \
                                --ks $KEYSTORE_PATH \
                                --ks-pass pass:$KEYSTORE_PASSWORD \
                                --key-pass pass:$KEYSTORE_KEY_PASSWORD \
                                --ks-key-alias $KEYSTORE_ALIAS \
                                --out "$BASENAME"-signed.apk \
                                $APK
    done
  '';
}
