{ lib, pkgs, python3Packages }:

let
  # Create the pitop-common dependency from PyPI
  pitop-common = python3Packages.buildPythonPackage rec {
    pname = "pitop.common";
    version = "0.34.3.post1";
    format = "setuptools";

    disabled = python3Packages.pythonOlder "3.7";

    src = pkgs.fetchPypi {
      inherit pname version;
      sha256 = "sha256-KHAvRHWy7UNb078YwZzSrEiMXv6lhzAJOZ7szoqrreM=";
    };

    nativeBuildInputs = with python3Packages; [ setuptools wheel ];

    propagatedBuildInputs = with python3Packages; [ ];

    # Skip tests for now since they likely require hardware
    doCheck = false;

    pythonImportsCheck = [ "pitop.common" ];

    meta = with lib; {
      description = "pi-top Python Common Library";
      longDescription = ''
        This library provides common functionality for pi-top Python libraries,
        including device identification, I2C communication helpers, and other
        utilities shared across pi-top software packages.
      '';
      homepage = "https://github.com/pi-top/pi-top-Python-SDK";
      license = licenses.asl20;
      maintainers = with maintainers; [ ];
      platforms = platforms.linux;
    };
  };

  # Use click-log from nixpkgs (compatible with click-logging)
  click-logging = python3Packages.click-log;

  # Use existing packages from nixpkgs (version constraints will be handled by disabling runtime checks)
  smbus2 = python3Packages.smbus2;
  spidev = python3Packages.spidev;

  # Use existing systemd-python from nixpkgs
  systemd-python = python3Packages.systemd;

  # Main pi-topd package
  pi-topd = python3Packages.buildPythonPackage rec {
    pname = "pitopd";
    version =
      "0.0.1"; # This will be overridden by PYTHON_PACKAGE_VERSION if set
    format = "pyproject";

    disabled = python3Packages.pythonOlder "3.9";

    src = ../.;

    nativeBuildInputs = with python3Packages; [ setuptools wheel ];

    propagatedBuildInputs = with python3Packages; [
      pitop-common
      click
      click-logging
      smbus2
      spidev
      systemd-python
      pyzmq
      pyee
    ];

    # Disable runtime dependency checking to avoid version conflicts
    dontCheckRuntimeDeps = true;

    # Patch the source to use click_log instead of click_logging
    postPatch = ''
      # Replace click_logging imports with click_log
      find . -name "*.py" -exec sed -i 's/import click_logging/import click_log as click_logging/g' {} \;
      find . -name "*.py" -exec sed -i 's/from click_logging/from click_log/g' {} \;
    '';

    # Include package data (audio files, scripts, etc.)
    preBuild = ''
      export PYTHON_PACKAGE_VERSION="${version}"
    '';

    # Skip tests for now since they likely require hardware
    doCheck = false;

    pythonImportsCheck = [ "pitopd" ];

    # Install additional scripts and assets
    postInstall = ''
      # Install shell scripts
      install -Dm755 pitopd/scripts/i2s.sh $out/bin/pt-i2s

      # Install audio assets
      mkdir -p $out/share/pi-topd/assets
      cp pitopd/assets/*.mp3 $out/share/pi-topd/assets/
      cp pitopd/assets/*.restore $out/share/pi-topd/assets/
    '';

    meta = with lib; {
      description = "pi-top System Daemon";
      longDescription = ''
        This application runs as a background process in order to receive state/event
        information from pi-top hardware and manage the system configuration in order
        to provide plug-and-play functionality. It also provides an interface for
        getting information from the hub without requiring any knowledge of the hub's
        internal register interface.
      '';
      homepage = "https://github.com/pi-top/pi-topd";
      license = licenses.asl20;
      maintainers = with maintainers; [ ];
      platforms = platforms.linux;
      # This is hardware-specific software for pi-top devices
      broken = false;
    };
  };

  # Create Python environment with pi-topd
  pi-topd-python = pkgs.python3.withPackages (ps: [ pi-topd ]);

in {
  inherit pitop-common click-logging smbus2 spidev systemd-python pi-topd
    pi-topd-python;
}
