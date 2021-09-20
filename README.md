## This project is supposed to help with building android apps

*As you may see this repo is work in progress*

This is supposed to be a tool for building Android apps with Nix.
It is based on [status-react](https://github.com/status-im/status-react/tree/develop/nix) approach of building.

It is currently supposed to build Briar app.

## Steps (for now)

### Set Nix up 

TODO: Use `lib.makeAndroid2nixEnv`

### After setting Nix up

Load up dev shell and generate deps.json

```
nix develop .
generate --root-dir <Android app dir>
```

Build the app
```
nix build .#release
```

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

