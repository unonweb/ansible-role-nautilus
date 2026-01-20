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
	if ! GS=$(which gs); then
		${ZENITY} --error --title="${ZENITY_TITLE}" --text="This script requires the ghostscript package, which is not installed. Please install it and try again."
		exit 1
	fi

	# Check if the user has selected any files
	# we double check. Remove the first part if you plan to manually invoke the script
	if [ "x${NAUTILUS_SCRIPT_SELECTED_FILE_PATHS}" = "x"  -o  "$#" = "0" ]; then
		${ZENITY} --error --title="${ZENITY_TITLE}" --text="No file selected."
		exit 1
	fi

	# Check if we can properly parse the arguments
	INPUT=("$@")
	N=("$#")
	if [ "${#INPUT[@]}" != "$N" ]; then
		# comparing the number of arguments the script is given with what it can count
		${ZENITY} --error --title="${ZENITY_TITLE}" # if we arrive here, there is something very messed
		exit 1
	fi

	# Check if all the arguments are proper PDF files
	for selected_path in "${@}"; do
		# ignoring case for 'pdf'; as far as I know, the slash before (sth/pdf) is universal mimetype output. In most cases we can even expect 'application/pdf' (portability issues?).
		if ! file --brief --mime-type "${selected_path}" | grep -i "/pdf"; then 
			${ZENITY} --error --title="${ZENITY_TITLE}" --text="Dies ist kein PDF:\n${selected_path}\n\nBitte wähle nur PDFs aus!"
			exit 1		
		fi
	done
	
	for selected_path in "${@}"; do
		
		local selected_name=$(basename "${selected_path}")
		local out_filename=${selected_name%.*}${OUTPUT_SUFFIX}.${selected_name##*.}
		local out_basename=$(basename "${out_filename}")
		local tmp_filename=tmp-${out_basename}

		if [ -e ${tmp_filename} ]; then 
			${ZENITY} --error --title="${ZENITY_TITLE}"
			exit 1
		fi

		# Execute ghostscript while showing a progress bar
		(
			gs -q -dNOPAUSE -dBATCH -dSAFER \
			-sDEVICE=pdfwrite \
			-dCompatibilityLevel=1.3 \
			-dPDFSETTINGS=/screen \
			-dEmbedAllFonts=true -dSubsetFonts=true \
			-dColorImageDownsampleType=/Bicubic \
			-dColorImageResolution=144 \
			-dGrayImageDownsampleType=/Bicubic \
			-dGrayImageResolution=144 \
			-dMonoImageDownsampleType=/Bicubic \
			-dMonoImageResolution=144 \
			-sOutputFile=${tmp_filename} \
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

main ${@}