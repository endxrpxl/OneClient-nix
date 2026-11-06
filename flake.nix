{
  description = "OneClient (Polyfrost OneLauncher monorepo) packaged for Nix";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ self.overlays.default ];
      };
    in
    {
      overlays.default = final: prev: {
        oneclient = final.callPackage ./package.nix { };
      };

      packages.${system} = {
        oneclient = pkgs.oneclient;
        default = pkgs.oneclient;
      };
    };
}
