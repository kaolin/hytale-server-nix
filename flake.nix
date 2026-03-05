{
  description = "NixOS module for running a Hytale dedicated server";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: {
    nixosModules.hytale-server = import ./hytale-server.nix;
    nixosModules.default = self.nixosModules.hytale-server;
  };
}
