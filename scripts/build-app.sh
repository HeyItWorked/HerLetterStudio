#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release --product HerLetterStudio
app_path="$PWD/build/HerLetterStudio.app"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
cp .build/release/HerLetterStudio "$app_path/Contents/MacOS/HerLetterStudio"
cp -R .build/release/HerLetterStudio_LetterCore.bundle "$app_path/Contents/Resources/"
cat > "$app_path/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>HerLetterStudio</string>
<key>CFBundleIdentifier</key><string>local.liam.HerLetterStudio</string>
<key>CFBundleName</key><string>HerLetterStudio</string>
<key>CFBundleDisplayName</key><string>HerLetterStudio</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>26.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSMicrophoneUsageDescription</key><string>HerLetterStudio listens while you dictate and turns your words into a handwritten letter.</string>
<key>NSSpeechRecognitionUsageDescription</key><string>HerLetterStudio transcribes your spoken words into your letter.</string>
</dict></plist>
PLIST
codesign --force --sign - --identifier local.liam.HerLetterStudio "$app_path"
printf 'Built: %s\n' "$app_path"
