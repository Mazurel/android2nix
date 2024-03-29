# Android2Nix

**WARNING:** Currently this project requires usage of flakes. To install and enable flakes, see [this Nixos Wiki link](https://nixos.wiki/wiki/Flakes).

*As you may see this repo is work in progress*

This tool was build upon [status-react](https://github.com/status-im/status-react/tree/develop/nix) approach of building Android apps with Nix.

**Table of contents**

- [Built with android2nix](#example-android-apps-built-with-android2nix)
- [Building typical Android application](#steps-for-building-typical-android-application)
- [Android2nix for custom scenarios](#steps-for-using-android2nix-in-harder-scenarios)
- [Known issues](#known-issues)

## Example Android apps built with android2nix

- [Briar](https://github.com/ngi-nix/briar/tree/with-source)
- [Conversations](https://github.com/ngi-nix/Conversations-1)

## Steps for building typical Android application

### Set Nix up 

For setting Nix up it is recommended to use provided template. To initialize template, please run `flake init -t "github:Mazurel/android2nix"`. You can also go through it manually and see how to use it.

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

## Steps for using android2nix in harder scenarios

Currently it is the best to look through the overlay and see how each component is used in `android2nix/mkBuild.nix`

TODO: Add some template for it or write some docs

## Known issues

- Sometimes `generate` may fail on generating urls due to timeout, you will need to rerun it again.
- Sometimes dependencies are loaded incorrectly. In this case you need to add them manually to the `additional-deps.list`, see chapter below.
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

## mkAndroid2nixEnv arguments

| Importance | Name                   | Default value   | Description                                                                                                                                                       |
|:----------:|:----------------------:|:---------------:|:-----------------------------------------------------------------------------------------------------------------------------------------------------------------:|
| Required   | src                    |                 | Source of the project                                                                                                                                             |
| Required   | pname                  |                 | Name of the project                                                                                                                                               |
| Required   | devshell               |                 | `devshell.toml` that will be used by the project (contains Android declaration)                                                                                   |
| Required   | deps                   |                 | `deps.json` file that is generated by `generate` that will be used for dependencies declaration                                                                   |
| Optional   | jdk                    | pkgs.jdk        | Java jdk pacged to be used                                                                                                                                        |
| Optional   | gradlePkg              | pkgs.gradle     | Gradle package to be used                                                                                                                                         |
| Optional   | enableParallelBuilding | true            | Use parallel Gradle capabilites                                                                                                                                   |
| Optional   | buildType              | "assembleDebug" | Gradle build type that will be used when building the project                                                                                                     |
| Optional   | nestedinandroid        | false           | (Not yet tested) Sets if android project is nested in android folder, like in flutter or react-native                                                             |
| Optional   | extractApks            | true            | Extract all builded Apks and install them into output folder, otherwise whole build directory will be copied. Useful only when you do not expect Apks to be built |
| Optional   | autoSignApks           | true            | Automatically sign all Apks based on current `keystore` settings. [More about Apk signing](https://developer.android.com/studio/publish/app-signing)              |
| Optional   | keystore               | { }             | Android Keystore arguents. Set that can contain three different keys: `alias`, `password` and `passwordKey`                                                       |

