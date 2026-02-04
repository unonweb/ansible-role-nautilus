#!/bin/bash

BATCH_ABORT_ERR=115
OUT_SUFFIX="-converted"

function main {

	# Ask the user to select an output format
	local out_format=$(zenity --list --title="Bild Konvertierung" --text "Wähle ein Format" --radiolist --height 700 --width 400 \
		--column "" \
		--column "Format" \
		TRUE "webp" \
		FALSE "jpg" \
		FALSE "png" --height 250 --width 400
	)

	case ${out_format} in

		webp|jpg|png)
			echo "Valid format selected"
			;;
		*)
			echo "ERROR: Format selection failed"
			exit 1
			;;
	esac
	
	# Make sure that all files selected are images
	for selected_path in "${@}"; do
		if ! file "${selected_path}" | grep -qE 'image|bitmap'; then
			zenity \
			--error \
			--title="Konvertierung fehlgeschlagen" \
			--text="Dies ist kein Bild:\n${selected_path}\n\nBitte wähle nur Bilder aus!"
			exit 1
		fi
	done
	
	# convert image
	for selected_path in "${@}"; do
		
		local selected_file_name=$(basename "${selected_file_path}")

		(
			convert "${selected_path}" "${selected_path%.*}${OUT_SUFFIX}.${out_format}" & echo -e "${!}\n"
		) | (
			# the pipes create implicit subshells
			# we make them explicitly
			read PIPED_PID

			if zenity --progress --pulsate --auto-close --title="Bild Konvertierung" --text "Verarbeite Datei:\n<b>${selected_file_name}</b>"; then
				echo "Bild erfolgreich konvertiert: ${out_name}"
			else
				kill ${PIPED_PID}
				exit ${BATCH_ABORT_ERR} # Warning: it exits the subshell but not the script
			fi
		)
		
		# break the loop in case we abort (zenity fails)
		if [ "${?}" = "${BATCH_ABORT_ERR}" ]; then
			break
		fi
	done

}

main ${@}