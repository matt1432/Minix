{
  description = "Minix: NixOS module for minecraft servers";

  inputs = {
    nixpkgs = {
      type = "github";
      owner = "NixOS";
      repo = "nixpkgs";
      ref = "nixos-unstable";
    };

    curseforge-server-downloader-src = {
      type = "github";
      owner = "Malpiszonekx4";
      repo = "curseforge-server-downloader";
      flake = false;
    };
  };

  outputs = {
    curseforge-server-downloader-src,
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
      minix = import ./modules;

      default = self.nixosModules.minix;
    };

    packages = perSystem (system: pkgs: {
      curseforge-server-downloader = pkgs.callPackage ./pkgs {
        inherit curseforge-server-downloader-src;
      };
    });

    formatter = perSystem (_: pkgs: pkgs.alejandra);
  };
}
