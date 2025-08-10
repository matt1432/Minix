{
  description = "Minix: NixOS module for minecraft servers";

  inputs = {
    nixpkgs = {
      type = "git";
      url = "https://github.com/NixOS/nixpkgs";
      ref = "nixos-unstable";
      shallow = true;
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

    overlays = {
      minix = final: prev: {
        curseforge-server-downloader = final.callPackage ./pkgs/curseforge-server-downloader.nix {
          inherit curseforge-server-downloader-src;
        };
      };
      default = self.overlays.minix;
    };

    packages = perSystem (pkgs: {
      inherit (pkgs) curseforge-server-downloader;
    });

    formatter = perSystem (pkgs: pkgs.alejandra);
  };
}
