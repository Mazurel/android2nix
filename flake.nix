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

            fixupPhase = ''
            cd $out

            find . -name "build.gradle" -exec sed -i "s/classpath files('libs\/gradle-witness\.jar')//" {} \;
            find . -name "build.gradle" -exec sed -i "s/apply \(plugin\|from\): 'witness\(\.gradle\)\?'//" {} \;
            find . -name "build.gradle" -exec sed -i "s/id 'witness'//" {} \;
            # find . -name "build.gradle" -exec sed -i "s/tor 'org.briarproject:obfs4proxy-android:0.0.12-dev-40245c4a@zip'//" {} \;

            SETTINGS_COPY="$(cat settings.gradle)"

            echo "
pluginManagement {
   repositories {
     mavenLocal()
     gradlePluginPortal()
   }
}" > settings.gradle
            echo "$SETTINGS_COPY" >> settings.gradle
            '';
          };
        in
          {
            packages.src = src;
            packages.debug-keystore = pkgs.callPackage ./keystore.nix {};
            packages.gradle-deps = pkgs.gradle-deps ./deps.json;
            packages.release = pkgs.callPackage ./release.nix
              {
                inherit src;
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
