#!/bin/bash

# Check if there are at least two files selected
if [ "${#}" -lt 2 ]; then
    zenity --error --text="Please select at least two PDF files."
    exit 1
fi

if ! which pdfunite; then
	${ZENITY} --error --title="Error" --text="This script requires the poppler-utils package, which is not installed. Please install it and try again."
	exit 1
fi

# Ask the user for the name of the output file
#OUT_NAME=$(zenity --entry --title="Filename" --text="Name of the merged file:")
OUT_PATH=$(zenity --file-selection --save --confirm-overwrite --title="Save Merged PDF As" --file-filter="PDF files (pdf) | *.pdf")

# If the user cancels the save dialog, exit the script
if [ -z "${OUT_PATH}" ]; then
    exit 1
fi

if [[ "${OUT_PATH}"  != *.pdf ]]; then
	OUT_PATH="${OUT_PATH}.pdf"
fi

# Merge the PDFs using pdfunite
CMD_OUTPUT=$(pdfunite "${@}" "${OUT_PATH}")
CMD_EXIT_CODE=${?}

echo ${CMD_OUTPUT}

if [ ${CMD_EXIT_CODE} -eq 0 ]; then
    zenity --info --text="PDFs successfully merged into\n<b>${OUT_PATH}</b>"
else
    zenity --error --title="Failed to merge PDFs" --text="${CMD_OUTPUT}"
fi