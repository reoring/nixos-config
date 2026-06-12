{ pkgs }:

with pkgs;
let shared-packages = import ../shared/packages.nix { inherit pkgs; }; in
shared-packages ++ [
  dockutil
  pinentry_mac
  aerospace
  # kdash  # disabled 2026-05-26: upstream nixpkgs hash mismatch on v1.1.2 source archive
]
