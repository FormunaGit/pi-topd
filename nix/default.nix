{ lib, buildPythonPackage, fetchFromGitHub, setuptools, wheel, click
, click-logging, smbus2, spidev, systemd, pyzmq, pyee, pitop-common, pythonOlder
}:

buildPythonPackage rec {
  pname = "pitopd";
  version = "0.0.1"; # This will be overridden by PYTHON_PACKAGE_VERSION if set
  format = "pyproject";

  disabled = pythonOlder "3.9";

  src = ../.;

  nativeBuildInputs = [ setuptools wheel ];

  propagatedBuildInputs =
    [ click click-logging smbus2 spidev systemd pyzmq pyee pitop-common ];

  # Include package data (audio files, scripts, etc.)
  preBuild = ''
    export PYTHON_PACKAGE_VERSION="${version}"
  '';

  # Skip tests for now since they likely require hardware
  doCheck = false;

  pythonImportsCheck = [ "pitopd" ];

  meta = with lib; {
    description =
      "pi-top System Daemon - Core pi-top service for interfacing with pi-top hardware";
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
}
