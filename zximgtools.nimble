# Package
description = "ZX-Spectrum tape/disk image tools"
version     = "0.0.1"
license     = "MIT"
author      = "Vladimir Berezenko <qmaster2000@gmail.com>"
srcDir = "src"
installExt = @["nim"]
bin = @["cli/zximgtools"]

# Dependencies
requires "nim >= 0.20.00"

task test, "tests":
  let tests = @["connection", "channel", "exchange", "queue", "basic"]
  for test in tests:
    echo "Running " & test & " test"
    try:
      exec "nim c -r tests/" & test & ".nim"
    except OSError:
      continue
