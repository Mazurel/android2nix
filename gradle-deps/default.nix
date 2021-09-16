{ stdenv, lib, pkgs, fetchurl, writeShellScriptBin, deps-path }:
let
  inherit (lib)
    removeSuffix optionalString splitString concatMapStrings
    attrByPath attrValues last makeOverridable importJSON;

  inherit (pkgs) aapt2;

  deps = lib.trivial.pipe deps-path
    [
      builtins.readFile
      builtins.fromJSON
    ];
  
  # some .jar files have an `-aot` suffix that doesn't work for .pom files
  getPOM = jarUrl: "${removeSuffix "-aot" jarUrl}.pom";

  script = writeShellScriptBin "create-local-maven-repo" (''
    mkdir -p $out
    cd $out
  '' +
  (concatMapStrings (dep: 
    let
      url = "${dep.host}/${dep.path}";
      pom = {
        sha1 = attrByPath [ "pom" "sha1" ] "" dep;
        sha256 = attrByPath [ "pom" "sha256" ] "" dep;
      };
      pom-download = optionalString (pom.sha256 != "") (
        fetchurl { url = getPOM url; inherit (pom) sha256; }
      );
      jar = {
        sha1 = attrByPath [ "jar" "sha1" ] "" dep;
        sha256 = attrByPath [ "jar" "sha256" ] "" dep;
      };
      jar-download = optionalString (jar.sha256 != "") (
        fetchurl { url = "${url}.${dep.type}"; inherit (jar) sha256; }
      );
      signature = {
        sha1 = attrByPath [ "signature" "sha1" ] "" dep;
        sha256 = attrByPath [ "signature" "sha256" ] "" dep;
      };
      signature-download = optionalString (signature.sha256 != "") (
        fetchurl { url = "${url}.signature"; inherit (signature) sha256; }
      );
      fileName = last (splitString "/" dep.path);
      directory = removeSuffix fileName dep.path;
    in
      ''
        mkdir -p ${directory}

        ${optionalString (pom-download != "") ''
        ln -s "${pom-download}" "${getPOM dep.path}"
        ''}
        ${optionalString (pom.sha1 != "") ''
        echo "${pom.sha1}" > "${getPOM dep.path}.sha1"
        ''}
        ${optionalString (jar-download != "") ''
        ln -s "${jar-download}" "${dep.path}.${dep.type}"
        ''}
        ${optionalString (jar.sha1 != "") ''
        echo "${jar.sha1}" > "${dep.path}.${dep.type}.sha1"
        ''}
        ${optionalString (signature-download != "") ''
        ln -s "${signature-download}" "${dep.path}.signature"
        ''}
        ${optionalString (signature.sha1 != "") ''
        echo "${signature.sha1}" > "${dep.path}.signature.sha1"
        ''}
      '')
    deps));

in stdenv.mkDerivation {
  name = "status-react-maven-deps";
  buildInputs = [ aapt2 ];
  phases = [ "buildPhase" "patchPhase" ];
  buildPhase = "${script}/bin/create-local-maven-repo";
  # Patched AAPT2 
  patchPhase = ''
    #aapt2_dir=$out/com/android/tools/build/aapt2/${aapt2.version}
    #mkdir -p $aapt2_dir
    #ln -sf ${aapt2}/* $aapt2_dir
  '';
}
