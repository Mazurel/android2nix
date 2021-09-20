{ lib, config, pkgs, ... }:
let
  cfg = config.android;

  mkEnv = envs:
    lib.attrsets.mapAttrsToList (
      name: value: {
        inherit name value;
      }
    ) envs;
in
{
  options.android = with lib; mkOption {
    type = types.attrsOf types.anything;
    description = ''
      Android composition arguments that will be used to create composition that will be used in the user environemnt.

      For avaiable arguments, see: https://github.com/NixOS/nixpkgs/blob/master/pkgs/development/mobile/androidenv/compose-android-packages.nix
    '';
    default = {};
    example = {
      toolsVersion = "26.1.1";
      platformToolsVersion = "31.0.3";
      buildToolsVersions = [ "28.0.3" "30.0.3" ];
      platformVersions = [ "30" ];
      abiVersions = [ "armeabi-v7a" "arm64-v8a" ];
      cmakeVersions = [ "3.6.4111459" ];
      includeNDK = true;
      ndkVersions = [ "21.3.6528147" ];
      includeEmulator = false;
      includeSources = false;
      includeSystemImages = false;
      useGoogleAPIs = false;
      useGoogleTVAddOns = false;
    };
  };

  config = let
    androidComposition = pkgs.androidenv.composeAndroidPackages cfg;
  in
    {
      devshell.packages = with pkgs; [
        jdk11
        androidComposition.androidsdk
        androidComposition.platform-tools
        androidComposition
      ];

      env =
        with pkgs; mkEnv rec {
          GRADLE_OPTS =
            "-Dorg.gradle.project.android.aapt2FromMavenOverride=${androidComposition.androidsdk}/libexec/android-sdk/build-tools/30.0.3/aapt2";
          ANDROID_SDK_ROOT = "${androidComposition.androidsdk}/libexec/android-sdk";
          ANDROID_NDK_ROOT = "${ANDROID_SDK_ROOT}/ndk-bundle";
          ANDROID_JAVA_HOME = "${jdk11.home}";
          JAVA_HOME = "${jdk11.home}";
        };
    };
}
