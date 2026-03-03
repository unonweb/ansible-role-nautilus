#!/bin/bash
if [[ $# -gt 1 ]]; then
    zenity --error --title="Run in firejail" --text="Too many arguments.\n\nYou can only run one program in firejail."
    exit 2
fi
exec firejail "$1"
