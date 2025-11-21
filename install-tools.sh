#!/usr/bin/env bash

# ---------------------------------------
#  Tool Installer for Emulator Helpers
#  - NX-Optimizer, Reloaded-II, GlumSak, EmuSAK, STSYPE
# ---------------------------------------

ROOT="/c/emulation/tools"
LOGDIR="$ROOT/.tool-install-logs"
mkdir -p "$LOGDIR"

LOGFILE="$LOGDIR/install_$(date +%Y%m%d_%H%M%S).log"
echo "[*] Logging to: $LOGFILE"

exec > >(tee -a "$LOGFILE") 2>&1

# ---------------------------------------
# Helper Functions
# ---------------------------------------

ensure_7zip() {
    if ! command -v 7z &> /dev/null; then
        echo "[!] 7zip not found. Installing..."
        scoop install 7zip
    fi
}

ensure_curl() {
    if ! command -v curl &> /dev/null; then
        echo "[!] curl not found. Installing..."
        scoop install curl
    fi
}

ensure_jq() {
    if ! command -v jq &> /dev/null; then
        echo "[!] jq not found. Installing..."
        scoop install jq
    fi
}

ensure_bucket() {
    scoop bucket add games >/dev/null 2>&1 || true
}

install_github_release() {
    local app="$1"
    local repo="$2"
    local filter="$3"

    echo ""
    echo "==============================="
    echo " Installing $app from GitHub..."
    echo "==============================="
    echo "   Repo: $repo"

    local api_url="https://api.github.com/repos/$repo/releases/latest"
    local json
    json="$(curl -s "$api_url")"

    # Avoid 'Cannot iterate over null' by defaulting .assets to []
    local download_url
    download_url="$(echo "$json" | jq -r ".assets // [] | .[] | select(.name | test(\"$filter\"; \"i\")) | .browser_download_url" | head -n 1)"

    if [ -z "$download_url" ] || [ "$download_url" = "null" ]; then
        echo "   [!] Could not find a release asset matching '$filter' in $repo"
        return 1
    fi

    echo "   Downloading: $download_url"
    local filename
    filename="$(basename "$download_url")"
    local dest_dir="$ROOT/$app"

    mkdir -p "$dest_dir"
    curl -L -o "$dest_dir/$filename" "$download_url"

    # Extract if it's an archive
    if [[ "$filename" == *.zip ]] || [[ "$filename" == *.7z ]]; then
        echo "   Extracting to $dest_dir..."
        ensure_7zip
        7z x "$dest_dir/$filename" -o"$dest_dir" -y >/dev/null
        rm "$dest_dir/$filename"
    fi

    echo "   ✓ Installed $app to $dest_dir"
}

install_direct_archive() {
    local app="$1"
    local url="$2"

    echo ""
    echo "==============================="
    echo " Installing $app from direct URL..."
    echo "==============================="
    echo "   URL: $url"

    local filename
    filename="$(basename "$url")"
    local dest_dir="$ROOT/$app"

    mkdir -p "$dest_dir"
    curl -L -o "$dest_dir/$filename" "$url"

    if [[ "$filename" == *.zip ]] || [[ "$filename" == *.7z ]]; then
        echo "   Extracting to $dest_dir..."
        ensure_7zip
        7z x "$dest_dir/$filename" -o"$dest_dir" -y >/dev/null
        rm "$dest_dir/$filename"
    fi

    echo "   ✓ Installed $app to $dest_dir"
}

install_scoop_app() {
    local app="$1"

    echo ""
    echo "==============================="
    echo " Installing $app via Scoop..."
    echo "==============================="

    if scoop list "$app" 2>/dev/null | grep -q "$app"; then
        echo "   ✓ $app already installed"
    else
        scoop install "$app"
        echo "   ✓ Installed $app"
    fi
}

# ---------------------------------------
# Main Installation
# ---------------------------------------

ensure_curl
ensure_jq
ensure_7zip
ensure_bucket

echo ""
echo "========================================="
echo "  Tool Installer"
echo "========================================="
echo ""
echo "This will install the following tools:"
echo "  1. NX-Optimizer (GitHub)"
echo "  2. Reloaded-II (Scoop)"
echo "  3. GlumSak (GitHub)"
echo "  4. EmuSAK (SourceForge mirror)"
echo "  5. STSYPE (manual step only, no auto-download)"
echo ""
read -p "Continue? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

# NX-Optimizer
install_github_release "nx-optimizer" "MaxLastBreath/nx-optimizer" "exe"

# Reloaded-II
install_scoop_app "reloaded-ii"

# GlumSak (correct repo: Glumboi/GlumSak)
install_github_release "glumsak" "Glumboi/GlumSak" "zip|setup|exe"

# EmuSAK via SourceForge mirror (portable Windows build)
# From: https://sourceforge.net/projects/emusak-ui.mirror/files/v2.1.9/
install_direct_archive "emusak" \
  "https://sourceforge.net/projects/emusak-ui.mirror/files/v2.1.9/EmuSAK-win32-x64-2.1.9-portable.zip/download"

# STSYPE – no reliable GitHub/API endpoint; user must install manually
echo ""
echo "==============================="
echo " STSYPE (manual install step)"
echo "==============================="
echo "   STS Yuzu/Ryujinx Performance Enhancer (STSYPE) is distributed via GBAtemp,"
echo "   not a public GitHub repo with API-accessible releases."
echo "   → Please download it manually from the GBAtemp page and extract it into:"
echo "       $ROOT/stsype"
mkdir -p "$ROOT/stsype"

echo ""
echo "========================================="
echo "  ✓ Tool installation complete!"
echo "  → Tools installed to: $ROOT"
echo "  → Log saved to: $LOGFILE"
echo "========================================="
