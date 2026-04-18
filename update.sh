#!/usr/bin/env bash
set -euo pipefail

REPO="Kotlin/kotlin-lsp"
PACKAGE_NIX="package.nix"

current_version=$(grep 'version = ' "$PACKAGE_NIX" | head -1 | sed 's/.*"\(.*\)".*/\1/')

latest_tag=$(curl -sf "https://api.github.com/repos/${REPO}/releases/latest" \
  | jq -r '.tag_name')

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

# Use a temp file for portable sed (macOS + Linux)
update_file() {
  local file="$1" pattern="$2" replacement="$3"
  local tmp="${file}.tmp"
  sed "s|${pattern}|${replacement}|" "$file" > "$tmp" && mv "$tmp" "$file"
}

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
  update_file "$PACKAGE_NIX" "$old_hex" "$new_hex"
  echo "  $system: $new_hex"
done

update_file "$PACKAGE_NIX" "version = \"${current_version}\"" "version = \"${latest_version}\""

echo "Updated package.nix to version $latest_version"
