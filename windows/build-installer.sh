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

x64_kib="$(du -sk "$stage/win-x64" | awk '{print $1 + 1024}')"
arm64_kib="$(du -sk "$stage/win-arm64" | awk '{print $1 + 1024}')"
makensis -WX -V2 "-DPOCKET_PAYLOAD=$stage" "-DPOCKET_SETUP=$stage/Pocket-Setup.exe" \
  "-DPOCKET_X64_SIZE=$x64_kib" "-DPOCKET_ARM64_SIZE=$arm64_kib" PocketSetup.nsi
mkdir -p bin/installer
mv -- "$stage/Pocket-Setup.exe" bin/installer/Pocket-Setup.exe
echo "Built $(pwd)/bin/installer/Pocket-Setup.exe"
