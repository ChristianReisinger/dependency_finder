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

#####################################################################################################
#declare maps that indicate which headers, libraries and directories are used

declare -A hh_included
while read -r hh; do
	hh_included["$hh"]=0
done <<< "$includes"

declare -A include_dir_used
while read -r Idir; do
	include_dir_used["$Idir"]=0
done < "includes"

declare -A lib_files
while read -r lib; do
	lib_files["${lib%.*}"]=0
done <<< "$includes"

declare -A lib_dir_used
while read -r Ldir; do
	lib_dir_used["$Ldir"]=0
done < "libs"

#####################################################################################################
#determine which include / lib directories are needed and which headers / libraries are found in them

while read -r Idir; do
	while read -r hh; do
		hits="$(find "$Idir" -name "$hh")"
		if [ "$hits" != "" ]; then
			if [ $(wc -l <<< "$hits") -eq 1 ] && [ ${hh_included["$hh"]} -eq 0 ]; then
				include_dir_used["$Idir"]=1
				hh_included["$hh"]=1
			else
				echo "Error: multiple headers '$hh' found"
				exit 1
			fi
		fi
	done <<< "$includes"
done < "includes"

while read -r Ldir; do
	while read -r lib; do
		libstem="${lib%.*}"
		hits="$(find "$Ldir" -regextype posix-extended -regex '.*/(lib)?'"$libstem"'[.](o|so|a)')"
		if [ "$hits" != "" ]; then
			if [ $(wc -l <<< "$hits") -eq 1 ] && [ "${lib_files["$libstem"]}" == "0" ]; then
				lib_dir_used["$Ldir"]=1
				lib_files["$libstem"]="${hits##*/}"
			else
				echo "Error: multiple libraries '$libstem' found"
				exit 1
			fi
		fi
	done <<< "$includes"
done < "libs"

#####################################################################################################
#assemble options -I -L -l to be passed to the compiler

Is=""
Ls=""
libs=""

while read -r Idir; do
	if [ ${include_dir_used["$Idir"]} -eq 1 ]; then
		Is="$Is -I\"$Idir\""
	fi
done < "includes"

while read -r Ldir; do
	if [ ${lib_dir_used["$Ldir"]} -eq 1 ]; then
		Ls="$Ls -L\"$Ldir\""
	fi
done < "libs"

while read -r lib; do
	libstem="${lib%.*}"
	if [ "${lib_files["$libstem"]}" != "0" ]; then
		libs="$libs -l:${lib_files["$libstem"]}"
	fi
done <<< "$includes"

echo "$Is $Ls $libs"
