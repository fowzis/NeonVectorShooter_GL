#!/usr/bin/env bash
# Wine prefix for MonoGame MGFXC on Linux (MonoGame 3.8.x / mgcb uses .NET 6 in Wine).
# Modeled on: https://github.com/MonoGame/MonoGame/blob/develop/Tools/MonoGame.Effect.Compiler/mgfxc_wine_setup.sh
# Default prefix matches Directory.Build.targets: ~/.winemonogame (override with MGFXC_WINE_PATH).

set -euo pipefail

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

# MGFXC always starts a process named "wine64". Ubuntu's "wine" package often has no wine64 on PATH,
# but the real 64-bit loader is /usr/lib/wine/wine64 — a shim that runs "wine" breaks 64-bit dotnet.exe
# (ShellExecuteEx via syswow64). Prefer symlink to the loader; fall back to a wine script only if needed.
ensure_wine64_on_path() {
  if [[ -x /usr/bin/wine64 ]]; then
    return 0
  fi

  local shim_dir="$HOME/.local/bin"
  mkdir -p "$shim_dir"
  local shim="$shim_dir/wine64"

  if [[ -x /usr/lib/wine/wine64 ]]; then
    ln -sf /usr/lib/wine/wine64 "$shim"
    export PATH="$shim_dir:$PATH"
    echo "Linked $shim -> /usr/lib/wine/wine64 (MGFXC needs a real 64-bit Wine entry point)."
    return 0
  fi
  if [[ -x /usr/lib64/wine/wine64 ]]; then
    ln -sf /usr/lib64/wine/wine64 "$shim"
    export PATH="$shim_dir:$PATH"
    echo "Linked $shim -> /usr/lib64/wine/wine64."
    return 0
  fi

  if ! command -v wine >/dev/null 2>&1; then
    echo "No usable Wine 64-bit loader found (tried /usr/bin/wine64, /usr/lib/wine/wine64, wine)." >&2
    echo "Install Wine, e.g.: sudo apt install wine64 winetricks" >&2
    echo "Or see https://wiki.winehq.org/Download" >&2
    exit 1
  fi

  cat >"$shim" <<'SHIM'
#!/bin/sh
# Last resort: may not run MGFXC/dotnet correctly. Prefer: ln -sf /usr/lib/wine/wine64 ~/.local/bin/wine64
export WINEARCH="${WINEARCH:-win64}"
exec wine "$@"
SHIM
  chmod +x "$shim"
  export PATH="$shim_dir:$PATH"
  echo "WARNING: Created $shim -> wine (WoW64). MGFXC may fail; install a distro that provides /usr/lib/wine/wine64." >&2
  case ":$PATH:" in
    *":$shim_dir:"*) ;;
    *)
      echo "Tip: add to ~/.profile:  export PATH=\"$shim_dir:\$PATH\""
      ;;
  esac
}

ensure_wine64_on_path
need_cmd 7z

# Snap's curl often dies on large files with: curl: (23) client returned ERROR on write.
# Prefer wget or /usr/bin/curl (PATH trimmed so Snap is not picked first).
need_downloader() {
  if [[ -x /usr/bin/wget ]] || command -v wget >/dev/null 2>&1; then return 0; fi
  if [[ -x /usr/bin/curl ]]; then return 0; fi
  if command -v curl >/dev/null 2>&1; then return 0; fi
  echo "Need wget or curl. Prefer: sudo apt install wget" >&2
  exit 1
}

download_file() {
  local url=$1 dest=$2
  rm -f "$dest"
  if [[ -x /usr/bin/wget ]]; then
    /usr/bin/wget -q -O "$dest" "$url" && return 0
  fi
  if command -v wget >/dev/null 2>&1; then
    wget -q -O "$dest" "$url" && return 0
  fi
  if [[ -x /usr/bin/curl ]]; then
    PATH="/usr/bin:/bin:/usr/local/bin" /usr/bin/curl -fsSL "$url" -o "$dest" && return 0
  fi
  if command -v curl >/dev/null 2>&1; then
    echo "Warning: using curl from PATH. If download fails with curl (23), install wget: sudo apt install wget" >&2
    curl -fsSL "$url" -o "$dest" && return 0
  fi
  echo "Download failed (no working wget/curl)." >&2
  return 1
}

need_downloader

# Quieter Wine logs (RpcSs/OLE). Override with WINEDEBUG=… if you need traces.
export WINEDEBUG="${WINEDEBUG:--all}"

WINE_VERSION=$(wine64 --version 2>&1 | grep -oE 'wine-[0-9]+' | head -1 | sed 's/wine-//' || true)
[[ -z "$WINE_VERSION" ]] && WINE_VERSION=0
if (( WINE_VERSION < 8 )); then
  echo "Wine version ${WINE_VERSION:-unknown} is below the minimum required version (8.0)." >&2
  exit 1
fi

export WINEARCH=win64
export WINEPREFIX="${MGFXC_WINE_PATH:-$HOME/.winemonogame}"
echo "Using WINEPREFIX=$WINEPREFIX"

wine64 wineboot --init
echo "(First-time wineboot can log OLE/RpcSs noise; it is usually harmless.)"

TEMP_DIR="${TMPDIR:-/tmp}"
SCRIPT_DIR="$TEMP_DIR/winemg-mgfxc-setup"
mkdir -p "$SCRIPT_DIR"

cat >"$SCRIPT_DIR/crashdialog.reg" <<'_EOF_'
REGEDIT4
[HKEY_CURRENT_USER\Software\Wine\WineDbg]
"ShowCrashDialog"=dword:00000000
_EOF_
wine64 regedit "$SCRIPT_DIR/crashdialog.reg"

# MonoGame 3.8.1 mgfxc targets .NET 6 (see mgfxc.runtimeconfig.json in dotnet-mgcb package).
DOTNET_URL="https://builds.dotnet.microsoft.com/dotnet/Sdk/6.0.428/dotnet-sdk-6.0.428-win-x64.zip"
echo "Downloading .NET 6 Windows SDK (~200 MiB)..."
download_file "$DOTNET_URL" "$SCRIPT_DIR/dotnet-sdk.zip"
7z x "$SCRIPT_DIR/dotnet-sdk.zip" -o"$WINEPREFIX/drive_c/windows/system32/" -y -bd

FIREFOX_URL="https://download-installer.cdn.mozilla.net/pub/firefox/releases/62.0.3/win64/ach/Firefox%20Setup%2062.0.3.exe"
echo "Downloading Firefox stub (for d3dcompiler_47.dll)..."
download_file "$FIREFOX_URL" "$SCRIPT_DIR/firefox.exe"
7z e "$SCRIPT_DIR/firefox.exe" "core/d3dcompiler_47.dll" -o"$WINEPREFIX/drive_c/windows/system32/" -aoa -y -bd

rm -rf "$SCRIPT_DIR"

# Drain Wine for this prefix so stray RpcSs/OLE lines are less likely after the script returns.
if command -v wineserver >/dev/null 2>&1; then
  wineserver -w 2>/dev/null || true
fi

echo
echo "Done. MGFXC_WINE_PATH should be your prefix (Directory.Build.targets defaults to ~/.winemonogame if unset)."
echo "Add to ~/.profile if you want it in every shell:"
echo "  export MGFXC_WINE_PATH=\"$WINEPREFIX\""
echo "Next: ensure ~/.local/bin is on PATH, then run:  dotnet build"
