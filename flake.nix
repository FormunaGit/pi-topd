{
  description = "pi-topd - pi-top System Daemon";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # Import our package definitions
        pi-topd-pkgs =
          import ./nix/pkgs.nix { inherit (pkgs) lib pkgs python3Packages; };

      in {
        packages = {
          default = pi-topd-pkgs.pi-topd;
          pi-topd = pi-topd-pkgs.pi-topd;
          pi-topd-python = pi-topd-pkgs.pi-topd-python;
          pitop-common = pi-topd-pkgs.pitop-common;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            python3
            python3Packages.pip
            python3Packages.virtualenv
            python3Packages.setuptools
            python3Packages.wheel
            # Development tools
            python3Packages.black
            python3Packages.flake8
            python3Packages.isort
            python3Packages.pytest
            # System dependencies for development
            alsa-utils
            i2c-tools
          ];

          shellHook = ''
            echo "pi-topd development environment"
            echo "Use 'nix build' to build the package"
            echo "Use 'nix run' to run pi-topd"
          '';
        };

        apps.default = flake-utils.lib.mkApp {
          drv = pi-topd-pkgs.pi-topd-python;
          exePath = "/bin/pi-topd";
        };
      }) // {
        # NixOS module
        nixosModules.default = import ./nix/module.nix;
        nixosModules.pi-topd = import ./nix/module.nix;

        # Overlay for adding pi-topd to nixpkgs
        overlays.default = final: prev: {
          pi-topd-pkgs =
            import ./nix/pkgs.nix { inherit (final) lib pkgs python3Packages; };

          pi-topd = final.pi-topd-pkgs.pi-topd;
          pi-topd-python = final.pi-topd-pkgs.pi-topd-python;

          # Add individual Python packages to python3Packages
          python3 = prev.python3.override {
            packageOverrides = python-self: python-super: {
              pitop-common = final.pi-topd-pkgs.pitop-common;
              smbus2 = final.pi-topd-pkgs.smbus2;
              spidev = final.pi-topd-pkgs.spidev;
              systemd-python = final.pi-topd-pkgs.systemd-python;
            };
          };
        };
      };
}
