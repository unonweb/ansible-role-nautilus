#!/bin/bash

readarray -t FILEPATHS <<< "$(echo -e "${NAUTILUS_SCRIPT_SELECTED_FILE_PATHS}" | sed -e 's/\r//g')"

# Make sure that at least one file was selected
if [ "${#FILEPATHS[@]}" -eq 0 ]; then
    zenity --error --title="Erro" --text="No file selected"
    exit 1
fi

# Ask user for password
pw=$(zenity --password --title="Datei-Verschlüsselung" --text="Passwort:")

# Make sure pw is not empty
if [ -z "${pw}" ]; then
    zenity --error --title="Error" --text="Passwort ist leer!"
    exit 1
fi

# Encrypt each selected file
for file_path in "${FILEPATHS[@]}"; do

	file_name=$(basename "${file_path}")
    file_path_encrypted="${file_path}.gpg"

    # Encrypt with gpd
    echo "${pw}" | gpg --batch --yes --passphrase-fd 0 --symmetric --cipher-algo AES256 "${file_path}"

    # Make sure everything went well
    if [ ${?} -eq 0 ]; then
		echo "Erfolgreich verschlüsselt:\n${file_path}"
        #zenity \
		#--info \
        #--title="Verschlüsselung abgeschlossen" \
        #--text="Erfolgreich verschlüsselt:\n${file_path}"
    else
        zenity --error --title="Error" --text="Fehler bei der Verschlüsselung\n${file_path}"
    fi
done