#!/bin/bash

function show_help {
    echo "This tool compares the files of this repository to those"
    echo "of another repository. Use to compare with files from MiSTer, for instance."
    echo "Usage: cmpt80.sh <path to reference T80 files>"
}

if [ -z "$1" ]; then
    show_help
    exit 1
fi

if [ ! -d "$1" ]; then
    echo "ERROR: $1 is not a folder or it doesn't exist"
    show_help
    exit 1
fi

diff_list=
missing_list=

for file in $(find "$1" -iname "T80*vhd"); do
    bname=$(basename "$file")
    local=$(find ../rtl/vhdl -name "$bname")
    echo $bname
    if [ -e "$local" ]; then
        if ! diff --ignore-space-change "$local" "$file"; then
            diff_list="$diff_list $local"
        fi
    else
        missing_list="$missing_list $local"
    fi
done

if [ ! -z "$diff_list" ]; then
    echo "INFO: Some files were different: "
    echo "$diff_list"
fi

if [ ! -z "$missing_list" ]; then
    echo "INFO: Some files were missing: "
    echo "$missing_list"
fi