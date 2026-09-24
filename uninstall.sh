#!/usr/bin/env bash
# Removes the Cycle Tiling KWin script and restores stock KWin shortcuts.
set -euo pipefail

PKG_ID="cycleTiling"
KGS="$HOME/.config/kglobalshortcutsrc"

current_binding() {
    grep -m1 "^$1=" "$KGS" 2>/dev/null | cut -d= -f2- | cut -d, -f1
}

qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript "$PKG_ID" 2>/dev/null || true
kpackagetool6 --type KWin/Script --remove "$PKG_ID"
kwriteconfig6 --file kwinrc --group Plugins --key "${PKG_ID}Enabled" --delete || true

for key in 'Cycle Tiling: Left' 'Cycle Tiling: Right' 'Cycle Tiling: Center'; do
    kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "$key" --delete || true
done

# Restore the built-in Meta+Left/Right quick tiles if we disabled them
# (a "none" entry over the default), and the desktop-switching defaults.
for key in 'Window Quick Tile Left' 'Window Quick Tile Right'; do
    if [ "$(current_binding "$key")" = "none" ]; then
        kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "$key" --delete || true
    fi
done
for key in 'Switch One Desktop to the Left' 'Switch One Desktop to the Right'; do
    if [ "$(current_binding "$key")" = "none" ]; then
        kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "$key" --delete || true
    fi
done

qdbus6 org.kde.KWin /KWin reconfigure 2>/dev/null || true

echo "Removed. Stock KWin shortcuts fully return after the next login."
