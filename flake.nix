{
  description = "virtual environments";

  inputs.devshell.url = "github:numtide/devshell";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  inputs.briar.url = "git+https://code.briarproject.org/briar/briar.git";
  inputs.briar.flake = false;

  outputs = { self, flake-utils, devshell, nixpkgs, briar }:
    {
      overlay = final: prev: rec {
        go-maven-resolver = prev.callPackage ./go-maven-resolver {};
        aapt2 = prev.callPackage ./aapt2 {};
        patch-maven-source = prev.callPackage ./patch-maven-srcs {};
        generate = prev.callPackage ./generate { inherit go-maven-resolver; };

        gradle-deps = deps-path: final.callPackage ./gradle-deps { inherit deps-path; };
      };
    } // flake-utils.lib.eachDefaultSystem (
      system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.android_sdk.accept_license = true;
            overlays = [ devshell.overlay self.overlay ];
          };

          src = pkgs.stdenv.mkDerivation {
            pname = "briar";
            version = "x";
            src = briar;
            dontBuild = true;
            dontConfigure = true;

            installPhase = ''
            mkdir -p $out
            cp -rf ./* $out/
            '';
          };
        in
          {
            packages.debug-keystore = pkgs.callPackage ./keystore.nix {};
            packages.gradle-deps = pkgs.gradle-deps ./deps.json;
            packages.release = pkgs.callPackage ./release.nix
              {
                #inherit src;
                src = /home/mateusz/ttais/nix/briar/src;
                deps = (pkgs.gradle-deps ./deps.json);
                gradlePkg = pkgs.gradle_6;
              };

            devShell =
              pkgs.devshell.mkShell {
                imports = [ (pkgs.devshell.importTOML ./devshell.toml) ];
              };
          }
    );
}
