{ pkgs
, mkLocalMavenRepo
, gradle
, androidenv
, callPackage
, lib
  # User defined
, devshell
, deps
, src
, reposFile ? null
, ...
} @ args:
{
  devShell = pkgs.devshell.mkShell {
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
        command = "generate.sh $@";
        help = "Generate all android2nix files";
      }
      {
        name = "predefined-generate";
        command = ''
        generate.sh \
                    ${lib.optionalString (reposFile != null) "--repos-file ${reposFile}"} \
                    ${lib.optionalString (args.nestedInAndroid or false) "--nested-in-android"} \
                    $@
        '';
        help = "Call `generate` with predefined settings based on you flake.nix";
      }
    ];
  };

  packages.local-maven-repo = mkLocalMavenRepo deps;
  defaultPackage = callPackage ./build.nix
    (
      {
        local-maven-repo = (mkLocalMavenRepo deps);
        androidComposition = androidenv.composeAndroidPackages
          (lib.importTOML devshell).android;
      } // (
        removeAttrs args [
          "devshell"
          "deps"
          "systems"
        ]
      )
    );
}
