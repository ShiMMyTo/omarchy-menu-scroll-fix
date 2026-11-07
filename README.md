# Omarchy — Mouse Wheel Scroll Speed Fix for the Menu and the App Grid

The mouse wheel scrolls painfully slowly inside the Omarchy menu, the dock's app
grid, and their submenus, while it feels normal in every other application.

- **Tested on:** Omarchy 4.5.0-3 (Arch Linux, Hyprland 0.57.1, Qt 6.12)
- **Files patched:** `omarchy.menu` (`Menu.qml`) and `omarchy.dock`'s app grid
  (`AppGrid.qml`)

## Problem

Qt Quick `ListView` and `GridView` inherit `Flickable`, which scrolls by a
small fixed amount per wheel tick and has no externally configurable speed. A
long list of apps makes that obvious.

## Fix

Add a transparent `MouseArea` **on top of** the list (after it in the stacking
order) that captures the wheel first and scrolls manually at a configurable
speed.

**The key trick:** the `MouseArea` must go *after* the `ListView`/`GridView` in
the stacking order, with `acceptedButtons: Qt.NoButton` so clicks and drags
still reach the rows and cells underneath. Placed before the list, the list
steals the wheel event and the handler never fires.

A `WheelHandler` declared inside the list does **not** work here: the
`Flickable` keeps handling the wheel itself on this Qt version, which is why
the fix has to be an overlay and not a handler.

## Installation

The files live in `/usr/share/omarchy`, so they are patched as root. The script
writes a timestamped backup next to each file before touching it, and refuses to
write anything that does not parse with `qmlformat`.

```bash
./install.sh
```

It patches both files, restarts the Omarchy shell, and is safe to run again: an
already patched file is skipped.

```bash
./install.sh --no-restart    # patch without restarting the shell
./install.sh --revert        # restore the newest backup of both files
```

## Adjusting the speed

The step is one eighth of the visible list per wheel tick. Change it with:

```bash
SPEED_DIVISOR=12 ./install.sh    # slower: one twelfth of the list per tick
SPEED_DIVISOR=5  ./install.sh    # faster
```

To change the speed of an already patched file, revert first: the script will
not patch a file twice.

## After an Omarchy update

An update rewrites both files from the package and the fix disappears. Run
`./install.sh` again. If Omarchy changes the surrounding code, the script stops
with `anchor not found` instead of writing something broken, and the anchor
strings in `install.sh` need updating.

## Why not ship the patched files themselves

Earlier versions of this repository shipped a full copy of `Menu.qml`. That copy
was taken from Omarchy 4.0.1; the menu in 4.5 is a different file, so copying it
over silently reverts every menu change since. The old copy is kept in `legacy/`
for reference only. The script exists so the fix tracks whatever version of the
files is installed.

## Files

- `install.sh` — patches `Menu.qml` and `AppGrid.qml`, with backup and revert.
- `legacy/Menu.qml-omarchy-4.0.1` — the original hand-patched file from Omarchy
  4.0.1, reference only.
