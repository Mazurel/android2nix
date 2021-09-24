{ pkgs, lib, reposFile, devshell, ... } @ args:
pkgs.devshell.mkShell {
  imports = [
    ./devshell-modules/android.nix
    (pkgs.devshell.importTOML devshell)
  ];
  devshell = {
    name = lib.mkDefault "android2nix";

    packages = [
      "generate"
      "go-maven-resolver"
    ];
  };

  android = {};

  commands = [
    {
      name = "generate";
      command = ''
        generate.sh \
                    ${lib.optionalString (reposFile != null) "--repos-file ${reposFile}"} \
                    ${lib.optionalString (args.nestedInAndroid or false) "--nested-in-android"} \
                    $@
      '';
      help = "Generate all android2nix files";
    }
  ];
}
