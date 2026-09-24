/*
    Cycle Tiling — KWin script for KDE Plasma 6 (Wayland/X11).

    Ctrl+Shift+Meta+Left   — move window to the left edge; repeated presses
                             cycle its width: 1/2 → 1/3 → 2/3 → 1/2 → ...
    Ctrl+Shift+Meta+Right  — same for the right edge.
    Ctrl+Shift+Meta+Return — center the window: 2/3 of the screen width,
                             full height.

    The cycle step is derived from the window's actual geometry (no state is
    stored): if the window is already in one of the target positions, the
    next one is applied; otherwise the cycle starts at 1/2. The window is
    laid out within the screen it currently resides on.
*/

const VERSION = "1.1.0";

// Gap between the window and the work-area edges, px (0 = flush, like quick tiles)
const GAP = 0;

// Tolerance when comparing geometries: coordinates are fractional under
// fractional scaling, and KWin may clamp sizes to window size hints
const TOLERANCE = 2;

// Cycle order: the first press gives 1/2, then 1/3, 2/3, back to 1/2 ...
const FRACTIONS = [1 / 2, 1 / 3, 2 / 3];

function manageable(win) {
    return win && win.normalWindow && !win.minimized && !win.fullScreen && win.moveable;
}

// Target rectangles for side ("left"/"right") within the work area
function candidates(area, side) {
    const availWidth = area.width - 2 * GAP;
    const availHeight = area.height - 2 * GAP;
    return FRACTIONS.map(function (fraction) {
        const width = Math.round(availWidth * fraction);
        return {
            x: side === "left" ? area.x + GAP : area.x + area.width - GAP - width,
            y: area.y + GAP,
            width: width,
            height: Math.round(availHeight),
        };
    });
}

function sameRect(a, b) {
    return Math.abs(a.x - b.x) <= TOLERANCE && Math.abs(a.y - b.y) <= TOLERANCE
        && Math.abs(a.width - b.width) <= TOLERANCE && Math.abs(a.height - b.height) <= TOLERANCE;
}

function applyGeometry(win, rect) {
    // A window attached to a KWin tile (quick/custom tiling) or maximized
    // would snap back to its old position unless detached first
    if (win.tile) {
        win.tile = null;
    }
    win.setMaximize(false, false);
    win.frameGeometry = {
        x: rect.x,
        y: rect.y,
        width: rect.width,
        height: rect.height,
    };
}

function cycle(side) {
    const win = workspace.activeWindow;
    if (!manageable(win)) {
        return;
    }
    const area = workspace.clientArea(KWin.MaximizeArea, win);
    const cands = candidates(area, side);
    const current = win.frameGeometry;

    let index = 0;
    for (let i = 0; i < cands.length; i++) {
        if (sameRect(current, cands[i])) {
            index = (i + 1) % cands.length;
            break;
        }
    }
    applyGeometry(win, cands[index]);
}

function center() {
    const win = workspace.activeWindow;
    if (!manageable(win)) {
        return;
    }
    const area = workspace.clientArea(KWin.MaximizeArea, win);
    // Width: 2/3 of the screen, centered; height: the full work area, flush
    const width = Math.round((area.width - 2 * GAP) * 2 / 3);
    applyGeometry(win, {
        x: area.x + (area.width - width) / 2,
        y: area.y + GAP,
        width: width,
        height: Math.round(area.height - 2 * GAP),
    });
}

registerShortcut(
    "Cycle Tiling: Left",
    "Cycle Tiling: tile window to the left edge (cycle 1/2 → 1/3 → 2/3)",
    "Ctrl+Shift+Meta+Left",
    function () { cycle("left"); });

registerShortcut(
    "Cycle Tiling: Right",
    "Cycle Tiling: tile window to the right edge (cycle 1/2 → 1/3 → 2/3)",
    "Ctrl+Shift+Meta+Right",
    function () { cycle("right"); });

registerShortcut(
    "Cycle Tiling: Center",
    "Cycle Tiling: center window (2/3 width and full height)",
    "Ctrl+Shift+Meta+Return",
    center);

console.info("cycleTiling: loaded v" + VERSION);
