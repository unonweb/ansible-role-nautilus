#! /bin/bash

# NAUTILUS_SCRIPT_SELECTED_FILE_PATHS
# -> Pfade der gewählten Dateien, durch Newline getrennt (nur im lokalen Fall)
# NAUTILUS_SCRIPT_SELECTED_URIS
# -> URIs der ausgewählten Dateien, durch Newline getrennt
# NAUTILUS_SCRIPT_CURRENT_URI
# -> URI des aktuellen Ortes

ZENITY_TITLE="Compress PDF"
COMPRESSPDF_BATCH_ABORT_ERR=115
OUTPUT_SUFFIX="-compressed"

function main {

	# Check if Zenity is installed
	if ! ZENITY=$(which zenity); then
		echo "Error - This script needs Zenity to run."
		exit 1
	fi

	# Check if Ghostscript is installed
	if ! which gs; then
		${ZENITY} --error --title="${ZENITY_TITLE}" --text="This script requires the 'ghostscript' package, which is not installed. Please install it and try again."
		exit 1
	fi

	# Ask to select compression
	local compression_lvl=$(zenity --list --title="Kompressions-Level" --text "Je höher, desto kleiner das Dokument,\naber desto niedrieger die Qualität" --radiolist --height 400 --width 300 \
		--column "" \
		--column "Level" \
		FALSE 1 \
		TRUE 2 \
		FALSE 3
	)

	if [[ -z ${compression_lvl} ]]; then
		echo "Error: No compression lvl set. Exiting."
		exit 1
	fi

	case ${compression_lvl} in

		1)
			image_resolution=144
			;;
		2)
			image_resolution=128
			;;
		3)
			image_resolution=64
			;;
		*)
			echo "ERROR: Compression selection failed"
			exit 1
			;;
	esac

	for selected_path in "${@}"; do
		
		local selected_name=$(basename "${selected_path}")
		local out_filename=${selected_name%.*}${OUTPUT_SUFFIX}.${selected_name##*.}
		local out_basename=$(basename "${out_filename}")
		local tmp_filename="tmp-${out_basename}"
		
		# debug
		echo "selected_path: ${selected_path}"
		echo "out_filename: ${out_filename}"
		echo "out_basename: ${out_basename}"
		echo "tmp_filename: ${tmp_filename}"
		

		if [[ -e ${tmp_filename} ]]; then 
			${ZENITY} --error --title="${ZENITY_TITLE}" --text "Temporary filename already exists: ${tmp_filename}"
			exit 1
		fi

		# Check if it's a PDF file
		# ignoring case for 'pdf'; as far as I know, the slash before (sth/pdf) is universal mimetype output. In most cases we can even expect 'application/pdf' (portability issues?)
		file --brief --mime-type "${selected_path}" | grep -iq "/pdf"
		local file_exit_code=${?}
		
		if [[ ${file_exit_code} -ne 0 ]]; then
			${ZENITY} --error --title="${ZENITY_TITLE}" --text="Dies ist kein PDF:\n<b>${selected_path}</b>\n\nDatei wird übersprungen!"
			continue
		fi

		# Execute ghostscript while showing a progress bar
		(
			gs -q -dNOPAUSE -dBATCH -dSAFER \
			-sDEVICE=pdfwrite \
			-dCompatibilityLevel=1.4 \
			-dPDFSETTINGS=/screen \
			-dEmbedAllFonts=true -dSubsetFonts=true \
			-dColorImageDownsampleType=/Bicubic \
			-dColorImageResolution=${image_resolution} \
			-dGrayImageDownsampleType=/Bicubic \
			-dGrayImageResolution=${image_resolution} \
			-dMonoImageDownsampleType=/Bicubic \
			-dMonoImageResolution=${image_resolution} \
			-sOutputFile="${tmp_filename}" \
			"${selected_path}" & echo -e "${!}\n"
			# we output the pid so that it passes the pipe
			# the explicit linefeed starts the zenity progressbar pulsation
		) | (
			# the pipes create implicit subshells; marking them explicitly
			read PIPED_PID
			if ${ZENITY} --progress --pulsate --auto-close --title="${ZENITY_TITLE}" --text "Verarbeite Date:\n<b>${out_basename}</b>"; then
				# we go on to the next file as fast as possible (this subprocess survives the end of the script, so it is even safer)
				mv -f "${tmp_filename}" "${out_filename}" &
				# notify-send "Compress PDF" "${out_basename} "has been successfully compressed""
			else
				kill ${PIPED_PID}
				rm "${tmp_filename}"
				exit ${COMPRESSPDF_BATCH_ABORT_ERR} # Warning: it exits the subshell but not the script
			fi
		)

		if [ "${?}" = "${COMPRESSPDF_BATCH_ABORT_ERR}" ]; then 
			break
		fi # to break the loop in case we abort (zenity fails)

	done
}

main "${@}"