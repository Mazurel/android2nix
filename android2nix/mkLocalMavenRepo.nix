# This builder creates local maven repo in the Nix store.
# It is used in android2nix.gradle.
{ stdenv, lib, pkgs, fetchurl, writeShellScriptBin, deps-path }:
let
  inherit (builtins) removeAttrs;

  inherit (lib)
    removeSuffix optionalString splitString concatMapStrings
    attrByPath attrValues last makeOverridable importJSON
    mapAttrs foldAttrs concatStringsSep
    ;

  deps = importJSON deps-path;

  # some .jar files have an `-aot` suffix that doesn't work for .pom files
  getPOM = jarUrl: "${removeSuffix "-aot" jarUrl}.pom";

  loadMavenFile = dep: ext: file:
    ''
      cp "${file.path}" "${dep.path}.${ext}"

      ${if ext == "pom" then ''
      sed -i 's|<project>|<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">|' "${dep.path}.${ext}"
      echo $(sha1sum "${dep.path}.${ext}" | cut -d " " -f 1) > "${dep.path}.${ext}.sha1"
      '' else ''
      echo "${file.sha1}" > "${dep.path}.${ext}.sha1"
      ''}
    '';

  script = writeShellScriptBin "create-local-maven-repo" (
    ''
      mkdir -p $out
      cd $out
    '' + (
      concatMapStrings (
        dep:
          let
            url = "${dep.host}/${dep.path}";
            files = removeAttrs dep [ "host" "path" ];
            files' = mapAttrs
              (
                name: value: value // {
                  path = fetchurl {
                    url = "${url}.${name}";
                    inherit (value) sha256;
                  };
                }
              ) files;

            fileName = last (splitString "/" dep.path);
            directory = removeSuffix fileName dep.path;
          in
            ''
              mkdir -p ${directory}
            '' + (
              concatStringsSep "\n"
                (
                  lib.attrsets.mapAttrsToList (loadMavenFile dep) files'
                )
            )
      ) deps
    )
  );

in
stdenv.mkDerivation {
  name = "local-maven-repo";
  buildInputs = [];
  phases = [ "buildPhase" ];
  buildPhase = "${script}/bin/create-local-maven-repo";
}
