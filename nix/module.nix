{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.pi-topd;

  # Create a Python environment with pi-topd and its dependencies
  pi-topd-python = pkgs.python3.withPackages (ps:
    [
      (ps.callPackage ./default.nix {
        pitop-common = ps.callPackage ./pitop-common.nix { };
      })
    ]);

in {
  options.services.pi-topd = {
    enable = mkEnableOption "pi-top System Daemon";

    package = mkOption {
      type = types.package;
      default = pi-topd-python;
      defaultText = literalExpression "pi-topd-python";
      description = "The pi-topd package to use.";
    };

    logBatteryChange = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to log battery change events.";
    };

    extraEnvironment = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description =
        "Additional environment variables to set for the pi-topd service.";
    };

    enableScreenBlanking = mkOption {
      type = types.bool;
      default = true;
      description =
        "Enable screen blanking functionality (requires desktop environment).";
    };

    enableNotifications = mkOption {
      type = types.bool;
      default = true;
      description = "Enable desktop notifications for pi-topd events.";
    };
  };

  config = mkIf cfg.enable {
    # Ensure required hardware interfaces are enabled
    assertions = [
      {
        assertion = config.hardware.i2c.enable;
        message =
          "pi-topd requires I2C to be enabled. Set hardware.i2c.enable = true;";
      }
      {
        assertion = config.hardware.spi.enable;
        message =
          "pi-topd requires SPI to be enabled. Set hardware.spi.enable = true;";
      }
    ];

    # Install required system packages
    environment.systemPackages = with pkgs;
      [ cfg.package alsa-utils ]
      ++ optionals cfg.enableScreenBlanking [ xprintidle ]
      ++ optionals cfg.enableNotifications [ libnotify ];

    # Create the systemd service
    systemd.services.pi-topd = {
      description = "pi-top System Daemon";
      documentation = [ "https://knowledgebase.pi-top.com/knowledge" ];
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        Type = "notify";
        Restart = "on-failure";
        ExecStart = "${cfg.package}/bin/pi-topd";

        # Security settings
        User = "root"; # Required for hardware access
        Group = "root";

        # Hardening (while still allowing hardware access)
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;

        # Allow access to hardware interfaces
        DeviceAllow = [ "/dev/i2c-* rw" "/dev/spidev* rw" "/dev/gpiomem rw" ];

        # Allow access to sound devices
        SupplementaryGroups = [ "audio" ];
      };

      environment = {
        PT_LOG_BATTERY_CHANGE = if cfg.logBatteryChange then "1" else "0";
        PYTHONUNBUFFERED = "1";
        PYTHONDONTWRITEBYTECODE = "1";
      } // cfg.extraEnvironment;
    };

    # Additional systemd services for power management
    systemd.services.pt-poweroff = {
      description = "pi-top Power Off Service";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${cfg.package}/bin/pt-poweroff";
        User = "root";
      };
    };

    systemd.services.pt-reboot = {
      description = "pi-top Reboot Service";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${cfg.package}/bin/pt-reboot";
        User = "root";
      };
    };

    # Configure LightDM for desktop integration if screen blanking is enabled
    services.xserver.displayManager.lightdm.extraConfig =
      mkIf (cfg.enableScreenBlanking && config.services.xserver.enable) ''
        [Seat:*]
        session-setup-script=${pkgs.xorg.xhost}/bin/xhost +SI:localuser:root
      '';

    # Ensure the user running the desktop session is in the required groups
    users.groups.pi-top = { };

    # Add udev rules for pi-top hardware access
    services.udev.extraRules = ''
      # pi-top hardware access
      SUBSYSTEM=="i2c-dev", GROUP="i2c", MODE="0660"
      SUBSYSTEM=="spidev", GROUP="spi", MODE="0660"

      # pi-top specific hardware
      ATTRS{idVendor}=="0525", ATTRS{idProduct}=="a4ac", MODE="0660", GROUP="pi-top"
      ATTRS{idVendor}=="0525", ATTRS{idProduct}=="a4ad", MODE="0660", GROUP="pi-top"
    '';

    # Enable hardware interfaces
    hardware.i2c.enable = mkDefault true;
    hardware.spi.enable = mkDefault true;

    # Create necessary groups
    users.groups.i2c = { };
    users.groups.spi = { };
  };
}
