#
# Generates an ad-hoc and temporary keystore for signing debug/pr builds.
#
# WARNING: Do NOT use this to make a keystore that needs to be secret!
#          Using a derivation will store the inputs in a .drv file.
#
{ stdenv, lib, pkgs, alias, password, keyPassword }:

let
  inherit (lib) getAttr;

  # Loading defaults from gradle.properties which should be safe.
  KEYSTORE_ALIAS = alias;
  KEYSTORE_PASSWORD = password;
  KEYSTORE_KEY_PASSWORD = keyPassword;

in stdenv.mkDerivation {
  name = "android2nix-android-keystore";

  buildInputs = [ pkgs.openjdk8 ];

  phases = [ "generatePhase" ];
  generatePhase = ''
    keytool -genkey -v \
        -keyalg RSA -keysize 2048 \
        -validity 10000 \
        -dname "CN=, OU=, O=, L=, S=, C=" \
        -keystore "$out" \
        -alias "${KEYSTORE_ALIAS}" \
        -storepass "${KEYSTORE_PASSWORD}" \
        -keypass "${KEYSTORE_KEY_PASSWORD}" \
        >&2
  '';

  shellHook = ''
    export KEYSTORE_ALIAS="${KEYSTORE_ALIAS}"
    export KEYSTORE_PASSWORD="${KEYSTORE_PASSWORD}"
    export KEYSTORE_KEY_PASSWORD="${KEYSTORE_KEY_PASSWORD}"
  '';
}
