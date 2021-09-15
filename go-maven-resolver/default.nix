{ lib, buildGo116Module, fetchFromGitHub }:

let
  inherit (lib) strings;
in buildGo116Module rec {
  pname = "go-maven-resolver";
  version = "v1.1.1";

  vendorSha256 = "sha256-dlqI+onfeo4tTwmHeq8heVKRzLU1gFEQ+4iv+8egN90=";

  src = fetchFromGitHub rec {
    name = "${repo}-${version}-source";
    owner = "Mazurel";
    repo = pname;
    rev = version;
    sha256 = "sha256-OARMadvrfRKz5l0njy5WmWiHoXIrPQDHL3xgRvZZSl4=";
  };
}
