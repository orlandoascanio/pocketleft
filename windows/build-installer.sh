#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "$0")"
command -v makensis >/dev/null || { echo "Install NSIS (makensis) to build Pocket Setup." >&2; exit 1; }

stage="$(mktemp -d "${TMPDIR:-/tmp}/pocket-setup.XXXXXX")"
trap 'rm -rf -- "$stage"' EXIT

npm ci --ignore-scripts
for target in win-x64 win-arm64; do
  dotnet publish Pocket.Windows.csproj -c Release -r "$target" --self-contained -o "$stage/$target" -warnaserror
done

makensis -WX -V2 "-DPOCKET_PAYLOAD=$stage" "-DPOCKET_SETUP=$stage/Pocket-Setup.exe" PocketSetup.nsi
mkdir -p bin/installer
mv -- "$stage/Pocket-Setup.exe" bin/installer/Pocket-Setup.exe
echo "Built $(pwd)/bin/installer/Pocket-Setup.exe"
