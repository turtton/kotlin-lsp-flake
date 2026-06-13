# kotlin-lsp-flake

JetBrains製 [kotlin-lsp](https://github.com/Kotlin/kotlin-lsp) の Nix flake パッケージです。

[English](README.md)

## 対応プラットフォーム

- `x86_64-linux`
- `aarch64-linux`
- `x86_64-darwin`
- `aarch64-darwin`

## 使い方

### 直接実行

```sh
nix run github:turtton/kotlin-lsp-flake
```

### flake inputs に追加

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    kotlin-lsp.url = "github:turtton/kotlin-lsp-flake";
  };

  outputs = { nixpkgs, kotlin-lsp, ... }:
    let
      system = "x86_64-linux"; # お使いのシステムに変更してください
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ kotlin-lsp.overlays.default ];
      };
    in
    {
      # パッケージを直接使用
      # kotlin-lsp.packages.${system}.default

      # または overlay 経由で使用
      # pkgs.kotlin-lsp
    };
}
```

### overlay 使用時

overlay を適用すると、`pkgs.kotlin-lsp` として利用できます。

## 提供パッケージ

この flake は以下のパッケージを提供しています：

| パッケージ | バイナリ名 | 説明 |
|---|---|---|
| `kotlin-lsp` | `kotlin-lsp` | 標準のバイナリ名を持つデフォルトパッケージ |
| `kotlin-ls` | `kotlin-lsp`, `kotlin-ls` | `kotlin-ls` エイリアスを含む（この名前を期待する LSP クライアント向け） |

### `kotlin-ls` パッケージの使用

`kotlin-ls` を PATH 上で利用可能にする（例：このバイナリ名を期待する LSP クライアント向け）：

```sh
nix shell github:turtton/kotlin-lsp-flake#kotlin-ls -c kotlin-ls
```

### カスタムバイナリエイリアス

`kotlin-lsp` パッケージは `extraBinNames` パラメータを受け付け、任意のエイリアスを追加できます：

```nix
# overlay 経由
pkgs.kotlin-lsp.override { extraBinNames = [ "kotlin-ls" "kotlin-languageserver" ]; }

# または flake package の override 経由
inputs.kotlin-lsp.packages.${system}.kotlin-lsp.override {
  extraBinNames = [ "kotlin-ls" ];
}
```

注意: `nix run` はパッケージの `meta.mainProgram`（`kotlin-lsp`）を実行します。`kotlin-ls` symlink は `$out/bin/` に追加され、パッケージインストール時に PATH 上で利用可能です。

## 自動更新

GitHub Actions ワークフローが毎日新しいリリースをチェックし、更新がある場合は PR を作成します。

## ライセンス

この flake 設定は [Apache-2.0](https://www.apache.org/licenses/LICENSE-2.0) ライセンスの下で公開されています。
kotlin-lsp 自体は JetBrains により独自のライセンス条項で配布されています。
