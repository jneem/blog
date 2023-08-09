{
  description = "A very basic flake";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        tikzifyDeps = with pkgs; [
          pdf2svg
          python3
          texlive.combined.scheme-full
        ];

        generatedPosts = [
          { infile = ./src/merge.md; outfile = "2017-05-08-merging.md"; }
          { infile = ./src/pijul.md; outfile = "2017-05-13-pijul.md"; }
          { infile = ./src/cycles.md; outfile = "2019-02-19-cycles.md"; }
          { infile = ./src/ids.md; outfile = "2019-02-25-ids.md"; }
          { infile = ./src/pseudo.md; outfile = "2019-05-07-pseudo.md"; }
        ];

        generateTikzPost = {infile, outfile}: pkgs.stdenv.mkDerivation {
          pname = "jneem-tikz-posts";
          version = "2023-08-08";
          src = ./src;
          nativeBuildInputs = tikzifyDeps;
          buildPhase = "python tikzify.py ${infile} ${outfile}";
          installPhase = ''
            mkdir -p $out/content
            mkdir -p $out/images
            cp images/* $out/images/
            cp ${outfile} $out/content
          '';
        };

        generateTikzPosts = pkgs.symlinkJoin {
          name = "generated-posts";
          paths = pkgs.lib.lists.forEach generatedPosts generateTikzPost;
        };
      in
      {
        packages.default = pkgs.stdenv.mkDerivation {
          pname = "jneem-website";
          version = "2023-08-08";
          src = ./.;
          nativeBuildInputs = [ pkgs.zola ];
          buildPhase = "zola build";
          installPhase = "cp -r public $out";
        };

        packages.generatedPosts = generateTikzPosts;

        devShell = pkgs.mkShell {
          packages = with pkgs; [
            zola
          ] ++ tikzifyDeps;
        };
      }
    );
}
