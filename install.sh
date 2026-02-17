#!/usr/bin/env bash
set -euo pipefail

# GitHub Copilot CLI Installation Script
# Usage: curl -fsSL https://gh.io/copilot-install | bash
#    or: wget -qO- https://gh.io/copilot-install | bash
# Use | sudo bash to run as root and install to /usr/local/bin
# Export PREFIX to install to $PREFIX/bin/ directory (default: /usr/local for
# root, $HOME/.local for non-root), e.g., export PREFIX=$HOME/custom to install
# to $HOME/custom/bin

echo "Installing GitHub Copilot CLI..."

# Detect platform
OS="$(uname -s 2>/dev/null || echo "")"
case "$OS" in
  Darwin*) PLATFORM="darwin" ;;
  Linux*) PLATFORM="linux" ;;
  MINGW*|MSYS*|CYGWIN*)
    if command -v winget >/dev/null 2>&1; then
      echo "Windows detected. Installing via winget..."
      winget install GitHub.Copilot
      exit $?
    fi

    echo "Error: Windows detected but winget not found. Please see https://gh.io/install-copilot-readme" >&2
    exit 1
    ;;
  *)
    echo "Error: Unsupported operating system '$OS'. Please see https://gh.io/install-copilot-readme" >&2
    exit 1
    ;;
esac

# Detect architecture
case "$(uname -m)" in
  x86_64|amd64) ARCH="x64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *) echo "Error: Unsupported architecture $(uname -m)" >&2 ; exit 1 ;;
esac

# Determine download URL based on VERSION
if [ -n "${VERSION:-}" ]; then
  # Prefix version with 'v' if not already present
  case "$VERSION" in
    v*) ;;
    *) VERSION="v$VERSION" ;;
  esac
  DOWNLOAD_URL="https://github.com/github/copilot-cli/releases/download/${VERSION}/copilot-${PLATFORM}-${ARCH}.tar.gz"
else
  DOWNLOAD_URL="https://github.com/github/copilot-cli/releases/latest/download/copilot-${PLATFORM}-${ARCH}.tar.gz"
fi
echo "Downloading from: $DOWNLOAD_URL"

# Download and extract with error handling
TMP_TARBALL="$(mktemp)"
TMP_DIR=""
cleanup() {
  rm -f "$TMP_TARBALL"
  if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
    rm -rf "$TMP_DIR"
  fi
}
trap cleanup EXIT

if command -v curl >/dev/null 2>&1; then
  curl --fail --silent --show-error --location --retry 3 --connect-timeout 10 --max-time 300 "$DOWNLOAD_URL" -o "$TMP_TARBALL"
elif command -v wget >/dev/null 2>&1; then
  wget -q --tries=3 --timeout=30 -O "$TMP_TARBALL" "$DOWNLOAD_URL"
else
  echo "Error: Neither curl nor wget found. Please install one of them."
  exit 1
fi

# Check that the file is a valid tarball
if ! tar -tzf "$TMP_TARBALL" >/dev/null 2>&1; then
  echo "Error: Downloaded file is not a valid tarball or is corrupted." >&2
  exit 1
fi

# Check if running as root, fallback to non-root
if [ "$(id -u 2>/dev/null || echo 1)" -eq 0 ]; then
  PREFIX="${PREFIX:-/usr/local}"
else
  PREFIX="${PREFIX:-$HOME/.local}"
fi
INSTALL_DIR="$PREFIX/bin"
if ! mkdir -p "$INSTALL_DIR"; then
  echo "Error: Could not create directory $INSTALL_DIR. You may not have write permissions." >&2
  echo "Try running this script with sudo or set PREFIX to a directory you own (e.g., export PREFIX=\$HOME/.local)." >&2
  exit 1
fi

# Install binary
if [ -f "$INSTALL_DIR/copilot" ]; then
  echo "Notice: Replacing copilot binary found at $INSTALL_DIR/copilot."
fi

TMP_DIR="$(mktemp -d)"
tar -xzf "$TMP_TARBALL" -C "$TMP_DIR"

if [ ! -f "$TMP_DIR/copilot" ]; then
  echo "Error: Downloaded archive does not contain a 'copilot' binary at the archive root." >&2
  exit 1
fi

install -m 755 "$TMP_DIR/copilot" "$INSTALL_DIR/copilot"
echo "✓ GitHub Copilot CLI installed to $INSTALL_DIR/copilot"

# Check if install directory is in PATH
case ":$PATH:" in
  *":$INSTALL_DIR:"*) ;;
  *)
    echo ""
    echo "Warning: $INSTALL_DIR is not in your PATH"
    echo "Add it to your PATH by adding this line to your shell profile:"
    echo "  export PATH=\"\$PATH:$INSTALL_DIR\""
    ;;
esac

echo ""
echo "Installation complete! Run 'copilot help' to get started."
