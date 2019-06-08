#!/bin/bash

project_dir=${1:?"Error: no project directory"}
src_file=${2:?"Error: no source file"}
#src_dir=${src_file%/*}
#project_dir=${src_dir%/*}

function strip_comments {
	sed 's/a/aA/g;s/__/aB/g;s/#/aC/g' "$1" | g++ -P -E - | sed 's/aC/#/g;s/aB/__/g;s/aA/a/g'
}

cd "$project_dir"

includes="$(echo "$(strip_comments "$src_file")" | sed -nr 's/^#include <(.+)>$/\1/p')"

Is=""
Ls=""
libs=""

if [ -f "includes" ]; then
	while read -r include_dir; do
		while read -r hh; do
			hits=$(find "$include_dir" -name "$hh")
			if [ "$hits" != "" ] && [ $(echo "$hits" | wc -l) -eq 1 ]; then
				Is="$Is -I${include_dir}"
				break
			fi
		done < <(echo "$includes")
	done < "includes"
fi

if [ -f "libs" ]; then
	while read -r lib_dir; do
		while read -r hh; do
			libstem=${hh%.*}
			hits=$(find "$lib_dir" -regextype posix-extended -regex '.*/(lib)?'"$libstem"'[.](o|so|a)')
			if [ "$hits" != "" ] && [ $(echo "$hits" | wc -l) -eq 1 ]; then
				Ls="$Ls -L${lib_dir}"
				libs="$libs -l:$(basename "${hits}")"
				break
			fi
		done < <(echo "$includes")
	done < "libs"
fi

echo $Is $Ls $libs
