{
  description = "Minix: NixOS module for minecraft servers";

  inputs = {
    nixpkgs = {
      type = "github";
      owner = "NixOS";
      repo = "nixpkgs";
      ref = "nixos-unstable";
    };

    systems = {
      type = "github";
      owner = "nix-systems";
      repo = "default-linux";
    };

    curseforge-server-downloader-src = {
      type = "github";
      owner = "Malpiszonekx4";
      repo = "curseforge-server-downloader";
      flake = false;
    };
  };

  outputs = {
    self,
    systems,
    nixpkgs,
    curseforge-server-downloader-src,
    ...
  }: let
    perSystem = attrs:
      nixpkgs.lib.genAttrs (import systems) (system:
        attrs (import nixpkgs {inherit system;}));
  in {
    nixosModules = {
      minix = import ./modules;

      default = self.nixosModules.minix;
    };

    packages = perSystem (pkgs: {
      curseforge-server-downloader =
        pkgs.callPackage
        ./pkgs/curseforge-server-downloader.nix {
          inherit curseforge-server-downloader-src;
        };
    });

    formatter = perSystem (pkgs: pkgs.alejandra);
  };
}
