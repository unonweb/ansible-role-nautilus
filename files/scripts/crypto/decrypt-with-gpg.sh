#!/bin/bash

readarray -t FILEPATHS <<< "$(echo -e "${NAUTILUS_SCRIPT_SELECTED_FILE_PATHS}" | sed -e 's/\r//g')"

if [ "${#FILEPATHS[@]}" -eq 0 ]; then
    zenity --error --title="Error" --text="No file selected!"
    exit 1
fi

pw=$(zenity --password --title="Datei-Entschlüsselung" --text="Passwort:")

if [ -z "${pw}" ]; then
    zenity --error --title="Error" --text="Passwort ist leer!"
    exit 1
fi

for file_path in "${FILEPATHS[@]}"; do
    
	file_name=$(basename "${file_path}")
	# Remove .gpg extension
    file_path_decrypted="${file_path%.gpg}"

    # Decrypt
    echo "${pw}" | gpg --batch --yes --passphrase-fd 0 --output "${file_path_decrypted}" --decrypt "${file_path}"

    # Verifica se a descriptografia foi bem-sucedida
    if [ ${?} -eq 0 ]; then
		echo "Erfolgreich entschlüsselt:\n${file_path}"
        #zenity \
		#--info \
		#--title="Abgeschlossen" \
		#--text="Erfolgreich entschlüsselt:\n${file_path}"
    else
        zenity --error --title="Error" --text="Fehler bei der Entschlüsselung von\n${file_path}"
    fi
done