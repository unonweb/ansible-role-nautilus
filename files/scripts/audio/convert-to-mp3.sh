#!/bin/bash

convert_audio_file() {
    local file_path="${1}"
    local file_name=$(basename "${file_path}")
    
    # Check if it's an audio file
    if ! file "${file_path}" | grep -qE 'audio|media'; then
        zenity --error --title="Error" --text="${file_name} ist keine Audio-Datei."
        return 1
    fi

    # Prepare output file path
    local output_path="${file_path%.*}-converted.mp3"

    # Run conversion with progress feedback
    ffmpeg -i "${file_path}" -c:a libmp3lame -b:a 320k "${output_path}" 2>&1
}

main() {
    # Convert file paths to array, handling potential whitespace and newlines
    readarray -t FILEPATHS <<< "$(echo -e "${NAUTILUS_SCRIPT_SELECTED_FILE_PATHS}" | tr '\r' '\n' | grep -v '^$')"
    
    local total_num=${#FILEPATHS[@]}
    local current_num=0

    # Create a named pipe for communication
    PIPE=$(mktemp -u)
    mkfifo "${PIPE}"

    # Start Zenity progress dialog in the background
    zenity --progress \
           --title="Fortschritt" \
           --text="Konvertiere insgesamt ${total_num} Dateien ..." \
           --percentage=0 \
           --auto-close < "${PIPE}" &
    
    ZENITY_PID=${!}

    # Redirect Zenity input to the pipe
    exec 3>"${PIPE}"

    for file_path in "${FILEPATHS[@]}"; do
        # Increment counter
        ((current_num++))

        # Calculate percentage
        local percentage=$((current_num * 100 / total_num))

        # Update progress
        echo "${percentage}" >&3
        echo "Konvertiere Datei ${current_num} von ${total_num}: $(basename "${file_path}")" >&3

        # Convert file
        convert_audio_file "${file_path}"
    done

    # Close pipe and wait for Zenity to finish
    exec 3>&-
    wait ${ZENITY_PID}

    # Clean up
    rm "${PIPE}"

	# Show success message
    # zenity --info --title="Conversion Complete" --text="Converted ${total_num} audio files."
}

main