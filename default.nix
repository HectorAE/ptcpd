# SPDX-FileCopyrightText: 2025 Hector A. Escobedo <hae@dry.email>
# SPDX-License-Identifier: GPL-3.0-only

let
  # Pinned haskell.nix version
  sources = {
    haskellNix = builtins.fetchTarball "https://github.com/input-output-hk/haskell.nix/archive/refs/tags/2025.03.30.tar.gz";
  };

  # Fetch the haskell.nix commit we have pinned
  haskellNix = import sources.haskellNix {};

  # Import nixpkgs and pass the haskell.nix provided nixpkgsArgs
  pkgs = import
    # haskell.nix provides access to the nixpkgs pins which are used by our CI,
    # hence you will be more likely to get cache hits when using these.
    # But you can also just use your own, e.g. '<nixpkgs>'.
    haskellNix.sources.nixpkgs-2411
    # These arguments passed to nixpkgs, include some patches and also
    # the haskell.nix functionality itself as an overlay.
    haskellNix.nixpkgsArgs;
in pkgs.haskell-nix.project {
  # 'cleanGit' cleans a source directory based on the files known by git
  src = pkgs.haskell-nix.haskellLib.cleanGit {
    name = "haskell-nix-project";
    src = ./.;
  };
  # Specify the GHC version to use.
  compiler-nix-name = "ghc9122"; # Not required for `stack.yaml` based projects.
}
