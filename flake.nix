{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    claude-code = {
      url = "github:sadjow/claude-code-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      claude-code,
      ...
    }:
    flake-utils.lib.eachSystem
      [
        "x86_64-linux"
        "aarch64-linux"
      ]
      (
        system:
        let
          pkgs = import nixpkgs {
            inherit
              system
              ;
            config.allowUnfree = true;
          };

          # ── Claude Settings ─────────────────────────────────────
          claude = claude-code.packages.${system}.default;

          # ── Tooling shared by the dev shell and CI ───────────────
          ciTools = with pkgs; [
            typos
            committed
            git-cliff
            taplo
            editorconfig-checker

            # nix tooling
            nixfmt
            statix
            deadnix

            # crate deps
          ];
        in
        {
          # ── Dev Shell (nix develop) ──────────────────────────────
          devShells.default = pkgs.mkShell {
            buildInputs =
              ciTools
              ++ (with pkgs; [
                rust-analyzer
                just
                claude
                nodejs
              ]);
          };

          # # ── CI Shell (nix develop .#ci) ──────────────────────────
          # # Lean: just the toolchain + checks, no editor/claude/shellHook.
          # devShells.ci = pkgs.mkShell {
          #   buildInputs = ciTools;
          # };
        }
      );
}
