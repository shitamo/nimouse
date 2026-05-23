# Package
version       = "0.1.0"
author        = "Luciano Federico Pereira"
description   = "CLI tool for Microsoft IntelliMouse devices — Nim port with color output, config file, and shell completion"
license       = "MIT"
srcDir        = "src"
bin           = @["nimouse"]

# Dependencies
requires "nim >= 2.0.0"
requires "cligen >= 1.7.0"

# Build notes:
#   Linux: requires libhidapi-hidraw (runtime) and libhidapi-dev (headers + .so symlink) for compilation.
#     sudo apt install libhidapi-dev     # Debian/Ubuntu
#     sudo pacman -S hidapi              # Arch
#   macOS: brew install hidapi
#   Windows: download hidapi from https://github.com/libusb/hidapi/releases
