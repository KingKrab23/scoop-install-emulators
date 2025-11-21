#!/usr/bin/env bash

# ---------------------------------------
#  Emulator Version Pin Manager
#  - Uses Scoop hold/unhold
#  - Modes: hold | unhold | status
#  - Logs to /c/emulation/emulators/logs
# ---------------------------------------

ROOT="/c/emulation/emulators"
LOGDIR="$ROOT/.emulator-install/logs"
mkdir -p "$LOGDIR"

LOGFILE="$LOGDIR/pin_$(date +%Y%m%d_%H%M%S).log"
echo "[*] Logging to: $LOGFILE"

exec > >(tee -a "$LOGFILE") 2>&1

CORE_EMULATORS=(
  retroarch       # Multi-System Frontend
  snes9x          # Super Nintendo (SNES)
  mgba            # Game Boy Advance (GBA)
  azahar          # Nintendo 3DS (formerly Citra/Lime3DS)
  dolphin         # GameCube / Wii
  cemu            # Wii U
  melonds         # Nintendo DS
  duckstation     # PlayStation 1 (PSX)
  pcsx2           # PlayStation 2 (PS2)
  ppsspp          # PlayStation Portable (PSP)
  rpcs3           # PlayStation 3 (PS3)
  xemu            # Original Xbox
  xenia-canary    # Xbox 360
  mame            # Arcade
  stella          # Atari 2600
  vita3k          # PlayStation Vita
  bigpemu         # Atari Jaguar
  rmg             # Nintendo 64 (Rosalie's Mupen GUI)
  mesen           # NES / SNES / PC Engine / Game Boy
  flycast         # Dreamcast / Naomi
  supermodel      # Sega Model 3 Arcade
  ryujinx         # Nintendo Switch
  ares            # Multi-System (High Accuracy)
)

SWITCH_FORKS=(
  eden            # Switch Fork
  sudachi         # Switch Fork
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

get_symlink_name() {
    local app=$1
    case "$app" in
        retroarch)    echo "Multi_RetroArch" ;;
        snes9x)       echo "Nintendo_SNES_Snes9x" ;;
        mgba)         echo "Nintendo_GBA_mGBA" ;;
        azahar)       echo "Nintendo_3DS_Azahar" ;;
        dolphin)      echo "Nintendo_GameCube_Wii_Dolphin" ;;
        cemu)         echo "Nintendo_WiiU_Cemu" ;;
        melonds)      echo "Nintendo_DS_melonDS" ;;
        duckstation)  echo "Sony_PS1_DuckStation" ;;
        pcsx2)        echo "Sony_PS2_PCSX2" ;;
        ppsspp)       echo "Sony_PSP_PPSSPP" ;;
        rpcs3)        echo "Sony_PS3_RPCS3" ;;
        xemu)         echo "Microsoft_Xbox_Xemu" ;;
        xenia-canary) echo "Microsoft_Xbox360_Xenia" ;;
        mame)         echo "Arcade_MAME" ;;
        stella)       echo "Atari_2600_Stella" ;;
        vita3k)       echo "Sony_Vita_Vita3K" ;;
        bigpemu)      echo "Atari_Jaguar_BigPEmu" ;;
        rmg)          echo "Nintendo_N64_RMG" ;;
        mesen)        echo "Multi_NES_SNES_Mesen" ;;
        flycast)      echo "Sega_Dreamcast_Flycast" ;;
        supermodel)   echo "Sega_Model3_Supermodel" ;;
        ryujinx)      echo "Nintendo_Switch_Ryujinx" ;;
        ares)         echo "Multi_Ares" ;;
        eden)         echo "Nintendo_Switch_Eden" ;;
        citron)       echo "Nintendo_Switch_Citron" ;;
        sudachi)      echo "Nintendo_Switch_Sudachi" ;;
        suyu)         echo "Nintendo_Switch_Suyu" ;;
        *)            echo "$app" ;;
    esac
}

# ---------------------------------------
# Fallback Download Functions
# ---------------------------------------

install_github_release() {
    local app="$1"
    local repo="$2"
    local filter="$3" # e.g. "win64"
    
    echo "   ! Scoop install failed. Attempting GitHub Release download..."
    echo "   Repo: $repo"
    
    # Get latest release data
    local api_url="https://api.github.com/repos/$repo/releases/latest"
    local download_url=$(curl -s "$api_url" | jq -r ".assets[] | select(.name | test(\"$filter\"; \"i\")) | .browser_download_url" | head -n 1)
    
    if [ -z "$download_url" ] || [ "$download_url" == "null" ]; then
        echo "   [!] Could not find a release asset matching '$filter' in $repo"
        return 1
    fi
    
    echo "   Downloading: $download_url"
    local filename=$(basename "$download_url")
    local dest_dir="$ROOT/$app"
    
    mkdir -p "$dest_dir"
    curl -L -o "$dest_dir/$filename" "$download_url"
    
    echo "   Extracting to $dest_dir..."
    if command -v 7z >/dev/null 2>&1; then
        7z x "$dest_dir/$filename" -o"$dest_dir" -y >/dev/null
    else
        echo "   [!] 7z not found. Please install 7zip (scoop install 7zip)."
        return 1
    fi
    
    # Cleanup
    rm "$dest_dir/$filename"
    
    # Create Symlink
    link_name=$(get_symlink_name "$app")
    echo "   → Linking $ROOT/$link_name -> $dest_dir"
    ln -sfn "$dest_dir" "$ROOT/$link_name"
    
    echo "   ✓ Installed $app from GitHub"
}

install_manual_url() {
    local app="$1"
    local url="$2"
    
    echo "   ! Scoop install failed. Attempting Direct Download..."
    echo "   URL: $url"
    
    local filename=$(basename "$url")
    local dest_dir="$ROOT/$app"
    
    mkdir -p "$dest_dir"
    curl -L -o "$dest_dir/$filename" "$url"
    
    echo "   Extracting to $dest_dir..."
    if command -v 7z >/dev/null 2>&1; then
        7z x "$dest_dir/$filename" -o"$dest_dir" -y >/dev/null
    else
        echo "   [!] 7z not found. Please install 7zip (scoop install 7zip)."
        return 1
    fi
    
    # Cleanup
    rm "$dest_dir/$filename"
    
    # Create Symlink
    link_name=$(get_symlink_name "$app")
    echo "   → Linking $ROOT/$link_name -> $dest_dir"
    ln -sfn "$dest_dir" "$ROOT/$link_name"
    
    echo "   ✓ Installed $app from Direct Link"
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
            scoop install "$app@$pinned_ver"
        fi
    else
        echo "   No pin found. Checking installation..."
        if [ -z "$current_ver" ]; then
            echo "   Installing latest $app..."
            scoop install "$app"
            # Update current_ver after install
            current_ver=$(get_installed_version "$app")
        fi
        
        if [ -n "$current_ver" ]; then
            set_pinned_version "$app" "$current_ver"
        else
            # Fallback for specific apps
            if [ "$app" == "bigpemu" ]; then
                install_manual_url "bigpemu" "https://www.richwhitehouse.com/jaguar/builds/BigPEmu_v119.zip"
            else
                echo "   [!] Could not determine version for $app (Install failed?)"
            fi
        fi
    fi

    # Create Symlink
    if [ -d "$HOME/scoop/apps/$app/current" ]; then
        link_name=$(get_symlink_name "$app")
        echo "   → Linking $ROOT/$link_name -> Scoop Current"
        ln -sfn "$HOME/scoop/apps/$app/current" "$ROOT/$link_name"
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
            scoop install "$app@$pinned_ver"
        fi
    else
        echo "   No pin found. Checking installation..."
        if [ -z "$current_ver" ]; then
            echo "   Installing latest $app..."
            scoop install "$app"
            current_ver=$(get_installed_version "$app")
        fi
        
        if [ -n "$current_ver" ]; then
            set_pinned_version "$app" "$current_ver"
        else
            echo "   [!] Could not determine version for $app (Install failed?)"
        fi
    fi

    # Create Symlink
    if [ -d "$HOME/scoop/apps/$app/current" ]; then
        link_name=$(get_symlink_name "$app")
        echo "   → Linking $ROOT/$link_name -> Scoop Current"
        ln -sfn "$HOME/scoop/apps/$app/current" "$ROOT/$link_name"
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
