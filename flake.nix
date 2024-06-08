{
  description = "NixOS module for minecraft servers";

  inputs = {
    nixpkgs = {
      type = "github";
      owner = "NixOS";
      repo = "nixpkgs";
      ref = "nixos-unstable";
    };
  };

  outputs = {
    nixpkgs,
    self,
    ...
  }: let
    supportedSystems = [
      "x86_64-linux"
      "x86_64-darwin"
    ];

    perSystem = attrs:
      nixpkgs.lib.genAttrs supportedSystems (system:
        attrs system nixpkgs.legacyPackages.${system});
  in {
    nixosModules = {
      nms = import ./modules;

      default = self.nixosModules.nms;
    };

    formatter = perSystem (_: pkgs: pkgs.alejandra);
  };
}
