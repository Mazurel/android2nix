## This project was supposed to help with building android apps

This is supposed to be a tool for building Android apps with Nix.
It is based on [status-react](https://github.com/status-im/status-react/tree/develop/nix) approach of building.

It is currently supposed to build Briar app.
Currently it completely fails.

## Steps (for now)

Load up dev shell and generate deps.json

```
nix develop .
generate --root-dir <Android app dir>
```

Build the app
```
nix build .#release
```

## Possible fixes for issues

### Gradle can't resolve XYZ dependency

If you are facing this kind of issue, you will need to manually update `deps.list` file (packages are newline separated).
Just add `<dependency and version>` to this file, got into devshell and run:

```bash
generate --root-dir <dir> --task gen_deps_urls
generate --root-dir <dir> --task gen_deps_json
```

This should resolve such issue.



