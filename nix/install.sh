#!/usr/bin/env bash

# pi-topd NixOS Installation Helper Script
# This script helps install and configure pi-topd on NixOS systems

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PI_TOPD_DIR="$(dirname "$SCRIPT_DIR")"

# Helper functions
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_nixos() {
    if [[ ! -f /etc/nixos/configuration.nix ]]; then
        print_error "This script is designed for NixOS systems."
        print_error "Please use the manual installation instructions for other systems."
        exit 1
    fi
}

check_hardware() {
    print_info "Checking hardware compatibility..."

    # Check if running on ARM (typical for pi-top devices)
    if [[ "$(uname -m)" == "aarch64" || "$(uname -m)" == "armv7l" ]]; then
        print_success "ARM architecture detected - compatible with pi-top devices"
    else
        print_warning "Non-ARM architecture detected ($(uname -m))"
        print_warning "pi-topd is designed for pi-top hardware running on ARM systems"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi

    # Check for I2C and SPI interfaces
    if [[ -d /sys/bus/i2c ]]; then
        print_success "I2C interface available"
    else
        print_warning "I2C interface not detected"
    fi

    if [[ -d /sys/bus/spi ]]; then
        print_success "SPI interface available"
    else
        print_warning "SPI interface not detected"
    fi
}

check_nix_flakes() {
    print_info "Checking Nix flakes support..."

    if nix --version | grep -q "nix (Nix) 2\.[4-9]\|nix (Nix) [3-9]"; then
        print_success "Nix version supports flakes"
    else
        print_error "Nix version too old for flakes support"
        print_error "Please upgrade to Nix 2.4 or later"
        exit 1
    fi

    # Check if flakes are enabled
    if nix show-config | grep -q "experimental-features.*flakes" 2>/dev/null; then
        print_success "Flakes are enabled"
    else
        print_warning "Flakes are not enabled"
        print_info "You can enable flakes by adding to your NixOS configuration:"
        echo "  nix.settings.experimental-features = [ \"nix-command\" \"flakes\" ];"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

build_package() {
    print_info "Building pi-topd package..."

    cd "$PI_TOPD_DIR"

    if nix build --no-link 2>/dev/null; then
        print_success "Package built successfully"
    else
        print_error "Failed to build package"
        print_error "Please check the build logs above"
        exit 1
    fi
}

generate_config() {
    local config_file="$1"

    print_info "Generating NixOS configuration..."

    cat > "$config_file" << 'EOF'
# pi-topd NixOS Configuration
# Add this to your NixOS configuration.nix or import it as a module

{ config, lib, pkgs, ... }:

{
  imports = [
    # Import the pi-topd module
    # Update this path to match your pi-topd location
    ./pi-topd/nix/module.nix
  ];

  # Enable pi-topd service
  services.pi-topd = {
    enable = true;
    enableScreenBlanking = true;
    enableNotifications = true;
    logBatteryChange = false;
  };

  # Required hardware interfaces
  hardware.i2c.enable = true;
  hardware.spi.enable = true;

  # Optional: Enable Nix flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Optional: Desktop environment for full functionality
  # Uncomment the following for a complete desktop setup
  # services.xserver = {
  #   enable = true;
  #   displayManager.lightdm.enable = true;
  #   desktopManager.lxqt.enable = true;
  # };

  # Optional: Additional packages for pi-top development
  environment.systemPackages = with pkgs; [
    i2c-tools
    # Add other packages as needed
  ];
}
EOF

    print_success "Configuration generated at: $config_file"
}

install_interactive() {
    print_info "Starting interactive installation..."

    echo
    echo "This will help you install pi-topd on your NixOS system."
    echo "Please answer the following questions:"
    echo

    # Ask about installation method
    echo "Installation method:"
    echo "1) Add to existing NixOS configuration"
    echo "2) Generate standalone configuration file"
    echo "3) Use with Nix flakes (recommended)"
    read -p "Choose option [1-3]: " -n 1 -r install_method
    echo
    echo

    case $install_method in
        1)
            print_info "You'll need to manually add the pi-topd configuration to your /etc/nixos/configuration.nix"
            print_info "See the generated example configuration for reference"
            generate_config "/tmp/pi-topd-config.nix"
            ;;
        2)
            read -p "Enter path for configuration file [./pi-topd-config.nix]: " config_path
            config_path="${config_path:-./pi-topd-config.nix}"
            generate_config "$config_path"
            ;;
        3)
            print_info "Using Nix flakes - creating flake.nix template..."
            cat > "./flake.nix" << EOF
{
  description = "NixOS configuration with pi-topd";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    pi-topd.url = "path:./pi-topd";  # Update this path
  };

  outputs = { self, nixpkgs, pi-topd }: {
    nixosConfigurations.pi-top = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";  # Change to x86_64-linux if needed
      modules = [
        pi-topd.nixosModules.default
        {
          services.pi-topd = {
            enable = true;
            enableScreenBlanking = true;
            enableNotifications = true;
          };

          hardware.i2c.enable = true;
          hardware.spi.enable = true;

          # Add your other configuration here
        }
      ];
    };
  };
}
EOF
            print_success "Flake configuration created at: ./flake.nix"
            ;;
        *)
            print_error "Invalid option"
            exit 1
            ;;
    esac

    echo
    print_info "Next steps:"
    case $install_method in
        1|2)
            echo "1. Review the generated configuration"
            echo "2. Add it to your NixOS configuration"
            echo "3. Run: sudo nixos-rebuild switch"
            ;;
        3)
            echo "1. Update the pi-topd path in flake.nix"
            echo "2. Run: sudo nixos-rebuild switch --flake .#pi-top"
            ;;
    esac
    echo "4. Reboot your system"
    echo "5. Check service status: systemctl status pi-topd"
}

show_help() {
    cat << EOF
pi-topd NixOS Installation Helper

Usage: $0 [OPTION]

Options:
  -h, --help          Show this help message
  -c, --check         Check system compatibility
  -b, --build         Build pi-topd package
  -g, --generate      Generate configuration file
  -i, --install       Interactive installation
  --config-file FILE  Generate configuration at specific file

Examples:
  $0 --check                    Check system compatibility
  $0 --build                    Build the package
  $0 --generate                 Generate configuration
  $0 --install                  Interactive installation
  $0 --config-file myconfig.nix Generate config at specific path

EOF
}

main() {
    case "${1:-}" in
        -h|--help)
            show_help
            exit 0
            ;;
        -c|--check)
            check_nixos
            check_hardware
            check_nix_flakes
            print_success "System compatibility check completed"
            ;;
        -b|--build)
            check_nixos
            check_nix_flakes
            build_package
            ;;
        -g|--generate)
            generate_config "./pi-topd-config.nix"
            ;;
        --config-file)
            if [[ -z "${2:-}" ]]; then
                print_error "Please specify a file path"
                exit 1
            fi
            generate_config "$2"
            ;;
        -i|--install)
            check_nixos
            check_hardware
            check_nix_flakes
            build_package
            install_interactive
            ;;
        "")
            # Default action - interactive install
            check_nixos
            check_hardware
            check_nix_flakes
            build_package
            install_interactive
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
