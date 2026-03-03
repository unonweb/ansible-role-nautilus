#!/bin/bash

# Prompt the user for size reduction options
SIZE_OPTION=$(zenity --list --title="Bild verkleinern" --text="Um wieviel Prozent soll das Bild verkleinert werden?" --column="Options" \
"15%" \
"25%" \
"50%"
)

# Set the percentage based on choice
case "${SIZE_OPTION}" in
    "15%")
        PERCENTAGE=15
        ;;
    "25%")
        PERCENTAGE=25
        ;;
    "50%")
        PERCENTAGE=50
        ;;
    *)
        zenity --error --text="Es wurde keine gültige Option gewählt!"
        exit 1
        ;;
esac

OUT_FILE_NAMES=()
SUFFIX="_reduced-by-${PERCENTAGE}"

# Process selected images
for file_path in "${@}"; do

	# skip files that are not images
	if ! file "${file_path}" | grep -qE 'image|bitmap'; then
		echo "Skipping ${file_path} as it's not an image|bitmap ..."
		continue
	fi

	if [[ ! -f "${file_path}" ]]; then
		echo "Can't find or access ${file_path}. Skipping it ..."
		continue
	fi

	# Get the new file_path name
	OUT_FILE_PATH="${file_path%.*}${SUFFIX}.${file_path##*.}"
	OUT_FILE_NAME=$(basename "${OUT_FILE_PATH}")
	
	# Reduce the image size
	convert "${file_path}" -resize "${PERCENTAGE}"% "${OUT_FILE_PATH}"

	OUT_FILE_NAMES+=("${OUT_FILE_NAME}")
done

# Prepare the output message
#OUT_MESSAGE=""
#OUT_MESSAGE+=$(printf "%s\n\n" "${OUT_FILE_NAMES[@]}")

zenity --info --title="Bilder gespeichert" --text="Bilder wurden verkleiner und mit dem Suffix <b>${SUFFIX}</b> abgespeichert."
