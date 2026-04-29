#!/usr/bin/env bash
set -euo pipefail

REPO="Kotlin/kotlin-lsp"
PACKAGE_NIX="package.nix"

current_version=$(awk -F'"' '/version = / { print $2; exit }' "$PACKAGE_NIX")

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

# Pre-flight: verify all platform binaries are available before modifying any files
TMP_SHA=""
cleanup() { [ -n "$TMP_SHA" ] && rm -f "$TMP_SHA"; }
trap cleanup EXIT

declare -A NEW_HASHES=()
for system in "${!PLATFORM_SUFFIXES[@]}"; do
  suffix="${PLATFORM_SUFFIXES[$system]}"
  sha_url="https://download-cdn.jetbrains.com/kotlin-lsp/${latest_version}/kotlin-lsp-${latest_version}-${suffix}.zip.sha256"

  echo "Fetching hash for $suffix..."
  TMP_SHA=$(mktemp)
  curl_exit=0
  http_code=$(curl -sSL -w '%{http_code}' -o "$TMP_SHA" "$sha_url") || curl_exit=$?

  # Network failure (DNS, TLS, timeout) → skip, retry tomorrow
  if [ "$curl_exit" -ne 0 ]; then
    echo "Network error fetching $suffix (curl exit $curl_exit)"
    echo "Skipping update — will retry on next scheduled run"
    exit 0
  fi

  # 404 → binary not published yet → skip
  if [ "$http_code" = "404" ]; then
    echo "Binary not yet available for $suffix (HTTP 404)"
    echo "Skipping update — will retry on next scheduled run"
    exit 0
  fi

  # Other HTTP errors → genuine failure
  if [ "$http_code" != "200" ]; then
    echo "Unexpected HTTP $http_code for $suffix"
    exit 1
  fi

  # HTTP 200 confirmed — now read the hash
  new_hex=$(awk 'NR==1 { print $1; exit }' "$TMP_SHA")
  rm -f "$TMP_SHA"
  TMP_SHA=""

  if ! [[ $new_hex =~ ^[0-9a-fA-F]{64}$ ]]; then
    echo "Invalid hash for $suffix: $new_hex"
    exit 1
  fi

  NEW_HASHES[$system]="$new_hex"
  echo "  $system: $new_hex (verified)"
done
trap - EXIT

# All binaries confirmed available — apply changes
for system in "${!PLATFORM_SUFFIXES[@]}"; do
  old_hex=$(grep -A2 "\"${system}\"" "$PACKAGE_NIX" | grep 'hash = ' | sed 's/.*sha256:\([a-f0-9]*\).*/\1/')
  update_file "$PACKAGE_NIX" "$old_hex" "${NEW_HASHES[$system]}"
done

update_file "$PACKAGE_NIX" "version = \"${current_version}\"" "version = \"${latest_version}\""

echo "Updated package.nix to version $latest_version"
