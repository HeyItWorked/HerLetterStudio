#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
app_binary="$PWD/build/LetterStudio.app/Contents/MacOS/LetterStudio"
if [[ "${1:-ui}" == model ]]; then
  "$app_binary" --verify
elif [[ "${1:-ui}" == snapshot ]]; then
  "$app_binary" --snapshot "$PWD/build/${2:-workspace}.png" "${@:3}"
else
  # take a bunch of screenshots
  "$app_binary" --verify
  "$app_binary" --snapshot "$PWD/build/workspace.png"
  "$app_binary" --snapshot "$PWD/build/compact.png" --compact
  "$app_binary" --snapshot "$PWD/build/materials.png" --compact --materials
  "$app_binary" --snapshot "$PWD/build/writing.png" --writing
  "$app_binary" --snapshot "$PWD/build/library.png" --library
  "$app_binary" --snapshot "$PWD/build/blank.png" --compact --blank
  "$app_binary" --snapshot "$PWD/build/print-preview.png" --print-preview
  "$app_binary" --snapshot "$PWD/build/fonts.png" --fonts
  "$app_binary" --snapshot "$PWD/build/voice-edit.png" --voice-edit --compact
  "$app_binary" --snapshot "$PWD/build/focus.png" --focus
  "$app_binary" --snapshot "$PWD/build/preparing.png" --preparing --compact
fi
