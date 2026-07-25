# kotlin-lsp-flake — AGENTS.md

Nix flake for [Kotlin Language Server](https://github.com/Kotlin/kotlin-lsp) (kotlin-lsp). Downloads prebuilt JRE-bundled binaries from JetBrains CDN.

## Repo structure

| File | Purpose |
|---|---|
| `flake.nix` | Flake entrypoint — calls `package.nix` per system, exposes an overlay |
| `package.nix` | Derivation — fetches JRE-bundled `.zip` from JetBrains CDN, uses `autoPatchelfHook` on Linux |
| `hashes.json` | Version + per-system suffix+SRI-hash map |
| `update.sh` | Fetches latest release from GitHub API, re-hashes from JetBrains CDN, writes `hashes.json` |
| `.github/workflows/ci.yml` | PR/push CI: `nix build .#kotlin-lsp` on 3 OS matrices — triggered on `pull_request` and `push` to `main` |
| `.github/workflows/update.yml` | Daily cron: `update.sh` → build → PR |

## Key commands

```bash
# Build locally
nix build .#kotlin-lsp

# Build with alias (kotlin-ls)
nix build .#kotlin-ls

# Update to latest upstream release
bash update.sh
nix build .#kotlin-lsp
```

`update.sh --force` re-fetches hashes even if the version hasn't changed — useful for hash refresh when the same tag was re-released.

## Supported systems

`x86_64-linux`, `aarch64-linux`, `x86_64-darwin`, `aarch64-darwin`.

## Platform suffix mapping

| Nix system | URL suffix |
|---|---|
| `x86_64-linux` | `linux-x64` |
| `aarch64-linux` | `linux-aarch64` |
| `x86_64-darwin` | `mac-x64` |
| `aarch64-darwin` | `mac-aarch64` |

## Packaging quirks

- **JRE-bundled**: The download includes a full JRE, so no JVM is needed at runtime.
- **Linux (`autoPatchelfHook`)**: On Linux, `autoPatchelfHook` patches the bundled JRE binaries for NixOS compatibility. Required libraries (alsa-lib, freetype, libgcc, libx11, libxi, libxrender, libxtst, wayland, zlib) are provided as `buildInputs`.
- **macOS**: No `autoPatchelfHook` — the JRE for macOS is used as-is.
- **`kotlin-ls` alias**: The `extraBinNames` parameter creates a `kotlin-ls` symlink alongside `kotlin-lsp` in `$out/bin`.
- **JRE path difference**: On macOS the JRE lives under `jre/Contents/Home/bin`, on Linux under `jre/bin`.
- **`kotlin-lsp.sh`**: The actual entrypoint is a shell script — `postInstall` replaces `chmod` calls in it to avoid permission errors under the Nix store.

## Updating

The auto-update workflow (`.github/workflows/update.yml`) runs daily at midnight UTC and can be triggered manually via `workflow_dispatch`. It runs `update.sh`, builds the derivation, and opens a PR on the `auto-update` branch. Binary version verification is handled by `.github/workflows/ci.yml` (read-only `pull_request` workflow).

## CI

`.github/workflows/ci.yml` runs `nix build .#kotlin-lsp` on every PR targeting `main` and every push to `main`, across 3 OS matrices (`ubuntu-latest`, `macos-latest`, `macos-15-intel`). It verifies the derivation builds, the binary exists, and optionally compares the built version against `hashes.json`.

## Auto-update PR and CI

The auto-update workflow creates PRs on the `auto-update` branch. For CI to run automatically on those PRs (via the `pull_request` trigger in `ci.yml`), a **GitHub Personal Access Token (PAT)** must be configured:

1. Create a fine-grained PAT at https://github.com/settings/tokens with:
   - Repository access: `turtton/kotlin-lsp-flake` only
   - Permissions: **Contents** (Read and write), **Pull requests** (Read and write)
2. Add it as a repository secret: **Settings → Secrets and variables → Actions → New repository secret**
   - Name: `PAT_TOKEN`
   - Value: the PAT you created

Without `PAT_TOKEN`, the workflow falls back to `GITHUB_TOKEN`. PRs are still created, but CI runs must be approved manually on the PR page ("Approve and run").

**Important**: If `PAT_TOKEN` is set but expired or revoked, the expression `${{ secrets.PAT_TOKEN || secrets.GITHUB_TOKEN }}` evaluates the expired token as truthy (non-empty string), so the fallback to `GITHUB_TOKEN` does **not** activate. The `create-pull-request` step will fail with an authentication error. To recover:
- Renew the PAT at https://github.com/settings/tokens
- Update the repository secret with the new token
- Alternatively, delete the `PAT_TOKEN` secret to revert to `GITHUB_TOKEN` behavior

## No tests

There are no unit or integration tests. Verification is: `nix build .#kotlin-lsp` succeeds and the binary reports the expected version (when `--version` output format is known).
