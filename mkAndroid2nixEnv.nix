{ nixpkgs, flake-utils, overlay, devshell-flake, android-devshell-module }:
{ devshell
, deps
, src ? null
, mkSrc ? null
, systems ? flake-utils.lib.defaultSystems
, ...
} @ args:
assert src == null -> mkSrc != null;
flake-utils.lib.eachSystem systems (
  system:
    let
      pkgs = import nixpkgs {
        inherit system;
        config.android_sdk.accept_license = true;
        overlays = [ devshell-flake.overlay overlay ];
      };

      src' = if src == null then (pkgs.callPackage mkSrc {}) else src;

      lib = pkgs.lib;
    in
      {
        devShell = pkgs.devshell.mkShell {
          imports = [
            android-devshell-module
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

        packages.local-maven-repo = pkgs.local-maven-repo deps;
        packages.release = pkgs.callPackage ./build.nix
          (
            {
              src = src';
              local-maven-repo = (pkgs.local-maven-repo deps);
              gradlePkg = pkgs.gradle;
              androidComposition = pkgs.androidenv.composeAndroidPackages
                (pkgs.lib.importTOML devshell).android;
            } // (
              removeAttrs args [
                "devshell"
                "deps"
                "src"
                "mkSrc"
                "systems"
              ]
            )
          );
      }
)
