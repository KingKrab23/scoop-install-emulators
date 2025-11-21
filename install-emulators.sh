#!/usr/bin/env bash

# ---------------------------------------
#  Emulator Version Pin Manager
#  - Uses Scoop hold/unhold
#  - Modes: hold | unhold | status
#  - Logs to /c/emulation/emulators/logs
# ---------------------------------------

ROOT="/c/emulation/emulators"
LOGDIR="$ROOT/logs"
mkdir -p "$LOGDIR"

LOGFILE="$LOGDIR/pin_$(date +%Y%m%d_%H%M%S).log"
echo "[*] Logging to: $LOGFILE"

exec > >(tee -a "$LOGFILE") 2>&1

CORE_EMULATORS=(
  retroarch
  snes9x
  mgba
  lime3ds
  dolphin
  cemu
  melonds
  duckstation
  pcsx2
  ppsspp
  rpcs3
  xemu
  xenia-canary
  mame
  stella
  vita3k
  bigpemu
  rmg
  mesen
  flycast
  supermodel
  ryujinx
  ares
)

SWITCH_FORKS=(
  eden
  citron
  sudachi
  suyu
)

ALL_EMULATORS=("${CORE_EMULATORS[@]}" "${SWITCH_FORKS[@]}")

MODE="${1:-status}"
TARGET_APP="$2"
JSON_FILE="emulator-versions.json"

# ---------------------------------------
# Helper Functions
# ---------------------------------------

ensure_jq() {
    if ! command -v jq &> /dev/null; then
        echo "[!] 'jq' is required but not found. Installing via Scoop..."
        scoop install jq
    fi
}

ensure_bucket() {
    scoop bucket add extras      >/dev/null 2>&1 || true
    scoop bucket add games       >/dev/null 2>&1 || true
    scoop bucket add versions    >/dev/null 2>&1 || true
    scoop bucket add dorado      >/dev/null 2>&1 || true
}

ensure_json() {
    if [ ! -f "$JSON_FILE" ]; then
        echo "{}" > "$JSON_FILE"
    fi
}

get_pinned_version() {
    local app=$1
    jq -r --arg a "$app" '.[$a] // empty' "$JSON_FILE"
}

set_pinned_version() {
    local app=$1
    local ver=$2
    local tmp=$(mktemp)
    jq --arg a "$app" --arg v "$ver" '.[$a] = $v' "$JSON_FILE" > "$tmp" && mv "$tmp" "$JSON_FILE"
    echo "   ✓ Pinned $app to version $ver in $JSON_FILE"
}

get_installed_version() {
    local app=$1
    # Parse scoop list output: "app  1.2.3  ..."
    scoop list "$app" 2>/dev/null | grep -E "^$app\s+" | awk '{print $2}' | head -n 1
}

install_app() {
    local app="$1"
    echo ""
    echo "==============================="
    echo " Installing $app..."
    echo "==============================="
    
    pinned_ver=$(get_pinned_version "$app")
    
    # Check if installed by looking for version
    current_ver=$(get_installed_version "$app")
    
    if [ -n "$pinned_ver" ]; then
        echo "   Target version: $pinned_ver (pinned)"
        
        if [ "$current_ver" == "$pinned_ver" ]; then
            echo "   ✓ Already on version $pinned_ver"
        else
            echo "   ! Installing specific version $pinned_ver..."
            scoop install "$app@$pinned_ver" --dir "$ROOT/$app"
        fi
    else
        echo "   No pin found. Checking installation..."
        if [ -z "$current_ver" ]; then
            echo "   Installing latest $app..."
            scoop install "$app" --dir "$ROOT/$app"
            # Update current_ver after install
            current_ver=$(get_installed_version "$app")
        fi
        
        if [ -n "$current_ver" ]; then
            set_pinned_version "$app" "$current_ver"
        else
            echo "   [!] Could not determine version for $app (Install failed?)"
        fi
    fi
}

install_optional() {
    local app="$1"
    echo ""
    echo "==============================="
    echo " Installing Optional: $app..."
    echo "==============================="
    
    pinned_ver=$(get_pinned_version "$app")
    current_ver=$(get_installed_version "$app")
    
    if [ -n "$pinned_ver" ]; then
        echo "   Target version: $pinned_ver (pinned)"
        
        if [ "$current_ver" == "$pinned_ver" ]; then
            echo "   ✓ Already on version $pinned_ver"
        else
            echo "   ! Installing specific version $pinned_ver..."
            scoop install "$app@$pinned_ver" --dir "$ROOT/$app"
        fi
    else
        echo "   No pin found. Checking installation..."
        if [ -z "$current_ver" ]; then
            echo "   Installing latest $app..."
            scoop install "$app" --dir "$ROOT/$app"
            current_ver=$(get_installed_version "$app")
        fi
        
        if [ -n "$current_ver" ]; then
            set_pinned_version "$app" "$current_ver"
        else
            echo "   [!] Could not determine version for $app (Install failed?)"
        fi
    fi
}

# ---------------------------------------
# Main Logic
# ---------------------------------------

ensure_jq
ensure_bucket
ensure_json

case "$MODE" in
  install)
    echo "[*] Installing/Syncing emulators..."
    
    echo "--- Core Emulators ---"
    for app in "${CORE_EMULATORS[@]}"; do
        install_app "$app"
    done

    echo "--- Switch Forks (Optional) ---"
    for app in "${SWITCH_FORKS[@]}"; do
        install_optional "$app"
    done
    ;;

  update)
    # Usage: ./script update [app_name|all]
    target="${TARGET_APP:-all}"
    
    if [ "$target" == "all" ]; then
        echo "[*] Updating ALL emulators to latest..."
        for app in "${ALL_EMULATORS[@]}"; do
            echo "→ Updating $app..."
            scoop update "$app"
            new_ver=$(get_installed_version "$app")
            set_pinned_version "$app" "$new_ver"
        done
    else
        # Update specific app
        if [[ " ${ALL_EMULATORS[*]} " =~ " ${target} " ]]; then
            echo "→ Updating $target..."
            scoop update "$target"
            new_ver=$(get_installed_version "$target")
            set_pinned_version "$target" "$new_ver"
        else
            echo "[!] Unknown emulator: $target"
            exit 1
        fi
    fi
    ;;

  check)
    echo "[*] Checking installation status..."
    printf "%-15s %-15s %-15s\n" "Emulator" "Pinned" "Installed"
    echo "------------------------------------------------"
    for app in "${ALL_EMULATORS[@]}"; do
      pinned=$(get_pinned_version "$app")
      installed=$(get_installed_version "$app")
      
      if [ -z "$pinned" ]; then pinned="(none)"; fi
      if [ -z "$installed" ]; then installed="(missing)"; fi
      
      printf "%-15s %-15s %-15s\n" "$app" "$pinned" "$installed"
    done
    ;;

  status)
    echo "[*] Scoop status:"
    scoop status
    ;;

  *)
    echo "Usage: $0 [install|update <app>|check|status]"
    echo "  install : Install pinned versions from json, or latest if missing"
    echo "  update  : Update app(s) to latest and update json pin"
    echo "  check   : Show pinned vs installed versions"
    exit 1
    ;;
esac

echo ""
echo "========================================="
echo "  ✓ pin_emulators.sh finished ($MODE)"
echo "  → Log saved to: $LOGFILE"
echo "========================================="
