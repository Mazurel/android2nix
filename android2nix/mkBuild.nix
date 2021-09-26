# This is a generic builder for building android SDK
# It is designed for buidling `classical` Android apps.
# It also can sign Apks for local used or debug with simple keystore
# (usage of it is discouraged for release, see android2nix/keystore.nix).
{ stdenv
, pkgs
, lib
, config
, androidComposition
, android2nix
  # User specified
, src
, pname
, deps # deps.json path
, jdk ? pkgs.jdk
, gradlePkg ? pkgs.gradle
, enableParallelBuilding ? true
, buildType ? "assembleDebug"
, nestedInAndroid ? false
, extractApks ? true
, autoSignApks ? true
, keystore ? {}
, ...
}:
let
  inherit (lib)
    toLower optionalString stringLength assertMsg
    makeLibraryPath checkEnvVarSet foldl optional optionals
    ;

  keystorePath = pkgs.callPackage ./keystore.nix {
    alias = keystore.alias or "nixStore";
    password = keystore.password or "nixPassword";
    keyPassword = keystore.keyPassword or "nixPassword";
  };

  latestBuildTools = foldl
    (acc: tools: if builtins.compareVersions acc.version tools.version == -1 then tools else acc)
    { version = ""; }
    androidComposition.build-tools;

  getBuildToolsBin = build-tools:
    "${build-tools}/libexec/android-sdk/build-tools/${build-tools.version}";

  name = "${pname}-${buildType}-android";

  android2nixGradle = android2nix.gradle {
    inherit deps androidComposition jdk gradlePkg enableParallelBuilding;
  };
in
stdenv.mkDerivation rec {
  inherit name src;

  nativeBuildInputs = with pkgs; [ bash jdk ]
  ++ optionals stdenv.isDarwin [ file gnumake ];

  # Used by the Android Gradle build script in android/build.gradle

  phases = [
    "unpackPhase"
  ]
  ++ optional autoSignApks [ "keystorePhase" ]
  ++ [
    "buildPhase"
    "installPhase"
  ]
  ++ optional autoSignApks [ "signPhase" ];

  unpackPhase = ''
    cp -ar $src/. ./
    chmod u+w -R ./
    runHook postUnpack
  '';

  postUnpack = ''
    # Copy android/ directory
    ${optionalString nestedInAndroid "cd android"}    

    mkdir -p build
    chmod -R +w .

    # Patch build.gradle and settings.gradle to use local repo
    ${android2nix.patch-maven-source}
  '';

  keystorePhase =
    ''
      ${keystorePath.shellHook}

      export KEYSTORE_PATH="$PWD/${pname}.keystore"
      cp -a --no-preserve=ownership "${keystorePath}" "$KEYSTORE_PATH"
    '';

  buildPhase =
    ''
      ${optionalString nestedInAndroid "cd android"}

      ${android2nixGradle}/bin/gradle ${buildType} || exit 1
    '';

  installPhase = ''
    mkdir -p $out
    ${if extractApks
  then
    ''find . -name "*.apk" -exec cp {} $out/ \;''
  else
    "cp -r ./* $out/"}
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
