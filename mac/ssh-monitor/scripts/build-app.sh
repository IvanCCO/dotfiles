#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
mkdir -p .build
BUILD_FLAGS=()
TOOLCHAIN_INCLUDE="$(xcrun --find swiftc)"
TOOLCHAIN_INCLUDE="${TOOLCHAIN_INCLUDE:h:h}/include/swift"
if [[ -f "$TOOLCHAIN_INCLUDE/module.modulemap" && -f "$TOOLCHAIN_INCLUDE/bridging.modulemap" ]] && grep -q "module SwiftBridging" "$TOOLCHAIN_INCLUDE/module.modulemap" && grep -q "module SwiftBridging" "$TOOLCHAIN_INCLUDE/bridging.modulemap"; then
  print '// Ignore stale duplicate SwiftBridging module.' > .build/empty.modulemap
  python3 - "$TOOLCHAIN_INCLUDE/module.modulemap" "$PWD" <<'PYTHON'
import json, sys, pathlib
root = pathlib.Path(sys.argv[2])
(root / '.build/toolchain-overlay.yaml').write_text(json.dumps({'version': 0, 'roots': [{'type': 'file', 'name': sys.argv[1], 'external-contents': str(root / '.build/empty.modulemap')}]}))
PYTHON
  BUILD_FLAGS=(-vfsoverlay "$PWD/.build/toolchain-overlay.yaml")
fi
clang -target "$(uname -m)-apple-macosx13.0" -fobjc-arc -c Sources/SSHMonitor/NativeGlass.m -o .build/NativeGlass.o
swiftc -import-objc-header Sources/SSHMonitor/NativeGlass.h .build/NativeGlass.o -O -swift-version 5 -parse-as-library "${BUILD_FLAGS[@]}" -target "$(uname -m)-apple-macosx13.0" Sources/SSHMonitor/App.swift Sources/SSHMonitor/Monitor.swift -o .build/SSHMonitor
APP="$PWD/dist/SSH Monitor.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/SSHMonitor "$APP/Contents/MacOS/SSHMonitor"
cp Sources/SSHMonitor/collector.py "$APP/Contents/Resources/collector.py"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>SSHMonitor</string>
<key>CFBundleIdentifier</key><string>dev.ivanfreire.sshmonitor</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleName</key><string>SSH Monitor</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --deep --sign - "$APP"
print "App criado em: $APP"
