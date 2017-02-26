#!/bin/bash

# NHL.DL
# A script for downloading and assembling NHL.tv video streams. See README.md.

if [ $(uname -s) = "Darwin" ]; then
    tempfile_cmd="mktemp"
else
    tempfile_cmd="tempfile"
fi

cookies=$($tempfile_cmd)
login_result_page=$($tempfile_cmd)

# Fetch master m3u8 file
master_m3u8_url=$1
master_m3u8_file=$($tempfile_cmd)

stream_directory=$(basename $(dirname $master_m3u8_url))

echo ">>> Fetching master m3u8 file: $master_m3u8_url"
wget --quiet --load-cookies cookies.txt \
     --output-document $master_m3u8_file \
     $master_m3u8_url
echo ">>> Done."

# Fetch stream m3u8 file
quality=$2
stream_m3u8_url="$(dirname $master_m3u8_url)/$(grep ${quality}K $master_m3u8_file)"
stream_m3u8_file=$($tempfile_cmd)

echo ">>> Fetching $qualityK stream m3u8 file: $stream_m3u8_url"
wget --quiet --load-cookies cookies.txt \
     --output-document $stream_m3u8_file \
     $stream_m3u8_url
echo ">>> Done."

# Fetch all the keyfiles
stream_key_urls=$(grep -o "https://mf[^\"]*" $stream_m3u8_file | uniq)

mkdir -p $stream_directory/keys

# @todo: Scrape the nhl.tv login process and add user/pass to script arguments.

if [ -f cookies.txt ]; then
    echo ">>> Fetching keys using cookies.txt file."
    while read -r line; do
        wget --quiet \
             --load-cookies cookies.txt \
             --output-document "$stream_directory/keys/$(basename $line)" \
             $line
    done <<< "$stream_key_urls"
    echo ">>> Done."
else
    echo ">>> Stream keys:"
    echo "$stream_key_urls"
    echo ">>> Download the above keys in your browser and put them in $stream_directory/keys."
    read -p ">>> Press enter when you're done."
fi

# @todo: Download all of the stream segments first. Parallelise it.

concat_file=$stream_directory/stream_files.txt
: > $concat_file

counter=1
num_of_segments=$(grep "^[^#]" $stream_m3u8_file | wc -l)

# For each line in stream m3u8 file.
while read -r line; do
    # If line is a new key and IV
    if echo $line | grep -q "^#EXT-X-KEY"; then
        # Extract key.
        key_url=$(echo "$line" | grep -o "https://mf[^\"]*")
        key_file="$stream_directory/keys/$(basename $key_url)"
        key=$(xxd -p $key_file)

        # Extract IV.
        iv=$(echo "$line" | grep -o "IV=[^$]*" | cut -c 6-)

    # If line is a video segment.
    elif echo $line | grep -q "^[0-9]"; then
        # Make directory for segment
        mkdir -p "$stream_directory/$(dirname $line)"

        # While stream file doesn't exist, or is zero length.
        while [ ! -s "$stream_directory/$line" ]; do
            # Download segment.
            echo ">>> Downloading stream segment: $line [$counter/$num_of_segments]"
            wget --quiet --load-cookies cookies.txt \
                 --timeout 3 \
                 --output-document "$stream_directory/$line" \
                 $(dirname $stream_m3u8_url)/$line
            echo ">>> Done."

            # Decrypt segment.
            echo ">>> Decrypting segment."
            openssl enc -aes-128-cbc \
                    -in "$stream_directory/$line" \
                    -out "$stream_directory/$line.dec" \
                    -d -K "$key" -iv "$iv"

            # If decryption failed, delete bad segment,
            # otherwise replace it with decrypted version.
            if [ $? -ne 0 ]; then
                rm "$stream_directory/$line"
                echo ">>> Failed. Fetching segment again."
            else
                mv "$stream_directory/$line.dec" "$stream_directory/$line"
                echo ">>> Done."
            fi
        done

        # Add segment to ffmpeg concatenation file.
        echo "file '$line'" >> $concat_file

        # Increment counter
        counter=$((counter+1))
    fi
done < "$stream_m3u8_file"

echo ">>> Concatenating stream."
ffmpeg -loglevel error -f concat -i $concat_file -c copy -bsf:a aac_adtstoasc \
    $stream_directory/concatenated.mp4

echo ">>> Stripping blanked-out ads."
# Detect silences that indicate ads.
ffmpeg -nostats -i $stream_directory/concatenated.mp4 -filter_complex \
  "[0:a]silencedetect=n=-50dB:d=1[outa]" -map [outa] -f s16le -y /dev/null |& \
  grep "^\[silence" > $stream_directory/silence.txt

# Split into segments without ads.
mkdir -p $stream_directory/gapless
cat $stream_directory/silence.txt | F='-codec copy -loglevel error' D=$stream_directory perl -ne 'INIT { $ss=0; $se=0; }
  if (/silence_start: (\S+)/) { $ss=$1; $ctr+=1; printf "ffmpeg -nostdin -i $ENV{D}/concatenated.mp4 -ss %f -t %f $ENV{F} -y $ENV{D}/gapless/%03d.mp4\n", $se, ($ss-$se), $ctr; }
  if (/silence_end: (\S+)/) { $se=$1; }' | sh

# Merge segments into final gapless video.
printf "file 'gapless/%s'\n" $(ls $stream_directory/gapless) > $stream_directory/gapless_files.txt
ffmpeg -y -loglevel error -f concat -i $stream_directory/gapless_files.txt -c copy $stream_directory.mp4

echo ">>> Finished. You can now delete the $stream_directory directory."
