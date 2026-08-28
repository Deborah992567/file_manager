#!/usr/bin/env bash
# Compiles the dependency-free services with the verify harness and runs it.
# Exit code 0 means every round-trip and defense check passed.
set -euo pipefail

cd "$(dirname "$0")/.."
BIN="${TMPDIR:-/tmp}/nova-verify"
swiftc \
  -parse-as-library \
  scripts/verify_services.swift \
  FileManagerApp/Services/ZipService.swift \
  FileManagerApp/Utilities/Formatters.swift \
  -o "$BIN"
"$BIN"
rm -f "$BIN"