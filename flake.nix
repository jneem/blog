{
  description = "A very basic flake";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    deepthought = { url = "github:RatanShreshtha/DeepThought"; flake = false; };
  };

  outputs = { self, nixpkgs, flake-utils, deepthought }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        version = "2023-08-08";
        pkgs = import nixpkgs { inherit system; };

        themeName = ((builtins.fromTOML (builtins.readFile "${deepthought}/theme.toml")).name);

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
          inherit version;
          src = ./src;
          nativeBuildInputs = tikzifyDeps;
          buildPhase = "python tikzify.py ${infile} ${outfile}";
          installPhase = ''
            mkdir -p $out/content/posts
            mkdir -p $out/content/images
            cp images/* $out/content/images/
            cp ${outfile} $out/content/posts/
          '';
        };

        generateTikzPosts = pkgs.symlinkJoin {
          name = "generated-posts";
          paths = pkgs.lib.lists.forEach generatedPosts generateTikzPost;
        };

        generateLocal = pkgs.writeShellScriptBin "generate-local" ''
          nix build .#generatedPosts
          cp -ra result/content/* content/
        '';
      in
      {
        packages.default = pkgs.stdenv.mkDerivation {
          pname = "jneem-website";
          version = "2023-08-08";
          src = ./.;
          nativeBuildInputs = [ pkgs.zola ];
          configurePhase = ''
            mkdir -p "themes/${themeName}"
            mkdir -p templates
            mkdir -p static
            mkdir -p sass
            cp -r ${deepthought}/* "themes/${themeName}"
            cp -r ${generateTikzPosts}/* .
          '';
          buildPhase = "zola build";
          installPhase = "cp -r public $out";
        };

        packages.generatedPosts = generateTikzPosts;

        devShell = pkgs.mkShell {
          packages = with pkgs; [
            zola
            generateLocal
          ] ++ tikzifyDeps;
        };
      }
    );
}
