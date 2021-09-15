{ androidenv, lib, ... }:
androidenv.composeAndroidPackages (lib.importTOML ./devshell.toml).android
