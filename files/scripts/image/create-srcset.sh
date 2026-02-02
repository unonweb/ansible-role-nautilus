#!/bin/bash

function main {
  	# resize selected images according to a predefined scheme

	# Check if Zenity is installed
	if ! ZENITY=$(which zenity); then
		echo "ERROR: This script needs Zenity to run."
		exit 1
	fi

	local selected_scheme=$(zenity --list --title="Srcset schema" --text "Wähle ein Schema (Werte in Pixel)" --radiolist \
		--column "" \
		--column "Schema" \
		TRUE "640 | 768 | 1024 | 1366 | 1600 | 1920" \
		FALSE "120 | 240 | 360 | 480 | 600 | 720" \
	)

	local sizes=()

	case ${selected_scheme} in

		"640 | 768 | 1024 | 1366 | 1600 | 1920")
			sizes=(640 768 1024 1366 1600 1920)
			;;
		"120 | 240 | 360 | 480 | 600 | 720")
			sizes=(120 240 360 480 600 720)
			;;
		*)
			echo "ERROR: Scheme selection failed"
			exit 1
			;;
	esac

	# convert image
	for selected_path in "${@}"; do

		# skip files that are not images
		if ! file "${selected_path}" | grep -qE 'image|bitmap'; then
			echo "Skipping ${selected_path} as it's not an image|bitmap ..."
			continue
		fi

		local basename="${selected_path%%.*}" # remove the longest match from the end
		local ext="${selected_path##*.}"

		echo "ext: ${ext}"
		echo "basename: ${basename}"
		echo "resizing image: ${basename}.${ext}"
		
		for size in ${sizes[@]}; do
			local out_path="${basename}-${size}.${ext}"
			if [[ ! -f "${out_path}" ]]; then
				convert -resize "${size}x" "${selected_path}" "${out_path}"
			fi
		done
	done
}

main ${@}