{ stdenv, lib, go-maven-resolver, parallel, jq, makeWrapper, ... }:
stdenv.mkDerivation {
  pname = "generate";
  version = "0.1";

  src = ./.;

  nativeBuildInputs = [ makeWrapper ];
  
  buildInputs = [ go-maven-resolver parallel jq ];

  installPhase = ''
  mkdir -p $out/bin
  install -t $out/bin ./*.sh ./*.awk
  '';

  fixupPhase = ''
  wrapProgram $out/bin/generate.sh \
              --prefix PATH : ${lib.makeBinPath [ go-maven-resolver parallel ] }
  '';
}
