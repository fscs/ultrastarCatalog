{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    mvn2nix = {
      url = "github:fzakaria/mvn2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    nixpkgs,
    mvn2nix,
    flake-utils,
    ...
  }: let
  in
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
      };
    in {
      packages.default = let
        mavenRepository =
          mvn2nix.legacyPackages.${system}.buildMavenRepositoryFromLockFile
          {file = ./mvn2nix-lock.json;};
      in
        pkgs.stdenv.mkDerivation rec {
          pname = "ultrastarCatalog";
          version = "0.2";
          name = "${pname}-${version}";
          src = pkgs.lib.cleanSource ./.;

          nativeBuildInputs = with pkgs; [
            jdk21_headless
            maven
            makeWrapper
          ];

          buildPhase = ''
            echo "Building with maven repository ${mavenRepository}"
            mvn package --offline -Dmaven.repo.local=${mavenRepository}
          '';

          installPhase = ''
            # create the bin directory
            mkdir -p $out/bin

            # create a symbolic link for the lib directory
            ln -s ${mavenRepository} $out/lib

            # copy out the JAR
            # Maven already setup the classpath to use m2 repository layout
            # with the prefix of lib/
            cp target/${name}.jar $out/

            # create a wrapper that will automatically set the classpath
            # this should be the paths from the dependency derivation
            makeWrapper ${pkgs.jdk21_headless}/bin/java $out/bin/${pname} \
                  --add-flags "-jar $out/${name}.jar"
          '';
        };
    });
}
