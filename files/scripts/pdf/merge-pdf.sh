#!/bin/bash

DEBUG=0

# Create an array from the string
readarray -t SELECTED_PATHS <<< "${NAUTILUS_SCRIPT_SELECTED_FILE_PATHS}"

# Check if there are at least two files selected
if [ "${#}" -lt 2 ]; then
    zenity --error --text="Please select at least two PDF files."
    exit 1
fi

if ! which pdfunite; then
	${ZENITY} --error --title="Error" --text="This script requires the poppler-utils package, which is not installed. Please install it and try again."
	exit 1
fi

# get directory to open using the last element in the array of selected files
OPEN_DIR=$(dirname ${SELECTED_PATHS[1]})

if ((DEBUG)); then
  echo "SELECTED_PATHS[1]: ${SELECTED_PATHS[1]}"
  echo "OPEN_DIR: ${OPEN_DIR}"
fi

# Ask the user for the name of the output file
# OUT_NAME=$(zenity --entry --title="Filename" --text="Name of the merged file:")
OUT_PATH=$(zenity \
  --title="Save Merged PDF As" \
  --file-selection \
  --save \
  --file-filter="PDF files (pdf) | *.pdf" \
  --filename="${OPEN_DIR}/"
)

# If the user cancels the save dialog, exit the script
if [ -z "${OUT_PATH}" ]; then
    exit 1
fi

# append .pdf if not set by user
if [[ "${OUT_PATH}" != *.pdf ]]; then
	OUT_PATH="${OUT_PATH}.pdf"
fi

# Merge the PDFs using pdfunite
CMD_OUTPUT=$(pdfunite "${@}" "${OUT_PATH}")
CMD_EXIT_CODE=${?}

echo ${CMD_OUTPUT}

if [ ${CMD_EXIT_CODE} -eq 0 ]; then
    zenity --info --text="PDFs successfully merged into:\n<b>${OUT_PATH}</b>"
else
    zenity --error --title="Failed to merge PDFs" --text="${CMD_OUTPUT}"
fi