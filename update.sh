#!/usr/bin/env bash
set -euo pipefail

REPO="Kotlin/kotlin-lsp"
PACKAGE_NIX="package.nix"

current_version=$(grep 'version = ' "$PACKAGE_NIX" | head -1 | sed 's/.*"\(.*\)".*/\1/')

latest_tag=$(curl -sf "https://api.github.com/repos/${REPO}/releases" \
  | jq -r '[.[] | select(.tag_name | startswith("kotlin-lsp/v"))][0].tag_name')

if [ -z "$latest_tag" ] || [ "$latest_tag" = "null" ]; then
  echo "Failed to fetch latest release tag"
  exit 1
fi

latest_version="${latest_tag#kotlin-lsp/v}"

echo "Current: $current_version"
echo "Latest:  $latest_version"

if [ "$current_version" = "$latest_version" ]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating to $latest_version..."

declare -A PLATFORM_SUFFIXES=(
  ["x86_64-linux"]="linux-x64"
  ["aarch64-linux"]="linux-aarch64"
  ["x86_64-darwin"]="mac-x64"
  ["aarch64-darwin"]="mac-aarch64"
)

for system in "${!PLATFORM_SUFFIXES[@]}"; do
  suffix="${PLATFORM_SUFFIXES[$system]}"
  url="https://download-cdn.jetbrains.com/kotlin-lsp/${latest_version}/kotlin-lsp-${latest_version}-${suffix}.zip"

  echo "Fetching hash for $suffix..."
  new_hex=$(curl -sfL "${url}.sha256" | awk '{print $1}')

  if [ -z "$new_hex" ]; then
    echo "Failed to fetch hash for $suffix"
    exit 1
  fi

  old_hex=$(grep -A2 "\"${system}\"" "$PACKAGE_NIX" | grep 'hash = ' | sed 's/.*sha256:\([a-f0-9]*\).*/\1/')
  sed -i "s|${old_hex}|${new_hex}|" "$PACKAGE_NIX"
  echo "  $system: $new_hex"
done

sed -i "s|version = \"${current_version}\"|version = \"${latest_version}\"|" "$PACKAGE_NIX"

echo "Updated package.nix to version $latest_version"
