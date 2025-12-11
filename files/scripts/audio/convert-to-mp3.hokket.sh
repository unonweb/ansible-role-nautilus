#!/bin/bash

readarray FILEPATHS <<< "$(echo -e "${NAUTILUS_SCRIPT_SELECTED_FILE_PATHS}" | sed -e 's/\r//g')"

for file in "${FILEPATHS[@]}"; do

    file_path=$(echo "${file_path}" | tr -d $'\n')
	file_name=$(basename ${file_path})

    if file "${file_path}" | grep -qE 'audio|media'; then
        
		# Get length of audio
        duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "${file_path}")
        
        # Convert to MP3 320k
        ffmpeg -i "${file_path}" -c:a libmp3lame -b:a 320k "${file_path%.*}-converted.mp3" 2>&1 | \
        while read -r line; do
            if [[ ${line} =~ time=([0-9:.]+) ]]; then
				# Convert time to seconds, using bc for floating-point numbers
                current_time=$(echo "${BASH_REMATCH[1]}" | awk -F: '{ print ($1 * 3600) + ($2 * 60) + $3 }')
				# Use bc to handle floating-point calculation for progress
				progress=$(echo "scale=2; (${current_time} * 100) / ${duration}" | bc)
        		echo "${progress%.*}"  # Remove decimal part if needed
                #progress=$(( (current_time * 100) / duration ))
                #echo "${progress}"
            fi
        done | zenity \
			--progress \
            --title="Fortschritt" \
            --text="Konvertiere: ${file_name} ..." \
            --percentage=0 \
            --auto-close
    else
        zenity \
		--error \
        --title="Error" \
        --text="${file_name} ist keine Audio-Datei."
    fi

done