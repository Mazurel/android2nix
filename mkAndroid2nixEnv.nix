{ pkgs
, mkLocalMavenRepo
, gradle
, androidenv
, callPackage
  # User defined
, devshell
, deps
, src
, ...
} @ args:
let
  lib = pkgs.lib;
in
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
