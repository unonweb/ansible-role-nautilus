#!/bin/bash

BATCH_ABORT_ERR=115
OUT_SUFFIX="-converted"

function main {

	local error_occurred=false # Flag to track errors

	# Ask the user to select an output format
	local out_format=$(zenity --list --title="Bild Konvertierung" --text "Wähle ein Format" --radiolist --height 350 \
		--column "" \
		--column "Format" \
		TRUE "webp" \
		FALSE "jpg" \
		FALSE "png"
	)

	case ${out_format} in

		webp|jpg|png)
			echo "Valid format selected"
			;;
		*)
			#echo "ERROR: Format selection failed"
			exit 1
			;;
	esac
	
	# convert image
	for selected_path in "${@}"; do
		
		# Make sure that it's an image
		file "${selected_path}" | grep -qE 'image|bitmap'
		local file_exit_code=${?}
		
		if [[ ${file_exit_code} -ne 0 ]]; then
			zenity \
			--error \
			--title="Kein Bild" \
			--text="Dies ist kein Bild:\n<b>${selected_path}</b>\n\nDatei wird übersprungen."
			continue
		fi
		
		local selected_file_name=$(basename "${selected_path}")

		(
			convert "${selected_path}" "${selected_path%.*}${OUT_SUFFIX}.${out_format}" & echo -e "${!}\n"
		) | (
			# the pipes create implicit subshells
			# we make them explicitly
			read PIPED_PID
			
			# convert
			zenity --progress --pulsate --auto-close --title="Bild Konvertierung" --text "Verarbeite Datei:\n<b>${selected_file_name}</b>"
			local zenity_exit_code=${?}

			if [[ ${zenity_exit_code} -eq 0 ]]; then
				echo "Bild erfolgreich konvertiert: ${selected_file_name}"
			else
				echo "ERROR: Bild Konvertierung fehlgeschlagen: ${selected_file_name}"
				kill ${PIPED_PID}
				error_occurred=true # Set the error flag
			fi
		)
		
		# Check if an error occurred during this conversion
		if ${error_occurred}; then
			break # Exit the loop if there was an error
		fi

	done
	
	# Final feedback based on the error flag
	if [[ ${error_occurred} = true ]]; then
		zenity \
			--error \
			--title="Fehler" \
			--text="Es gab einen Fehler während der Bildkonvertierung."
	else
		zenity \
			--info \
			--title="Bilder erfolgreich konvertiert!" \
			--text="Die konvertierten Bilder wurden mit dem Suffix <b>${OUT_SUFFIX}.${out_format}</b> gespeichert.\n\nEs kann sein, dass die Dateimanager-Ansicht aktualisiert werden muss, um sie zu sehen (<b>F5-Taste</b>)."
	fi

}

main "${@}"