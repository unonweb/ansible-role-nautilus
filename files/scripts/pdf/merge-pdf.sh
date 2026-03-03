#!/bin/bash

DEBUG=0
# Create an array from the string
readarray -t SELECTED_PATHS <<< "${NAUTILUS_SCRIPT_SELECTED_FILE_PATHS}"
# get directory to open using the last element in the array of selected files
OPEN_DIR=$(dirname ${SELECTED_PATHS[1]})

# Check if there are at least two files selected
if [ "${#}" -lt 2 ]; then
    zenity --error --text="Please select at least two PDF files."
    exit 1
fi

if ! which pdfunite; then
	zenity --error --title="Error" --text="This script requires the poppler-utils package, which is not installed. Please install it and try again."
	exit 1
fi

if ((DEBUG)); then
  echo "SELECTED_PATHS[1]: ${SELECTED_PATHS[@]}"
  echo "OPEN_DIR: ${OPEN_DIR}"
fi

# Loop over selected files
for selected_path in ${SELECTED_PATHS[@]}; do
		# Check if it's a PDF file
	# ignoring case for 'pdf'; as far as I know, the slash before (sth/pdf) is universal mimetype output. In most cases we can even expect 'application/pdf' (portability issues?)
	file --brief --mime-type "${selected_path}" | grep -iq "/pdf"
	file_exit_code=${?}
	if [[ ${file_exit_code} -ne 0 ]]; then
		echo "Not a pdf: ${selected_path}"
		zenity --error --title="Error" --text="Dies ist kein PDF:\n<b>${selected_path}</b>\n\nBitte nur PDFs auswählen!"
		exit 1
	fi
done

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

if ((DEBUG)); then
	echo ${CMD_OUTPUT}
fi

if [ ${CMD_EXIT_CODE} -eq 0 ]; then
    zenity --info --text="PDFs successfully merged into:\n<b>${OUT_PATH}</b>"
else
    zenity --error --title="Failed to merge PDFs" --text="${CMD_OUTPUT}"
fi