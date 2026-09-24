#!/usr/bin/env bash
# Installs the Cycle Tiling KWin script (KDE Plasma 6, Wayland/X11).
# Installs the package, enables it and activates it in the current session
# without re-login.
set -euo pipefail

PKG_ID="cycleTiling"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/src"
INSTALLED_MAIN="$HOME/.local/share/kwin/scripts/$PKG_ID/contents/code/main.js"
KGS="$HOME/.config/kglobalshortcutsrc"

command -v kpackagetool6 >/dev/null || { echo "Error: kpackagetool6 not found" >&2; exit 1; }
command -v kwriteconfig6 >/dev/null || { echo "Error: kwriteconfig6 not found" >&2; exit 1; }
command -v qdbus6 >/dev/null || { echo "Error: qdbus6 not found" >&2; exit 1; }

if ! kpackagetool6 --type KWin/Script --install "$SRC_DIR" 2>/dev/null; then
    echo "Package already installed — upgrading..."
    kpackagetool6 --type KWin/Script --upgrade "$SRC_DIR"
fi

# Enable the script (persists across sessions)
kwriteconfig6 --file kwinrc --group Plugins --key "${PKG_ID}Enabled" true

# --- Activate in the current session: unload the old instance and load the
# --- new one. This runs BEFORE the file edits below: kglobalaccel rewrites
# --- kglobalshortcutsrc from its in-memory state on every registration
# --- event, so entries written earlier would get clobbered. Live bindings
# --- are not changed by this — new combinations are picked up on the next
# --- KWin start (re-login).
qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript "$PKG_ID" 2>/dev/null || true
qdbus6 org.kde.KWin /KWin reconfigure 2>/dev/null || true
sleep 1
if ! qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.isScriptLoaded "$PKG_ID" 2>/dev/null | grep -qx true; then
    script_id=$(qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript "$INSTALLED_MAIN" "$PKG_ID")
    qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.start
    if [ "$script_id" -ge 0 ] 2>/dev/null; then
        qdbus6 org.kde.KWin /Scripting/Script"$script_id" org.kde.kwin.Script.run || true
    fi
fi

# --- Shortcut bindings. File-level edits only (after all registrations):
# --- they take effect on the next KWin start. Mutating a live kglobalaccel
# --- over DBus is unsafe (it once crashed KWin). Our own former defaults
# --- are updated freely; user-customized values are left untouched.
current_binding() {
    grep -m1 "^$1=" "$KGS" 2>/dev/null | cut -d= -f2- | cut -d, -f1
}

L=$(current_binding 'Cycle Tiling: Left')
case "$L" in
    ""|Meta+Ctrl+Left|Ctrl+Shift+Meta+Left)
        kwriteconfig6 --file kglobalshortcutsrc --group kwin --key 'Cycle Tiling: Left' \
            'Ctrl+Shift+Meta+Left,none,Cycle Tiling: tile window to the left edge (cycle 1/2 → 1/3 → 2/3)' ;;
    *) echo "Left: keeping user-defined binding '$L'" ;;
esac

R=$(current_binding 'Cycle Tiling: Right')
case "$R" in
    ""|Meta+Ctrl+Right|Ctrl+Shift+Meta+Right)
        kwriteconfig6 --file kglobalshortcutsrc --group kwin --key 'Cycle Tiling: Right' \
            'Ctrl+Shift+Meta+Right,none,Cycle Tiling: tile window to the right edge (cycle 1/2 → 1/3 → 2/3)' ;;
    *) echo "Right: keeping user-defined binding '$R'" ;;
esac

C=$(current_binding 'Cycle Tiling: Center')
case "$C" in
    ""|Meta+Ctrl+Return|Ctrl+Shift+Meta+Return)
        kwriteconfig6 --file kglobalshortcutsrc --group kwin --key 'Cycle Tiling: Center' \
            'Ctrl+Shift+Meta+Return,none,Cycle Tiling: center window (2/3 width and full height)' ;;
    *) echo "Center: keeping user-defined binding '$C'" ;;
esac

M=$(current_binding 'Cycle Tiling: Maximize')
case "$M" in
    ""|Ctrl+Shift+Meta+Space)
        kwriteconfig6 --file kglobalshortcutsrc --group kwin --key 'Cycle Tiling: Maximize' \
            'Ctrl+Shift+Meta+Space,none,Cycle Tiling: toggle maximize window (fill the whole screen)' ;;
    *) echo "Maximize: keeping user-defined binding '$M'" ;;
esac

# Disable the built-in Meta+Left/Right quick tiles (half-screen tiling) —
# Cycle Tiling replaces them. Left untouched if the user rebound them.
QL=$(current_binding 'Window Quick Tile Left')
case "$QL" in
    ""|Meta+Left)
        kwriteconfig6 --file kglobalshortcutsrc --group kwin --key 'Window Quick Tile Left' \
            'none,Meta+Left,Tile window to the left half of the screen' ;;
esac

QR=$(current_binding 'Window Quick Tile Right')
case "$QR" in
    ""|Meta+Right)
        kwriteconfig6 --file kglobalshortcutsrc --group kwin --key 'Window Quick Tile Right' \
            'none,Meta+Right,Tile window to the right half of the screen' ;;
esac

# v1.0 used to disable the stock desktop-switching defaults (Meta+Ctrl+
# arrows); the new combinations do not conflict with them — restore stock.
for key in 'Switch One Desktop to the Left' 'Switch One Desktop to the Right'; do
    if [ "$(current_binding "$key")" = "none" ]; then
        kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "$key" --delete || true
    fi
done

echo "Installed. Shortcuts: Ctrl+Shift+Meta+Left / Ctrl+Shift+Meta+Right / Ctrl+Shift+Meta+Return / Ctrl+Shift+Meta+Space"
echo "Shortcut changes and disabling of Meta+Left/Right take effect on the next login."
echo "Script errors (if something does not work): journalctl --user -b --no-pager | grep cycleTiling"
