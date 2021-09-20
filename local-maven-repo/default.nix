{ stdenv, lib, pkgs, fetchurl, writeShellScriptBin, deps-path }:
let
  inherit (builtins) removeAttrs;

  inherit (lib)
    removeSuffix optionalString splitString concatMapStrings
    attrByPath attrValues last makeOverridable importJSON
    mapAttrs foldAttrs concatStringsSep;

  deps = importJSON deps-path;

  # some .jar files have an `-aot` suffix that doesn't work for .pom files
  getPOM = jarUrl: "${removeSuffix "-aot" jarUrl}.pom";

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
                  lib.attrsets.mapAttrsToList (
                    ext: file:
                      ''
                        ${optionalString (file.path != "") ''
                        cp "${file.path}" "${dep.path}.${ext}"
                      ''}
                        ${optionalString (file.sha1 != "") ''
                        echo "${file.sha1}" > "${dep.path}.${ext}.sha1"
                      ''}''
                  ) files'
                )
            )
      ) deps
    )
  );

in
stdenv.mkDerivation {
  name = "local-maven-repo";
  buildInputs = [ ];
  phases = [ "buildPhase" "patchPhase" ];
  buildPhase = "${script}/bin/create-local-maven-repo";
}
