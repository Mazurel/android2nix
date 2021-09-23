{
  description = "Example description";

  inputs.android2nix.url = "github:Mazurel/android2nix";

  outputs = { self, android2nix }:
    android2nix.lib.mkAndroid2nixEnv (
      { gradle_6, jdk11, ... }: {
      pname = "Some project";
      src = ./.;
      gradlePkg = gradle_6;
      jdk = jdk11;
      devshell = ./nix/devshell.toml;
      deps = ./nix/deps.json;
      buildType = "assembleRelease";
    });
}
