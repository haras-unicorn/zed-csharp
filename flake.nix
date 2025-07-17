{
  description = "Zed CSharp extension";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    flake-utils.url = "github:numtide/flake-utils";

    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      flake-utils,
      nixpkgs,
      rust-overlay,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ (import rust-overlay) ];
        };

        wasi-sdk = pkgs.stdenv.mkDerivation {
          pname = "wasi-sdk";
          version = "25.0";
          src = pkgs.fetchzip {
            url = "https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-25/wasi-sdk-25.0-x86_64-linux.tar.gz";
            hash = "sha256-dGILAjomC2dx+O1NBmVcR35eC/Jf9SjOVUb3Q6civbE=";
          };
          dontBuild = true;
          nativeBuildInputs = [
            pkgs.autoPatchelfHook
          ];
          buildInputs = [
            pkgs.stdenv.cc.cc.lib
          ];
          installPhase = ''
            mkdir -p $out
            dir=$(echo wasi-sdk-*)
            cp -r "$dir"/* $out/
          '';
        };

        rust = pkgs.rust-bin.stable.latest.default.override {
          extensions = [
            "clippy"
            "rustfmt"
            "rust-analyzer"
            "rust-src"
          ];
          targets = [
            "wasm32-wasip2"
          ];
        };

        zed-editor = pkgs.writeShellApplication {
          name = "zeditor";
          runtimeInputs = [ pkgs.zed-editor ];
          text = ''
            ROOT="$(git rev-parse --show-toplevel)"

            rm -rf "$ROOT/data"
            rm -rf "$ROOT/extension.wasm"

            mkdir -p "$ROOT/data/extensions/build"
            ln -s "$WASI_SDK_PATH" "$ROOT/data/extensions/build/wasi-sdk"

            zeditor --user-data-dir "$ROOT/data" --foreground "$ROOT/work" "$@"
          '';
        };
      in
      {
        devShell = pkgs.mkShell {
          WASI_SDK_PATH = "${wasi-sdk}";

          packages = [
            zed-editor
            rust
            wasi-sdk
            pkgs.csharp-ls
            pkgs.dotnet-sdk_9

            pkgs.nodePackages.prettier
            pkgs.nodePackages.yaml-language-server
            pkgs.nodePackages.vscode-langservers-extracted
            pkgs.markdownlint-cli
            pkgs.nodePackages.markdown-link-check
            pkgs.marksman
            pkgs.taplo
          ];
        };
      }
    );
}
