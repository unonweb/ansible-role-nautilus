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
GRAY_SCALE_ARGS=""
PDF_VERSION="1.5"
DEBUG=1

function get_pdf_version {
	# $1 is the input file. The PDF version is contained in the
	# first 1024 bytes and will be extracted from the PDF file.
	PDF_VERSION=$(head -c 1024 "$1" | LC_ALL=C awk 'BEGIN { found=0 }{ if (match($0, "%PDF-[0-9]\\.[0-9]") && ! found) { print substr($0, RSTART + 5, 3); found=1 } }')
	if [ -z "${PDF_VERSION}" ] || [ "${#PDF_VERSION}" != "3" ]; then
		return 1
	fi
}

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
	local user_options=$(zenity \
		--title="Compress-PDF" \
		--forms \
		--text="Einstellungen" \
		--add-combo="Bild-Qualität" \
		--combo-values="36 dpi|48 dpi|72 dpi|144 dpi|" \
		--add-combo="Farbmodus" \
		--combo-values="Farbe|Graustufen" \
	)

	if [[ -z ${user_options} ]]; then
		echo "Aborted by user. Exiting."
		exit 1
	fi

	# Split the string into two parts
	local img_res="${user_options%%|*}" # Get everything before the '|'
	local color_mode="${user_options##*|}" # Get everything after the '|'

	# Remove ' dpi' from img_res
	img_res="${img_res/dpi/}"

	# remove trailing whitespaces
	img_res=${img_res%"${img_res##*[![:space:]]}"}
	color_mode=${color_mode%"${color_mode##*[![:space:]]}"}

	# remove leading whitespaces
	img_res=${img_res#"${img_res%%[![:space:]]*}"}
	color_mode=${color_mode#"${color_mode%%[![:space:]]*}"}

	# Set grayscale args
	if [ "${color_mode}" = "Graustufen" ]; then
		GRAY_SCALE_ARGS="-sProcessColorModel=DeviceGray -sColorConversionStrategy=Gray -dOverrideICC"
	else
		GRAY_SCALE_ARGS=""
	fi
	
	if ((DEBUG)); then
		echo "img_res: ${img_res}"
		echo "color_mode: ${color_mode}"
		echo "GRAY_SCALE_ARGS: ${GRAY_SCALE_ARGS}"
	fi

	# Loop over selected files
	for selected_path in "${@}"; do
		
		local selected_name=$(basename "${selected_path}")
		local out_filename=${selected_name%.*}${OUTPUT_SUFFIX}.${selected_name##*.}
		local out_basename=$(basename "${out_filename}")
		local tmp_filename=tmp-${out_basename}
		
		if ((DEBUG)); then
		  echo "selected_name: ${selected_name}"
		  echo "tmp_filename: ${tmp_filename}"
		  echo "out_filename: ${out_filename}"
	  fi

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

		# Get the PDF version of the input file.
		get_pdf_version "${selected_path}" || PDF_VERSION="1.5"

		# Execute ghostscript while showing a progress bar
		(
			gs \
			-q -dNOPAUSE -dBATCH -dSAFER \
			-sDEVICE=pdfwrite \
			-dCompatibilityLevel=${PDF_VERSION} \
			-dPDFSETTINGS=/screen \
			-dEmbedAllFonts=true \
			-dSubsetFonts=true \
			-dAutoRotatePages=/None \
			-dColorImageDownsampleType=/Bicubic \
			-dColorImageResolution=${img_res} \
			-dColorImageDownsampleThreshold="1.0" \
			-dGrayImageDownsampleType=/Bicubic \
			-dGrayImageResolution=${img_res} \
			-dGrayImageDownsampleThreshold="1.0" \
			-dMonoImageDownsampleType=/Bicubic \
			-dMonoImageResolution=${img_res} \
			-dMonoImageDownsampleThreshold="1.0" \
			-dPreserveAnnots=false \
			-sOutputFile=${tmp_filename} \
			${GRAY_SCALE_ARGS} \
			"${selected_path}" & echo -e "${!}\n"
			# we output the pid so that it passes the pipe
			# the explicit linefeed starts the zenity progressbar pulsation
		) | (
			# the pipes create implicit subshells; marking them explicitly
			read PIPED_PID
			if ${ZENITY} --progress --pulsate --auto-close --title="${ZENITY_TITLE}" --text "Verarbeite Datei:\n<b>${out_basename}</b>"; then
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