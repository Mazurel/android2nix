{
  description = "Use Nix to compile Android apps ";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  inputs.devshell-flake.url = "github:numtide/devshell";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, flake-utils, devshell-flake, nixpkgs }:
    let
      android-devshell-module = ./devshell-modules/android.nix;

      overlay = final: prev: rec {
        go-maven-resolver = prev.callPackage ./go-maven-resolver {};
        patch-maven-source = prev.callPackage ./patch-maven-srcs {};
        generate = prev.callPackage ./generate { inherit go-maven-resolver; };
        local-maven-repo = deps-path: final.callPackage ./local-maven-repo { inherit deps-path; };
      };
    in
      {
        lib.mkAndroid2nixEnv = import ./mkAndroid2nixEnv.nix {
          inherit nixpkgs flake-utils devshell-flake android-devshell-module overlay;
        };
      };
}
