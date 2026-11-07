#!/usr/bin/env bash
# Omarchy 4.5 — fast mouse wheel scrolling in the Omarchy menu and in the
# dock's app grid.
#
# Qt Quick's ListView and GridView scroll by a small fixed amount per wheel
# tick. This script drops a transparent MouseArea on top of each list: it
# receives the wheel first and scrolls the list by a fraction of the visible
# height per tick. acceptedButtons: Qt.NoButton keeps clicks and drags going
# through to the rows and cells underneath.
#
# The files live in /usr/share/omarchy, so they are patched as root. A
# timestamped backup is written next to each file, and --revert puts the
# newest backup back.
#
# Usage:
#   ./install.sh                 patch both files and restart the shell
#   ./install.sh --no-restart    patch without restarting the shell
#   ./install.sh --revert        restore the newest backup
#   SPEED_DIVISOR=12 ./install.sh  scroll slower (default 8: one eighth of
#                                  the visible list per wheel tick)
set -euo pipefail

MARKER="omarchy-scroll-fix"
MENU_FILE="/usr/share/omarchy/shell/plugins/menu/Menu.qml"
GRID_FILE="/usr/share/omarchy/shell/plugins/dock/AppGrid.qml"
DIVISOR="${SPEED_DIVISOR:-8}"

restart=1
revert=0
for arg in "$@"; do
  case "$arg" in
    --no-restart) restart=0 ;;
    --revert) revert=1 ;;
    -h | --help)
      sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "install.sh: unknown option: $arg" >&2
      exit 1
      ;;
  esac
done

[[ -r $MENU_FILE ]] || { echo "install.sh: cannot read $MENU_FILE" >&2; exit 1; }
[[ -r $GRID_FILE ]] || { echo "install.sh: cannot read $GRID_FILE" >&2; exit 1; }

as_root() {
  if (( EUID == 0 )); then
    "$@"
  else
    sudo "$@"
  fi
}

restore_newest_backup() {
  local file="$1" backup
  backup=$(ls -1t "$file".bak.*.scrollfix 2>/dev/null | head -1 || true)
  if [[ -z $backup ]]; then
    echo "  no backup found for $file, leaving it alone"
    return 0
  fi
  as_root install -m 644 -o root -g root "$backup" "$file"
  echo "  restored $(basename "$backup")"
}

write_patched() {
  local file="$1" kind="$2" tmp="$3"
  python3 - "$file" "$kind" "$tmp" "$MARKER" "$DIVISOR" <<'PY'
import sys

path, kind, out, marker, divisor = sys.argv[1:6]

if kind == "menu":
    list_name = "resultList"
    anchor = "          // Scroll scrims. The clipped row already marks the fold at rest;"
else:
    list_name = "grid"
    anchor = (
        "          Text {\n"
        "            anchors.centerIn: parent\n"
        "            visible: root.apps.length === 0"
    )

source = open(path, encoding="utf-8").read()

if marker in source:
    print("  already patched")
    sys.exit(2)

if anchor not in source:
    print(
        "  anchor not found: Omarchy changed this file; update install.sh",
        file=sys.stderr,
    )
    sys.exit(1)

block = f"""          // {marker}: Qt's {kind == "menu" and "ListView" or "GridView"} scrolls a
          // tiny fixed amount per wheel tick. This transparent overlay sits
          // above the list, takes the wheel first and scrolls by a fraction
          // of the visible height. acceptedButtons: Qt.NoButton keeps clicks
          // and drags going through to the items underneath.
          MouseArea {{
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: function(wheel) {{
              var step = {list_name}.height / {divisor}
              var ticks = wheel.angleDelta.y / 120
              if (ticks === 0) ticks = wheel.pixelDelta.y / 40
              if (ticks === 0) return
              {list_name}.contentY = Math.max(0, Math.min(
                {list_name}.contentY - ticks * step,
                Math.max(0, {list_name}.contentHeight - {list_name}.height)))
              wheel.accepted = true
            }}
          }}

"""

open(out, "w", encoding="utf-8").write(source.replace(anchor, block + anchor, 1))
PY
}

patch_file() {
  local file="$1" kind="$2" label="$3" tmp rc backup
  echo "$label: $file"
  tmp=$(mktemp /tmp/omarchy-scroll-fix.XXXXXX.qml)
  trap 'rm -f "$tmp"' RETURN

  rc=0
  write_patched "$file" "$kind" "$tmp" || rc=$?
  if (( rc == 2 )); then
    return 0
  elif (( rc != 0 )); then
    return 1
  fi

  if ! qmlformat "$tmp" >/dev/null 2>&1; then
    echo "  patched file does not parse, aborting (nothing written)" >&2
    return 1
  fi

  backup="$file.bak.$(date +%Y%m%d%H%M%S).scrollfix"
  as_root cp -a "$file" "$backup"
  as_root install -m 644 -o root -g root "$tmp" "$file"
  echo "  patched, backup at $(basename "$backup")"
}

if (( revert )); then
  echo "Reverting the wheel scroll fix"
  restore_newest_backup "$MENU_FILE"
  restore_newest_backup "$GRID_FILE"
else
  echo "Installing the wheel scroll fix (step: 1/$DIVISOR of the visible list)"
  patch_file "$MENU_FILE" menu "Omarchy menu"
  patch_file "$GRID_FILE" grid "App grid"
fi

if (( restart )); then
  if command -v omarchy >/dev/null 2>&1; then
    echo "Restarting the Omarchy shell"
    omarchy restart shell
  else
    echo "omarchy not found: restart the shell yourself to apply the change"
  fi
fi
