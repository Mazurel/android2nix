{ lib, buildGo116Module, fetchFromGitHub }:

let
  inherit (lib) strings;
in buildGo116Module rec {
  pname = "go-maven-resolver";
  version = "v1.1.1";

  vendorSha256 = "sha256-dlqI+onfeo4tTwmHeq8heVKRzLU1gFEQ+4iv+8egN90=";

  src = fetchFromGitHub rec {
    owner = "Mazurel";
    repo = pname;
    rev = "7e4536d38b6e27c3cb52ba310e039df93b3b0229";
    sha256 = "sha256-S7VyuRNyF+JepN0dN3hkZEsFIndNhwqO7u1fjXj5eFw=";
  };
}
