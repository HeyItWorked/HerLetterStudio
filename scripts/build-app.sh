#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release --product LetterStudio
app_path="$PWD/build/LetterStudio.app"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
cp .build/release/LetterStudio "$app_path/Contents/MacOS/LetterStudio"
cp -R .build/release/LetterStudio_LetterCore.bundle "$app_path/Contents/Resources/"
cat > "$app_path/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>LetterStudio</string>
<key>CFBundleIdentifier</key><string>local.liam.letterstudio</string>
<key>CFBundleName</key><string>LetterStudio</string>
<key>CFBundleDisplayName</key><string>LetterStudio</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>26.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSMicrophoneUsageDescription</key><string>LetterStudio listens while you dictate and turns your words into a handwritten letter.</string>
<key>NSSpeechRecognitionUsageDescription</key><string>LetterStudio transcribes your spoken words into your letter.</string>
</dict></plist>
PLIST
codesign --force --sign - --identifier local.liam.letterstudio "$app_path"
printf 'Built: %s\n' "$app_path"
