{
  description = "Haskell port of cstack's db_tutorial (TDD)";

  inputs = {
    # ../acac と同じ nixpkgs rev に lock を合わせ、GHC 等の store path を
    # 共有してディスク使用量を抑える。
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    flake-utils.url = "github:numtide/flake-utils";
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      treefmt-nix,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        hpkgs = pkgs.haskell.packages.ghc9122;
        treefmtEval = treefmt-nix.lib.evalModule pkgs ./treefmt.nix;
      in
      {
        formatter = treefmtEval.config.build.wrapper;

        packages.default = hpkgs.callCabal2nix "hsdb" ./. { };

        devShells.default = pkgs.mkShell {
          packages = [
            treefmtEval.config.build.wrapper
            (hpkgs.ghcWithPackages (
              ps: [
                ps.containers
                ps.bytestring
                ps.vector
                ps.hspec
              ]
            ))
            hpkgs.haskell-language-server
            pkgs.cabal-install
          ];
        };
      }
    );
}
