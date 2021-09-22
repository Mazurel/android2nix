{
  description = "Use Nix to compile Android apps ";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  inputs.devshell-flake.url = "github:numtide/devshell";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, flake-utils, devshell-flake, nixpkgs }:
    let
      overlay = final: prev: rec {
        go-maven-resolver = prev.callPackage ./go-maven-resolver {};
        patch-maven-source = prev.callPackage ./patch-maven-srcs {};
        generate = prev.callPackage ./generate { inherit go-maven-resolver; };
        mkLocalMavenRepo = deps-path: final.callPackage ./local-maven-repo { inherit deps-path; };
      };
    in
      {
        lib.mkAndroid2nixEnv = attrsetFn: flake-utils.lib.eachDefaultSystem (
          system:
            let
              pkgs = import nixpkgs {
                inherit system;
                config.android_sdk.accept_license = true;
                overlays = [ devshell-flake.overlay overlay ];
              };
            in
              pkgs.callPackage ./mkAndroid2nixEnv.nix (pkgs.callPackage attrsetFn { })
        );
      };
}
