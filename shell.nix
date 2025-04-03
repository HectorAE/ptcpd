# SPDX-FileCopyrightText: 2025 Hector A. Escobedo <hae@dry.email>
# SPDX-License-Identifier: GPL-3.0-only

let
  project = import ./default.nix;
in
  project.shellFor {
    withHoogle = true;
    tools = {
      cabal = "latest";
    };
  }
