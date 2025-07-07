# pi-topd Nix Package

This directory contains Nix derivations and a NixOS module for installing and running pi-topd on NixOS systems.

## Overview

pi-topd is a system daemon for pi-top hardware devices that provides:
- Hardware communication via I2C/SPI interfaces
- Battery monitoring and power management
- Peripheral detection and configuration
- System integration for plug-and-play functionality

## Quick Start

### Using Nix Flakes (Recommended)

1. **Build the package:**
   ```bash
   nix build github:pi-top/pi-topd
   ```

2. **Run pi-topd directly:**
   ```bash
   nix run github:pi-top/pi-topd
   ```

3. **Enter development shell:**
   ```bash
   nix develop github:pi-top/pi-topd
   ```

### Using with NixOS

Add the following to your NixOS configuration:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    pi-topd.url = "github:pi-top/pi-topd";
  };

  outputs = { self, nixpkgs, pi-topd }: {
    nixosConfigurations.your-system = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux"; # or "x86_64-linux" for testing
      modules = [
        pi-topd.nixosModules.default
        {
          services.pi-topd = {
            enable = true;
            enableScreenBlanking = true;
            enableNotifications = true;
            logBatteryChange = false;
          };

          # Required hardware interfaces
          hardware.i2c.enable = true;
          hardware.spi.enable = true;
        }
      ];
    };
  };
}
```

## Requirements

### Hardware Requirements
- pi-top device (pi-top 4, pi-top 3, pi-top CEED, etc.)
- Raspberry Pi or compatible ARM board
- I2C and SPI interfaces available

### Software Requirements
- NixOS (recommended) or Nix package manager
- Linux kernel with I2C and SPI support
- systemd (for service management)

## Configuration Options

The NixOS module provides the following configuration options:

### `services.pi-topd.enable`
- **Type:** boolean
- **Default:** `false`
- **Description:** Enable the pi-topd service

### `services.pi-topd.package`
- **Type:** package
- **Default:** `pi-topd-python`
- **Description:** The pi-topd package to use

### `services.pi-topd.logBatteryChange`
- **Type:** boolean
- **Default:** `false`
- **Description:** Whether to log battery change events

### `services.pi-topd.enableScreenBlanking`
- **Type:** boolean
- **Default:** `true`
- **Description:** Enable screen blanking functionality (requires desktop environment)

### `services.pi-topd.enableNotifications`
- **Type:** boolean
- **Default:** `true`
- **Description:** Enable desktop notifications for pi-topd events

### `services.pi-topd.extraEnvironment`
- **Type:** attribute set of strings
- **Default:** `{}`
- **Description:** Additional environment variables for the service

## Example Configurations

### Minimal Configuration
```nix
{
  services.pi-topd.enable = true;
  hardware.i2c.enable = true;
  hardware.spi.enable = true;
}
```

### Full Configuration
```nix
{
  services.pi-topd = {
    enable = true;
    logBatteryChange = true;
    enableScreenBlanking = true;
    enableNotifications = true;
    extraEnvironment = {
      PT_DEBUG_MODE = "1";
      PT_LOG_LEVEL = "DEBUG";
    };
  };

  hardware.i2c.enable = true;
  hardware.spi.enable = true;

  # Optional: Enable desktop environment for full functionality
  services.xserver.enable = true;
  services.xserver.displayManager.lightdm.enable = true;
  services.xserver.desktopManager.lxqt.enable = true;
}
```

### Development Configuration
```nix
{
  services.pi-topd = {
    enable = true;
    logBatteryChange = true;
    extraEnvironment = {
      PT_DEBUG_MODE = "1";
      PT_LOG_LEVEL = "DEBUG";
      PYTHONPATH = "/path/to/development/pi-topd";
    };
  };

  hardware.i2c.enable = true;
  hardware.spi.enable = true;

  # Development tools
  environment.systemPackages = with pkgs; [
    python3
    python3Packages.pip
    python3Packages.virtualenv
    i2c-tools
    alsa-utils
  ];
}
```

## Security Considerations

The pi-topd service runs as root by default because it requires:
- Direct hardware access to I2C/SPI interfaces
- System configuration changes
- Audio device management

The NixOS module implements several security hardening measures:
- `NoNewPrivileges = true`
- `ProtectSystem = "strict"`
- `ProtectHome = true`
- `PrivateTmp = true`
- Device access limited to specific hardware interfaces

## Troubleshooting

### Service not starting
1. Check that I2C and SPI are enabled:
   ```bash
   sudo dmesg | grep -i i2c
   sudo dmesg | grep -i spi
   ```

2. Verify hardware permissions:
   ```bash
   ls -la /dev/i2c-*
   ls -la /dev/spidev*
   ```

3. Check service logs:
   ```bash
   journalctl -u pi-topd -f
   ```

### Hardware not detected
1. Ensure you're running on pi-top hardware
2. Check I2C device detection:
   ```bash
   sudo i2cdetect -y 1
   ```

3. Verify pi-top hub communication:
   ```bash
   python3 -c "from pitop.common.common_ids import DeviceID; print(DeviceID.get_device_id())"
   ```

### Desktop integration issues
1. Ensure X11 is running and accessible to root:
   ```bash
   sudo xhost +SI:localuser:root
   ```

2. Check LightDM configuration:
   ```bash
   cat /etc/lightdm/lightdm.conf.d/pt-xhost-local-root.conf
   ```

## File Structure

```
nix/
├── README.md           # This file
├── default.nix         # Main pi-topd package derivation
├── pitop-common.nix    # pitop-common dependency
├── pkgs.nix            # Complete package set with all dependencies
├── module.nix          # NixOS module
└── flake.nix           # Nix flake (in parent directory)
```

## Dependencies

The following Python packages are included:
- `pitop.common` - Common pi-top library functionality
- `click` - Command-line interface framework
- `click-logging` - Logging configuration for click
- `smbus2` - I2C communication library
- `spidev` - SPI communication library
- `systemd-python` - Python bindings for systemd
- `pyzmq` - ZeroMQ Python bindings
- `pyee` - Python event emitter

System dependencies:
- `alsa-utils` - Audio configuration tools
- `xprintidle` - X11 idle time detection (optional)
- `libnotify` - Desktop notifications (optional)

## Development

### Building from source
```bash
git clone https://github.com/pi-top/pi-topd.git
cd pi-topd
nix build
```

### Development shell
```bash
nix develop
```

### Testing
```bash
# Run pi-topd in development mode
nix run

# Or build and run manually
nix build
./result/bin/pi-topd --help
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test on pi-top hardware
5. Submit a pull request

## License

This Nix packaging follows the same Apache 2.0 license as pi-topd itself.

## Support

For issues with the Nix packaging, please open an issue on the pi-topd repository.
For general pi-top support, visit the [pi-top knowledge base](https://knowledgebase.pi-top.com/).