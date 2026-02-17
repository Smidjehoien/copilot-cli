# QA Audit: README.md vs install.sh (Deep Pass)

## Scope

This audit reviews:

- Consistency between `README.md` and `install.sh`
- Shell-script risk areas (error handling, fallback behavior, permissions)
- Hardening checklist for release/install workflows

## 1) Consistency Findings

### ✅ Aligned items

- README documents script usage via `curl ... | bash` and `wget ... | bash`, matching script header comments and behavior.
- README documents `PREFIX` and `VERSION`; script supports both variables and uses defaults (`/usr/local` for root and `$HOME/.local` for non-root).
- README states script is for macOS/Linux; script now explicitly supports Darwin/Linux tarball install and provides a Windows-specific fallback path only when running in Windows-like shells.

### ⚠️ Gaps / caveats to keep in mind

- README focuses on happy path; script includes important fallback and error behavior (unsupported OS, missing winget) that is not described in detail.
- README does not currently describe network retry behavior and timeout expectations.

## 2) Shell Risk Review (set -e, fallbacks, permissions)

## What was improved

- Upgraded strict mode from `set -e` to `set -euo pipefail`.
  - Prevents silent usage of unset variables.
  - Propagates failures in pipelines.
- Platform detection hardened:
  - Windows fallback via winget is now limited to Windows-like uname values (`MINGW*|MSYS*|CYGWIN*`).
  - Non-Windows unknown OS now receives an explicit unsupported-OS error instead of a misleading Windows error.
- Temporary file/dir lifecycle hardened:
  - Added `trap cleanup EXIT` to ensure temp artifacts are removed on both success and failure.
- Network download robustness improved:
  - `curl`: retries + connect/max timeout.
  - `wget`: retries + timeout.
- Archive extraction/install hardened:
  - Extract archive into a temp dir first, verify `copilot` binary exists at expected location.
  - Use `install -m 755` to place binary atomically with intended mode.

## Remaining risks (not fully addressed here)

- No cryptographic integrity verification (e.g., checksums/signatures) for release artifacts.
- No provenance verification (SLSA/in-toto, signed attestations) before install.
- Archive trust still assumes release endpoint authenticity and transport security.

## 3) Recommended Hardening Checklist (Release + Install)

### Artifact integrity and provenance

- [ ] Publish SHA-256 checksums for each artifact and verify in installer.
- [ ] Sign checksums (e.g., cosign, minisign, GPG) and verify in installer.
- [ ] Publish provenance attestations (SLSA-compatible) and document verification steps.

### Installer robustness

- [ ] Keep `set -euo pipefail` + cleanup trap.
- [ ] Keep retries/timeouts configurable via env vars for enterprise networks.
- [ ] Detect and fail on partial downloads (already partly covered by tar validation).
- [ ] Validate archive structure and expected binary name before install (implemented).
- [ ] Consider `--version` post-install smoke check (`copilot --version`) and fail if missing.

### Permissions and filesystem safety

- [ ] Keep install target under explicit `PREFIX/bin` and avoid writing outside expected tree.
- [ ] Consider checking if existing target is symlink and handle according to policy.
- [ ] Consider `umask` management for stricter default file permissions in hardened environments.

### Operational / release hygiene

- [ ] Document fallback behavior and known failure modes in README (proxy, TLS intercept, winget missing).
- [ ] Add CI test matrix for installer (Linux/macOS shells; dry-run stubs for network calls).
- [ ] Add shell linting (e.g., shellcheck) and enforce in CI.
- [ ] Add regression tests for `VERSION`, `PREFIX`, unsupported OS/arch branches.

## 4) Suggested next docs updates

- Add a short “Troubleshooting install script” section in README covering:
  - Unsupported OS message
  - Missing winget on Windows shells
  - Permission-denied on install directory
  - PATH update notes
