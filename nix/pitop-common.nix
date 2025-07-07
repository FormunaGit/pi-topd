{ lib, buildPythonPackage, fetchFromGitHub, setuptools, wheel, pythonOlder }:

buildPythonPackage rec {
  pname = "pitop-common";
  version = "0.21.0";
  format = "pyproject";

  disabled = pythonOlder "3.7";

  src = fetchFromGitHub {
    owner = "pi-top";
    repo = "pi-top-Python-Common-Library";
    rev = "v${version}";
    sha256 = lib.fakeSha256; # Will need to be updated with actual hash
  };

  nativeBuildInputs = [ setuptools wheel ];

  propagatedBuildInputs = [ ];

  # Skip tests for now since they likely require hardware
  doCheck = false;

  pythonImportsCheck = [ "pitop.common" ];

  meta = with lib; {
    description =
      "pi-top Python Common Library - Common functionality for pi-top Python libraries";
    longDescription = ''
      This library provides common functionality for pi-top Python libraries,
      including device identification, I2C communication helpers, and other
      utilities shared across pi-top software packages.
    '';
    homepage = "https://github.com/pi-top/pi-top-Python-Common-Library";
    license = licenses.asl20;
    maintainers = with maintainers; [ ];
    platforms = platforms.linux;
  };
}
