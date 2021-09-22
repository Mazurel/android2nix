## This project is supposed to help with building android apps

*As you may see this repo is work in progress*

This is supposed to be a tool for building Android apps with Nix.
It is based on [status-react](https://github.com/status-im/status-react/tree/develop/nix) approach of building.

It is currently supposed to build Briar app.

## Steps (for now)

### Set Nix up 

Example:

flake.nix:

```nix
{
  description = "Example description";

  inputs.android2nix.url = "github:Mazurel/android2nix";

  outputs = { self, android2nix }:
    android2nix.lib.mkAndroid2nixEnv (
      { gradle, jdk11, ... }: {
      pname = "Some project";
      src = ./.;
      gradlePkg = gradle_6;
      jdk = jdk11;
      devshell = ./nix/devshell.toml;
      deps = ./nix/deps.json;
      buildType = "assembleRelease";
    });
}
```

nix/devshell.toml:

```toml
[devshell]
name = "Example devshell"

startup.main.text = "cd nix"

# Here you can specify all Android SDK settings.
# For available options, please see https://github.com/NixOS/nixpkgs/blob/master/pkgs/development/mobile/androidenv/compose-android-packages.nix
[android]
platformToolsVersion = "31.0.3"
buildToolsVersions = [ "30.0.2", "31.0.0" ]
platformVersions = [ "29" ]
abiVersions = [ "armeabi-v7a", "arm64-v8a" ]
ndkVersions = [ "20.0.5594570" ]
cmakeVersions = [ "3.6.4111459" ]
emulatorVersion = "30.8.4"
includeNDK = false
includeEmulator = false
includeSources = false
includeSystemImages = false
useGoogleAPIs = false
useGoogleTVAddOns = false
```

### After setting Nix up

Load up dev shell and generate deps.json

```
nix develop .
# To get all options avaiable via generate, run generate --help
generate --root-dir <Android app dir>
```

Build the app
```
nix build .#release
```

If they are some missing dependencies, add them manually to the `additional-deps.list` and rerun `generate` command (`gen_deps_list`, `gen_deps_urls` and `gen_deps_json` tasks).
It should go faster the second time as there is some basic caching implemented.

## Known issues

- Gradle plugins need to be filled manually in `additional-deps.list` (can be fixed)
- Some files may not be avaiable from local maven repo as they are filtered by extension. If some extension is missing, please add it to `generate/url2json.sh`.
- Sometimes dependencies are loaded correctly. In this case you need to add them manually.
- Gradle witness breaks when you are using local repo (can be fixed)

## Possible fixes for issues

### Gradle can't resolve XYZ dependency

If you are facing this kind of issue, you will need to manually update `additional-deps.list` file (packages are newline separated).
Just add `<dependency and version>` to this file, got into devshell and run:

```bash
generate --task gen_deps_list ...(rest of args)
generate --task gen_deps_urls ...(rest of args)
generate --task gen_deps_json ...(rest of args)
```

This should resolve such issue.

## Gradle witness support

Currently witness is not (yet!) supported. You will need to disable it for your project when building with Nix.

