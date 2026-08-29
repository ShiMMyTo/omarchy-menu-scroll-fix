# Omarchy 4 — Mouse Wheel Scroll Speed Fix for the Menu

Fix for the slow mouse wheel scroll in the **Omarchy 4** apps menu (and every other Qt Quick list, like the emoji picker).

- **Tested on:** Omarchy 4.0.1-1 (Arch Linux)
- **Plugin:** `omarchy.menu` (the apps launcher / menu)

## Problem

The mouse wheel scroll inside the Omarchy menu is very slow, while it is normal in every other application.

## Root cause

The menu is built with Qt Quick (`ListView`, which inherits `Flickable`). By default, the mouse wheel on a Qt Quick `ListView` moves a small fixed amount per wheel tick, with no way to configure it externally. The menu has a long list of applications, so the slow step becomes obvious. Every other list in Omarchy (emoji picker, etc.) behaves the same way.

## Fix

Add a transparent `MouseArea` **on top of** the `ListView` (after it in the stacking order) that captures the wheel first and scrolls manually at a configurable speed.

**The key trick:** the `MouseArea` must go *after* the `ListView` in the stacking order, with `acceptedButtons: Qt.NoButton` (so clicks still reach the rows). Placed before the `ListView`, the list steals the wheel event and the handler never fires.

## Installation

The original menu lives in `/usr/share/omarchy` (read-only). To modify it you must clone the plugin into your own config and edit the copy:

```bash
omarchy plugin clone omarchy.menu
# creates ~/.config/omarchy/plugins/<username>.menu and activates it
```

Then edit `~/.config/omarchy/plugins/<username>.menu/Menu.qml` and add this block right after the `resultList` ListView (inside the same Item, e.g. just before the closing brace of the list Item):

```qml
// Placed after the ListView (on top of it) so this transparent
// MouseArea receives the wheel first; the Qt Quick ListView otherwise
// scrolls by a fixed tiny amount per wheel tick, which feels slow on
// a long apps list. acceptedButtons: NoButton lets clicks pass to the
// rows below.
MouseArea {
  anchors.fill: parent
  acceptedButtons: Qt.NoButton
  onWheel: function(wheel) {
    if (wheel.angleDelta.y === 0) return
    if (resultList.contentHeight <= resultList.height) return
    var factor = 1
    var step = resultList.height / 8
    resultList.contentY = Math.max(0, Math.min(
      resultList.contentY - wheel.angleDelta.y / 120.0 * step * factor,
      resultList.contentHeight - resultList.height))
    wheel.accepted = true
  }
}
```

Alternatively, copy the whole `Menu.qml` from this repo over the cloned one.

## Reload

QML changes are **not** applied live on this plugin. Restart the shell:

```bash
omarchy restart shell
```

> Do **not** use `omarchy refresh shell` — it regenerates `shell.json` with Omarchy defaults and replaces your custom config.

## Adjusting the speed

Inside `onWheel` there are two variables:

- `factor` multiplies the speed (raise it to go faster).
- `step = height / N`. The larger `N`, the slower each wheel click scrolls. To go slower, raise `N` (e.g. `height/12`, `height/16`).

## Files

- `Menu.qml` — full modified menu plugin file (clone of `omarchy.menu` for Omarchy 4).