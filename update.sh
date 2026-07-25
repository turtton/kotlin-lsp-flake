#!/usr/bin/env bash
set -euo pipefail

REPO="Kotlin/kotlin-lsp"
HASHES_JSON="hashes.json"

current_version=$(jq -r '.version' "$HASHES_JSON")

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

# All binaries confirmed available — write hashes.json atomically
HASHES_TMP=$(mktemp)
jq -n \
  --arg version "$latest_version" \
  --arg x86_64_linux_suffix "${PLATFORM_SUFFIXES[x86_64-linux]}" \
  --arg x86_64_linux_hash "sha256:${NEW_HASHES[x86_64-linux]}" \
  --arg aarch64_linux_suffix "${PLATFORM_SUFFIXES[aarch64-linux]}" \
  --arg aarch64_linux_hash "sha256:${NEW_HASHES[aarch64-linux]}" \
  --arg x86_64_darwin_suffix "${PLATFORM_SUFFIXES[x86_64-darwin]}" \
  --arg x86_64_darwin_hash "sha256:${NEW_HASHES[x86_64-darwin]}" \
  --arg aarch64_darwin_suffix "${PLATFORM_SUFFIXES[aarch64-darwin]}" \
  --arg aarch64_darwin_hash "sha256:${NEW_HASHES[aarch64-darwin]}" \
  '{
    version: $version,
    sources: {
      "x86_64-linux":   { suffix: $x86_64_linux_suffix,   hash: $x86_64_linux_hash },
      "aarch64-linux":  { suffix: $aarch64_linux_suffix,  hash: $aarch64_linux_hash },
      "x86_64-darwin":  { suffix: $x86_64_darwin_suffix,  hash: $x86_64_darwin_hash },
      "aarch64-darwin": { suffix: $aarch64_darwin_suffix,  hash: $aarch64_darwin_hash }
    }
  }' > "$HASHES_TMP" && mv "$HASHES_TMP" "$HASHES_JSON"

echo "Updated $HASHES_JSON to version $latest_version"
