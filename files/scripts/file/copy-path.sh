#!/bin/bash

# Get the file path of the selected item

# NAUTILUS_SCRIPT_SELECTED_FILE_PATHS
# contains the full path of the selected files

if [ -n "${NAUTILUS_SCRIPT_SELECTED_FILE_PATHS}" ]; then
  echo -n "${NAUTILUS_SCRIPT_SELECTED_FILE_PATHS}" | wl-copy
  /usr/bin/notify-send "Pfade in die Zwischenablage kopiert" "${NAUTILUS_SCRIPT_SELECTED_FILE_PATHS}"
  #/usr/bin/notify-send "Selected paths copied to clipboard" "${NAUTILUS_SCRIPT_SELECTED_FILE_PATHS}"
fi