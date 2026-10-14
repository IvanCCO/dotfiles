#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
./scripts/build-app.sh
python3 -m unittest discover -s tests -v
CHECK_FLAGS=()
if [[ -f .build/toolchain-overlay.yaml ]]; then
  CHECK_FLAGS=(-vfsoverlay "$PWD/.build/toolchain-overlay.yaml")
fi
swiftc -swift-version 5 "${CHECK_FLAGS[@]}" Sources/SSHMonitor/Monitor.swift tests/MemoryAlertCheck.swift -o .build/MemoryAlertCheck
.build/MemoryAlertCheck
