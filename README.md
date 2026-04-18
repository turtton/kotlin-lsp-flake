# kotlin-lsp-flake

Nix flake for [kotlin-lsp](https://github.com/Kotlin/kotlin-lsp) by JetBrains.

[日本語](README.ja.md)

## Supported Platforms

- `x86_64-linux`
- `aarch64-linux`
- `x86_64-darwin`
- `aarch64-darwin`

## Usage

### Run directly

```sh
nix run github:turtton/kotlin-lsp-flake
```

### Add to flake inputs

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    kotlin-lsp.url = "github:turtton/kotlin-lsp-flake";
  };

  outputs = { nixpkgs, kotlin-lsp, ... }:
    let
      system = "x86_64-linux"; # Change to your system
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ kotlin-lsp.overlays.default ];
      };
    in
    {
      # Use the package directly
      # kotlin-lsp.packages.${system}.default

      # Or via overlay
      # pkgs.kotlin-lsp
    };
}
```

### With overlay

Once the overlay is applied, `kotlin-lsp` is available as `pkgs.kotlin-lsp`.

## Auto-Update

A GitHub Actions workflow checks for new releases daily and creates a PR when an update is available.

## License

This flake configuration is licensed under [Apache-2.0](https://www.apache.org/licenses/LICENSE-2.0).
kotlin-lsp itself is distributed by JetBrains under its own license terms.
