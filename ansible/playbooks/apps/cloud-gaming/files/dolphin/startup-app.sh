#!/bin/bash
# Wolf app start script for Dolphin. Bind-mounted over /opt/gow/startup-app.sh
# in the Pegasus image (games-on-whales/pegasus is built on base-emu, which
# bundles the upstream Dolphin AppImage at /Applications/dolphin-emu.AppImage).
# The games-on-whales entrypoint runs this as the unprivileged `retro` user with
# the per-app state folder mounted at /home/retro.
set -e

source /opt/gow/bash-lib/utils.sh
source /opt/gow/launch-comp.sh

# Seed Dolphin's config on the first run only (ROM paths, fullscreen, Wolf pad
# mapping). Dolphin owns the files afterwards: edits made in its UI persist in
# the per-app home, and a redeploy never overwrites them.
DOLPHIN_CFG="$HOME/.config/dolphin-emu"
mkdir -p "$DOLPHIN_CFG"
for seed in /cfg/dolphin/*.ini; do
  target="$DOLPHIN_CFG/$(basename "$seed")"
  if [ ! -e "$target" ]; then
    gow_log "Dolphin - seeding $(basename "$seed")"
    cp "$seed" "$target"
  fi
done

gow_log "Starting Dolphin"
launcher /Applications/launchers/dolphin.sh
