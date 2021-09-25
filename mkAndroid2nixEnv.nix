{ pkgs
, gradle
, androidenv
, callPackage
, lib
, android2nix
  # User defined
, devshell
, deps
, src
, reposFile ? null
, ...
} @ args:
{
  devShell = android2nix.mkDevshell {
    inherit reposFile devshell;
  };

  packages.local-maven-repo = android2nix.mkLocalMavenRepo deps;
  defaultPackage = android2nix.mkBuild (
    {
      androidComposition = androidenv.composeAndroidPackages
        (lib.importTOML devshell).android;
    } // ( args ) # Not sure if it is a safe idea, but it is easier this way
  );
}
