#!/bin/bash

BATCH_ABORT_ERR=115
OUT_SUFFIX="-converted"

function main {

    # Confirm conversion action
    zenity --question --text="Möchten Sie die ausgewählten PDFs in WebP-Bilder konvertieren?" --title="PDF zu WebP Konvertierung"
    if [[ $? -ne 0 ]]; then
        exit 0
    fi

    local error_occurred=false # Flag to track errors

    # Convert selected PDF files
    for selected_path in "${@}"; do

        # Check if the selected file is indeed a PDF
        file "${selected_path}" | grep -qE 'PDF document'
        local file_exit_code=${?}

        if [[ ${file_exit_code} -ne 0 ]]; then
            zenity \
            --error \
            --title="Kein PDF" \
            --text="Dies ist kein PDF:\n<b>${selected_path}</b>\n\nDatei wird übersprungen."
            continue # Skip this file and continue with the next
        fi

        local selected_file_name=$(basename "${selected_path}")

        (
            # Convert PDF to WebP
            convert -quality 90 "${selected_path}" "${selected_path%.*}${OUT_SUFFIX}.webp" & echo -e "${!}\n"
        ) | (
            read PIPED_PID

            # Progress feedback
            zenity --progress --pulsate --auto-close --title="PDF zu WebP Konvertierung" --text "Verarbeite Datei:\n<b>${selected_file_name}</b>"
            local zenity_exit_code=${?}

            if [[ ${zenity_exit_code} -eq 0 ]]; then
                echo "PDF erfolgreich konvertiert: ${selected_file_name}"
            else
                echo "ERROR: PDF Konvertierung fehlgeschlagen: ${selected_file_name}"
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
            --text="Es gab einen Fehler während der PDF-Konvertierung."
    else
        zenity \
            --info \
            --title="PDFs erfolgreich konvertiert!" \
            --text="Die konvertierten PDFs wurden mit dem Suffix <b>${OUT_SUFFIX}.webp</b> gespeichert.\n\nEs kann sein, dass die Dateimanager-Ansicht aktualisiert werden muss, um sie zu sehen (<b>F5-Taste</b>)."
    fi
}

main "${@}"
