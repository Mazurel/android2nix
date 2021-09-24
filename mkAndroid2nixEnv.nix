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
  devShell = pkgs.callPackage ./devshell.nix {
    inherit reposFile devshell;
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
