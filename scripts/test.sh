#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# This CLT installation ships an incomplete _Testing_Foundation framework.
# Run the same assertions in a standalone Swift executable; failures exit nonzero.
swift run LetterCoreChecks
