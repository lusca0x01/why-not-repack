#!/bin/bash

file=""

print_usage() {
  echo "Usage: $0 [-u|-r] -f input_file"
  echo "Options:"
  echo "  -h  To see the help menu"
  echo "  -u  Unpack the input file"
  echo "  -r  Repack the unpacked files"
  echo "  -f  Specify the input file"
  echo "  -n  Repack without the uImage Header"
}

while getopts 'urnhf:' flag; do
  case "${flag}" in
    h) print_usage
       exit 1 ;;
    u) unpack="true" ;;
    r) repack="true" ;;
    n) no_uImage="true";;
    f) file="${OPTARG}" ; path=$(dirname "$file") ;;
    *) echo "Invalid option"
       print_usage
       exit 1 ;;
  esac
done

if [[ -z "$file" ]]; then
  echo "Please provide an input file using the -f option"
  print_usage
  exit 1
fi

if [[ "$#" -eq 0 ]]; then
  echo "No option provided"
  print_usage
  exit 1
fi

if [[ "$unpack" = "$repack" ]]; then
  echo "Exactly one action option (-u or -r) must be provided"
  print_usage
  exit 1
fi

if ! [[ -f "$file" ]]; then
  echo "Input file '$file' not found"
  exit 1
fi

file_analyze () {
  temp_file=$(mktemp)

  binwalk -t -q "$1" -f "$temp_file"

  pattern="([[:digit:]]+)\s+(0x[[:xdigit:]]+)\s+([^,]+),"

  prev_line=""

  if [[ -f "$path/repack_info" ]]; then
    rm "$path/repack_info"
  fi

  touch "$path/repack_info"

  while IFS= read -r line; do
    if [[ "$line" =~ $pattern ]]; then
      decimal="${BASH_REMATCH[1]}"
      hexadecimal="${BASH_REMATCH[2]}"
      description="${BASH_REMATCH[3]}"

      if ! [[ -z "$prev_line" ]]; then
        echo "END: $decimal" >> "$path/repack_info"
      fi

      echo -n "DESCRIPTION: $description " >> "$path/repack_info"
      echo -n "START: $decimal " >> "$path/repack_info"
      prev_line="$line"

    fi
  done < "$temp_file"

 if [[ -s "$path/repack_info" ]]; then
  end_size=$(du -b "$1" | cut -f -1)
  echo "END: $end_size" >> "$path/repack_info"
  rm "$temp_file"

  echo "Control file for repacking created: repack_info file created!"
 fi
}

unpack() {
  if ! [[ -d "$path/unpacked" ]]; then
    mkdir "$path/unpacked"
  fi

  rm "$path/unpacked/*" 2>/dev/null

  while IFS= read -r line; do
    description=$(awk '$0 ~ /DESCRIPTION:/ { print $2 }' <<< "$line")
    start=$(awk 'sub(".*START: ", "", $0) { print $1 }' <<< "$line")
    end=$(awk 'sub(".*END: ", "", $0) { print $1 }' <<< "$line")

    printf "\033[2K\rUnpacking... $description"; sleep 0.1
    printf "\rUnpacking\xC2\xB7.. $description"; sleep 0.1
    printf "\rUnpacking.\xC2\xB7. $description"; sleep 0.1
    printf "\rUnpacking..\xC2\xB7 $description"; sleep 0.1

    if [[ -e "$path/unpacked/${description}.bin" ]]; then
      count=1
      while [[ -e "$path/unpacked/${description}-${count}.bin" ]]; do
        ((count++))
      done
      dd if="$1" of="$path/unpacked/${description}-${count}.bin" skip="$start" bs=1 count="$((end - start))" > /dev/null 2>&1
    else
      dd if="$1" of="$path/unpacked/${description}.bin" skip="$start" bs=1 count="$((end - start))" > /dev/null 2>&1
    fi
  done < "$path/repack_info"

  printf "\033[2K\rDone!"
  echo
}

repack() {
  filename="$1.packed"

  if [[ -f "$filename" ]]; then
    rm $filename
  fi

  touch "$filename"

  if ! [[ -s "$path/repack_info" && -d "$path/unpacked" ]]; then
    echo "Please, first unpack the file with -u"
    exit 1
  fi

  prev_description=""

  while IFS= read -r line; do
    filtered_count=""
    description=$(awk '$0 ~ /DESCRIPTION:/ { print $2 }' <<< "$line")
    start=$(awk 'sub(".*START: ", "", $0) { print $1 }' <<< "$line")
    end=$(awk 'sub(".*END: ", "", $0) { print $1 }' <<< "$line")

    if [[ "$prev_description" == *-* ]]; then
      filtered_description=$(echo "$prev_description" | cut -d'-' -f1)
      filtered_count=$(echo "$prev_description" | cut -d'-' -f2)
    else
      filtered_description="$prev_description"
    fi

    if [[ "$description" == "$filtered_description" ]]; then
      if [[ -n $filtered_count ]]; then
        count=$((filtered_count+1))
        description="$description-$count"
      else
        description="$description-1"
      fi
    fi

    prev_description="$description"

    if [[ "$no_uImage" = "true" && "$description" == "uImage" ]]; then
      uImage_start="$start"
      uImage_end="$end"
      continue
    fi

    if [[ -e "$path/unpacked/${description}.bin" ]]; then
      dd if="$path/unpacked/${description}.bin" of="$filename" seek=$start bs=1 conv=notrunc > /dev/null 2>&1
      size=$(du -b "$filename" | cut -f -1)
      padding=$((size - end))
      if [[ "$padding" > 0 ]]; then
        for i in {1.."$padding"}; do printf "\x00" >> "$filename"; done
      fi
    fi

    printf "\033[2K\rPacking... $description"; sleep 0.1
    printf "\rPacking\xC2\xB7.. $description"; sleep 0.1
    printf "\rPacking.\xC2\xB7. $description"; sleep 0.1
    printf "\rPacking..\xC2\xB7 $description"; sleep 0.1
  done < "$path/repack_info"

  if [[ "$no_uImage" = 'true' ]]; then
    dd if="$filename" of="$filename.tmp" bs=1 skip="$(( uImage_start + uImage_end))" > /dev/null 2>&1
    mv "$filename.tmp" "$filename"
  fi

  printf "\033[2K\rDone!"
  echo
}

if [[ "$unpack" = "true" ]]; then
  file_analyze "$file"
  unpack "$file"
elif [[ "$repack" = "true" ]]; then
  repack "$file"
fi
