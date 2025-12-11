#!/bin/bash

readarray FILENAME <<< "$(echo -e "${NAUTILUS_SCRIPT_SELECTED_FILE_PATHS}" | sed -e 's/\r//g')"

for file in "${FILENAME[@]}"; do
    # Make sure that the filename is not empty
    # Remove an leading/trailing whitespace
    file="$(echo -e "${file}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    if [ -z "${file}" ]; then
        continue
    fi

    file=$(echo "${file}" | tr -d $'\n')
	# Make sure that this is an img
    if file "${file}" | grep -qE 'image|bitmap'; then
        convert "${file}" "${file%.*}-converted.png" # convert image
        zenity --info \
            --title="Konvertierung abgeschlossen" \
            --text="Konvertierung zu PNG abgeschlossen"
    else
        zenity \
		--error \
        --title="Konvertierung fehlgeschlagen" \
        --text="Die ausgewählte Datei ist kein Bild."
        #notify-send "Erro" "O arquivo $file não é uma imagem." --app-name="Conversor"
        #exit 1
    fi

done
