# Package
description = "ZX-Spectrum tape/disk image tools"
version     = "0.0.1"
license     = "MIT"
author      = "Vladimir Berezenko <qmaster2000@gmail.com>"
srcDir = "src"
installExt = @["nim"]
namedBin = {"cli/zximgtools": "zximgtools"}.toTable()
skipDirs = @["test", ".vscode"]
# Dependencies
requires "nim >= 1.6.00"

