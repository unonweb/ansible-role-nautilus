#!/usr/bin/env bash
# ----------------------------------------------------------------------
# Reduce an image either by
# - shrinking its pixel dimensions, or
# - lowering JPEG/PNG quality

IFS=$'\n\t'

# ---------- required external tools ----------
declare -r REQ_CMDS=(file convert zenity)
for cmd in "${REQ_CMDS[@]}"; do
    command -v "${cmd}" >/dev/null || { printf 'Missing required command: %s\n' "${cmd}" >&2; exit 1; }
done

# ---------- helper functions ----------
function die   { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
function array_push { eval "${1}+=(\"\${2}\")"; } # push element onto an array
function format_names { local -n a=${1}; printf "%s\n" "${a[@]}"; }

# Ask the user whether to shrink *dimensions* or to lower *quality*
function choose_mode {
    zenity \
		--list \
		--radiolist \
		--hide-header \
		--title="Bild-Verkleinerung" \
        --text="Wie soll das Bild reduziert werden?" \
        --column="Option" \
		--column="Modus" \
		--column="Beschreibung" \
		TRUE "Dimensionen" "Höhe * Breite" \
		FALSE "Qualität" "Kompressionsqualität" \
        || die "Abbruch – keine Auswahl getroffen."
}

# Prompt for a percentage
function choose_resize_percentage {
    local p
    p=$(zenity \
		--list \
		--radiolist \
		--hide-header \
		--height=500 \
		--width=150 \
		--title="Bild-Dimensionen" \
        --text="Auf wie viel Prozent des Originals sollen die Bild-Dimensionen verringert werden?" \
        --column="Option" \
		--column="Prozent" \
		FALSE "95%" \
		TRUE "90%" \
		FALSE "85%" \
		FALSE "75%" \
		FALSE "50%") || die "Abbruch – keine Prozent-Auswahl."

    case "${p}" in
        "95%") echo 95 ;;
		"90%") echo 90 ;;
		"85%") echo 85 ;;
        "75%") echo 75 ;;
        "50%") echo 50 ;;
        *) die "Ungültige Auswahl: ${p}" ;;
    esac
}

# ----------------------------------------------------------------------
# Gather only image files from the command line
# ----------------------------------------------------------------------
declare -a IMG_PATHS=()
declare -a SKIPPED=()

for src in "${@}"; do
	if [[ ! -e ${src} ]]; then
		echo "Warnung: Datei nicht gefunden → ${src}" >&2
		continue
	fi
    file --brief "${src}" | grep -qEi 'image|bitmap'
    file_exit_code=${?}
    if [[ ${file_exit_code} -eq 0 ]]; then
        IMG_PATHS+=("${src}")
    else
    	echo "Not an image: ${src}"
        array_push SKIPPED "$(basename "${src}")"
		continue
    fi
done

echo ${IMG_PATHS[@]}

if [[ ${#IMG_PATHS[@]} -eq 0 ]]; then
	echo "Error: No image selected."
    zenity \
	--warning \
        --title="Kein Bild" \
        --text="Es wurden keine Bilddateien gefunden. Die folgenden Dateien wurden nicht als Bilder erkannt:\n\n$(format_names SKIPPED)" \
        --no-wrap
    exit 0
fi

# ----------------------------------------------------------------------
# Let the user pick the reduction mode
# ----------------------------------------------------------------------
MODE=$(choose_mode) # -> "Dimensionen" or "Qualität"

case "${MODE}" in
	"Dimensionen")
		REDUCE_DIMENSIONS_BY=$(choose_resize_percentage) # 15, 25 or 50
		SUFFIX="_resized-${REDUCE_DIMENSIONS_BY}%"
		if [[ -z ${REDUCE_DIMENSIONS_BY} ]]; then
			echo "Abbruch: Wert für Bild-Dimensionen leer"
			exit 1
		fi
	;;
	"Qualität")
		REDUCE_QUALITY_BY=$(zenity --scale --title="Qualität reduzieren" --text="Um wie viel Prozent soll die Qualität sinken?\n(Höher = kleinere Dateien)" --value=20 --min-value=1 --max-value=90) || exit 0
		SUFFIX="_quality-${REDUCE_QUALITY_BY}%"
		if [[ -z ${REDUCE_QUALITY_BY} ]]; then
			echo "Abbruch: Wert für Bild-Dimensionen leer"
			exit 1
		fi
	;;
esac


# ----------------------------------------------------------------------
# Process each image according to the chosen mode
# ----------------------------------------------------------------------
declare -a SUCCESS=()
declare -a FAILED=()

for src in "${IMG_PATHS[@]}"; do
    dir=$(dirname "${src}")
    base=$(basename "${src}")
    ext=${base##*.}
    name=${base%.*}
    dst="${dir}/${name}${SUFFIX}.${ext}"
    dst_name=$(basename "${dst}")

	case "${MODE}" in
		"Dimensionen")
			# shrink pixel dimensions
			(
				convert "${src}" -resize "${REDUCE_DIMENSIONS_BY}%" "${dst}"
			) | zenity --progress --title="Verarbeite" --text="Verarbeite ${base}..." --pulsate --auto-close
			convert_exit_code=${PIPESTATUS[0]}
			;;
		"Qualität")
			# keep original dimensions, lower compression quality
			# For JPEG the value is 0‑100; for PNG it is compression level (0‑9) –
			# ImageMagick maps a 0‑100 range to the PNG level automatically.
			# Detect source characteristics
			# 1. Get current quality for THIS specific file
			current_quality=$(identify -format "%Q" "${src}" 2>/dev/null || echo 92)
			echo "Identified quality: ${current_quality}"
			
			# 2. Calculate new quality: Current * (100 - Reduction) / 100
			# Bash only does integer math, which is perfect here.
			target_quality=$(( current_quality * (100 - REDUCE_QUALITY_BY) / 100 ))
			echo "Target quality: ${target_quality}"

			#subsampling=$(identify -format '%[jpeg:sampling-factor]' "${src}" 2>/dev/null || echo "4:2:0")
			#interlace=$(identify -format '%[jpeg:interlace]' "${src}" 2>/dev/null || echo "None")
			# Build the convert command with the safest defaults
			#cmd=(convert "${src}" -strip)
			# Preserve the original subsampling (or fall back to 4:2:0)
			# cmd+=(-sampling-factor "${subsampling}")
			# Preserve progressive encoding if it existed
			# [[ ${interlace} == Plane ]] && cmd+=(-interlace Plane)
			# Optimise Huffman tables (helps keep size low)
			# cmd+=(-define jpeg:optimize-coding=true)
			# Apply the user‑chosen quality (numeric, no % sign)
    		# cmd+=(-quality "${QUALITY}" "${dst}")

			# Safety: don't let it drop to 0
			[[ ${target_quality} -lt 1 ]] && target_quality=1

			# 3. Process
			convert "${src}" -strip -quality "${target_quality}" "${dst}"
			convert_exit_code=${?}
			;;
		
		*) zenity --error --text="Es wurde keine gültige Option gewählt!"; exit 1;;
	esac

	if [[ ${convert_exit_code} -eq 0 ]]; then
		array_push SUCCESS "${dst_name}"
	else
		array_push FAILED "${dst_name}"
	fi
done

# ----------------------------------------------------------------------
# Show result dialogs
# ----------------------------------------------------------------------
if [[ ${#SKIPPED[@]} -gt 0 ]]; then
    zenity --warning \
        --title="Dateien übersprungen" \
        --text="Die folgenden Dateien wurden nicht als Bild erkannt:\n\n$(format_names SKIPPED)" \
        --no-wrap
fi

if [[ ${#FAILED[@]} -gt 0 ]]; then
    zenity --warning \
        --title="Konvertierungsfehler" \
        --text="Bei diesen Dateien trat ein Fehler auf:\n\n$(format_names FAILED)" \
        --no-wrap
fi

if [[ ${#SUCCESS[@]} -gt 0 ]]; then
    zenity --info \
        --title="Erfolg" \
        --text="Die folgenden Bilder wurden erfolgreich verarbeitet:\n\n$(format_names SUCCESS)" \
        --no-wrap
fi
