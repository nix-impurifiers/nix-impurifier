# SPDX-License-Identifier: MIT
{ ... }:
{ lib, inputs, ... }: {
  flake.lib = lib.mkForce {
    nix-impurifier = { pkgs }: import ../../../nix { inherit pkgs; };
  };
  perSystem =
    { pkgs, ... }:
    let
      impurifier = import ../../../nix { inherit pkgs; };
    in
    {
      formatter = pkgs.nixfmt-tree;
      checks = import ../../../tests {
        inherit pkgs impurifier;
        coreSrc = inputs.impurifier;
      };
    };
}
