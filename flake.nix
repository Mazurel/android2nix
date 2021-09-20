{
  description = "virtual environments";

  inputs.devshell-flake.url = "github:numtide/devshell";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  inputs.briar.url = "git+https://code.briarproject.org/briar/briar.git";
  inputs.briar.flake = false;

  outputs = { self, flake-utils, devshell-flake, nixpkgs, briar }:
    let
      android-devshell-module = ./devshell-modules/android.nix;

      makeAndroid2nixEnv = import ./lib.nix {
        inherit nixpkgs flake-utils devshell-flake android-devshell-module;
        overlay = self.overlay;
      };
    in
      {
        overlay = final: prev: rec {
          go-maven-resolver = prev.callPackage ./go-maven-resolver {};
          patch-maven-source = prev.callPackage ./patch-maven-srcs {};
          generate = prev.callPackage ./generate { inherit go-maven-resolver; };
          local-maven-repo = deps-path: final.callPackage ./local-maven-repo { inherit deps-path; };
        };

        lib = { inherit makeAndroid2nixEnv; };
      };
}
