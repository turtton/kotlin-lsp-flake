{
  description = "Nix flake for Kotlin Language Server (kotlin-lsp) by JetBrains";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          kotlin-lsp = pkgs.callPackage ./package.nix { };
          kotlin-ls = self.packages.${system}.kotlin-lsp.override { extraBinNames = [ "kotlin-ls" ]; };
          default = self.packages.${system}.kotlin-lsp;
        }
      );

      checks = forAllSystems (system: {
        default = self.packages.${system}.default;
      });

      overlays.default = final: prev: {
        kotlin-lsp = final.callPackage ./package.nix { };
      };
    };
}
