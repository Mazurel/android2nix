{
  description = "Use Nix to compile Android apps ";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.devshell-flake.url = "github:numtide/devshell";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, flake-utils, devshell-flake, nixpkgs }:
    let
      overlay = final: prev: (rec {
        go-maven-resolver = prev.callPackage ./go-maven-resolver {};

        android2nix = {
          # Gradle wrapper provided by android2nix
          gradle = final.callPackage ./android2nix/gradle.nix;
          # For creating android2nix devshell
          mkDevshell = final.callPackage ./android2nix/mkDevshell.nix;
          # For loading android composition from devshell
          loadAndroidComposition = devshell: final.androidenv.composeAndroidPackages
            (final.lib.importTOML devshell).android;
          # Android2nix gradle builder
          mkBuild = final.callPackage ./android2nix/mkBuild.nix;
          # Script for patching gradle source, so that it uses local maven repo
          patch-maven-source = prev.callPackage ./android2nix/patch-maven-source.nix {};
          # Android2nix generator for fetching dependencies
          generate = prev.callPackage ./generate { inherit go-maven-resolver; };
          # Builder for creating local maven repo
          mkLocalMavenRepo = deps-path: final.callPackage ./android2nix/mkLocalMavenRepo.nix { inherit deps-path; };
        };
      })
      // devshell-flake.overlay final prev;
    in
      {
        # Makes overlay available as an output
        inherit overlay;
        lib = {
          # Helper function for creating flakes that build Android apps
          mkAndroid2nixEnv = attrsetFn: flake-utils.lib.eachSystem [ "x86_64-linux" "x86_64-darwin" ] (
            system:
              let
                pkgs = import nixpkgs {
                  inherit system;
                  config.android_sdk.accept_license = true;
                  overlays = [ devshell-flake.overlay overlay ];
                };
              in
                {
                  inherit (pkgs.callPackage ./mkAndroid2nixEnv.nix (pkgs.callPackage attrsetFn {}))
                    defaultPackage packages devShell
                    ;
                }
          );
        };

        defaultTemplate = {
          path = ./template;
          description = "Getting started template for Android2nix";
        };
      };
}
