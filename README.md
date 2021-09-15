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




