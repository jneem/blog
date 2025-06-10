{
  description = "A very basic flake";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    abridge = { url = "github:jieiku/abridge"; flake = false; };
  };

  outputs = { self, nixpkgs, flake-utils, abridge }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        version = "2023-08-08";
        pkgs = import nixpkgs { inherit system; };

        themeName = ((builtins.fromTOML (builtins.readFile "${abridge}/theme.toml")).name);

        tikzifyDeps = with pkgs; [
          pdf2svg
          python3
          texlive.combined.scheme-full
        ];

        generatedPosts = [
          { infile = ./tikz-posts/merge.md; outfile = "2017-05-08-merging"; }
          { infile = ./tikz-posts/pijul.md; outfile = "2017-05-13-pijul"; }
          { infile = ./tikz-posts/cycles.md; outfile = "2019-02-19-cycles"; }
          { infile = ./tikz-posts/ids.md; outfile = "2019-02-25-ids"; }
          { infile = ./tikz-posts/pseudo.md; outfile = "2019-05-07-pseudo"; }
        ];

        generateTikzPost = {infile, outfile}: pkgs.stdenv.mkDerivation {
          pname = "jneem-tikz-posts";
          inherit version;
          src = ./tikz-posts;
          nativeBuildInputs = tikzifyDeps;
          buildPhase = ''
            mkdir -m 0755 -p ${outfile}
            python tikzify.py ${infile} ${outfile}
            '';
          installPhase = ''
            mkdir -p $out/content/posts
            cp -rL ${outfile} $out/content/posts/
          '';
        };

        generateTikzPosts = pkgs.symlinkJoin {
          name = "generated-posts";
          paths = pkgs.lib.lists.forEach generatedPosts generateTikzPost;
        };

        generateLocal = pkgs.writeShellScriptBin "generate-local" ''
          nix build .#generatedPosts
          cp -rL result/content/* content/
          chmod -R u+w content/
        '';
      in
      {
        packages.default = pkgs.stdenv.mkDerivation {
          pname = "jneem-website";
          version = "2023-08-08";
          src = ./.;
          nativeBuildInputs = [ pkgs.zola ];
          configurePhase = ''
            mkdir -m 0755 -p "themes/${themeName}"
            mkdir -m 0755 -p templates
            mkdir -m 0755 -p sass
            mkdir -m 0777 -p public
            cp -r ${abridge}/* "themes/${themeName}"
            chmod -R ug+w themes
            cp -r ${generateTikzPosts}/* .
          '';
          buildPhase = ''
            zola build
          '';
          installPhase = "cp -r public $out";
        };

        packages.generatedPosts = generateTikzPosts;

        devShell = pkgs.mkShell {
          packages = with pkgs; [
            krita
            zola
            generateLocal
            gnuplot
            oxipng
          ] ++ tikzifyDeps;
        };
      }
    );
}
