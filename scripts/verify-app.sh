#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
app_binary="$PWD/build/Letter Studio.app/Contents/MacOS/LetterStudio"
if [[ "${1:-ui}" == interaction ]]; then
  "$app_binary" --verify-ui
elif [[ "${1:-ui}" == voice-edit ]]; then
  mkdir -p build/voice-edits
  say -v Samantha -o build/voice-edits/replace.aiff 'Replace quiet with calm.'
  say -v Samantha -o build/voice-edits/insert.aiff 'Insert blue before sea.'
  say -v Samantha -o build/voice-edits/font.aiff 'Use Baskerville.'
  say -v Samantha -o build/voice-edits/undo.aiff 'Undo the last change.'
  say -v Samantha -o build/voice-edits/tender.aiff 'A little more tender.'
  say -v Samantha -o build/voice-edits/ink.aiff 'Change ink to oxblood sincerity.'
  "$app_binary" --verify-voice-edit "$PWD/build/voice-edits"
elif [[ "${1:-ui}" == snapshot ]]; then
  "$app_binary" --snapshot "$PWD/build/${2:-workspace}.png" "${@:3}"
elif [[ "${1:-ui}" == transition ]]; then
  "$app_binary" --qa-transition "$PWD/build/${2:-transition}" "${@:3}"
elif [[ "${1:-ui}" == microphone ]]; then
  "$app_binary" --verify-microphone
elif [[ "${1:-ui}" == voice ]]; then
  say -v Samantha -o build/voice-fixture.aiff 'Dear Alex. I remember the afternoon by the water. The light was warm and the air was quiet. Thank you for making the ordinary days feel special. With love, Liam.'
  "$app_binary" --verify-voice "$PWD/build/voice-fixture.aiff" "$PWD/build/voice-result.txt"
else
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
