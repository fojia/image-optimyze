#!/bin/bash

PROGNAME=${0##*/}
INPUT=''
QUIET='0'
NOSTATS='0'
QUALITY=85
max_input_size=0
max_output_size=0

usage()
{
  cat <<EO
Usage: $PROGNAME [options]

Script to optimize JPG and PNG images in a directory.

Options:
EO
cat <<EO | column -s\& -t
	-h, --help  	   & shows this help
	-q, --quality 	   & set quality
	-i, --input [dir]  & specify input directory (current directory by default)
	-o, --output [dir] & specify output directory ("output" by default)
	-ns, --no-stats    & no stats at the end
EO
}

# $1: input image
# $2: output image 
optimize_image()
{
	input_file_size=$(stat -c%s "$1")
	max_input_size=$(expr $max_input_size + $input_file_size)

	convert -strip -interlace Plane  -quality "$QUALITY%" $1 $2

	output_file_size=$(stat -c%s "$2")
	max_output_size=$(expr $max_output_size + $output_file_size)
}

get_max_file_length()
{
	local maxlength=0

	IMAGES=$(find $INPUT -regextype posix-extended -regex '.*\.(jpg|jpeg|png)' | grep -v $OUTPUT)

	for CURRENT_IMAGE in $IMAGES; do
		filename=$(basename "$CURRENT_IMAGE");
		
		filepath=$(dirname "$CURRENT_IMAGE");

		filepath=${filepath#$INPUT}
		outputpath="$outputpath$filepath";
		outpfilename="$filepath/$filename";
		
		if [[ ${#outpfilename} -gt $maxlength ]]; then
			maxlength=${#outpfilename}
		fi
	done

	echo "$maxlength"	
}

main()
{
	# If $INPUT is empty, then we use current directory
	if [[ "$INPUT" == "" ]]; then
		INPUT=$(pwd)
	fi

	# If $OUTPUT is empty, then we use the directory "output" in the current directory
	if [[ "$OUTPUT" == "" ]]; then
		OUTPUT=$(pwd)/output
	fi

	# We create the output directory
	mkdir -p $OUTPUT

	# To avoid some troubles with filename with spaces, we store the current IFS (Internal File Separator)...
	SAVEIFS=$IFS
	# ...and we set a new one
	IFS=$(echo -en "\n\b")

	max_filelength=`get_max_file_length`
	pad=$(printf '%0.1s' "."{1..600})
	sDone=' [ DONE ]'
	linelength=$(expr $max_filelength + ${#sDone} + 5)

	# Search of all jpg/jpeg/png in $INPUT
	# We remove images from $OUTPUT if $OUTPUT is a subdirectory of $INPUT
	IMAGES=$(find $INPUT -regextype posix-extended -regex '.*\.(jpg|jpeg|png)' | grep -v $OUTPUT)

	if [ "$QUIET" == "0" ]; then
		echo --- Optimizing $INPUT ---
		echo
	fi
	for CURRENT_IMAGE in $IMAGES; do
		outputpath=$OUTPUT;
		filename=$(basename $CURRENT_IMAGE);
		
		filepath=$(dirname "$CURRENT_IMAGE");

		filepath=${filepath#$INPUT}
		outputpath="$outputpath$filepath";
		outpfilename="$filepath/$filename";
		
		mkdir -p "$outputpath";

		if [ "$QUIET" == "0" ]; then
		    printf '%s ' "$outpfilename"
		    printf '%*.*s' 0 $((linelength - ${#outpfilename} - ${#sDone} )) "$pad"
		fi

		optimize_image $CURRENT_IMAGE $outputpath/$filename

		if [ "$QUIET" == "0" ]; then
		    printf '%s\n' "$sDone"
		fi
	done

	# we restore the saved IFS
	IFS=$SAVEIFS

	if [ "$NOSTATS" == "0" -a "$QUIET" == "0" ]; then
		echo
		echo "Input: " $(human_readable_filesize $max_input_size)
		echo "Output: " $(human_readable_filesize $max_output_size)
		space_saved=$(expr $max_input_size - $max_output_size)
		echo "Space save: " $(human_readable_filesize $space_saved)
	fi
}

human_readable_filesize()
{
echo -n $1 | awk 'function human(x) {
     s=" b  Kb Mb Gb Tb"
     while (x>=1024 && length(s)>1) 
           {x/=1024; s=substr(s,4)}
     s=substr(s,1,4)
     xf=(s==" b ")?"%5d   ":"%.2f"
     return sprintf( xf"%s", x, s)
  }
  {gsub(/^[0-9]+/, human($1)); print}'
}

SHORTOPTS="h,i:,o:,q:,s"
LONGOPTS="help,input:,output:,quality,no-stats"
ARGS=$(getopt -s bash --options $SHORTOPTS --longoptions $LONGOPTS --name $PROGNAME -- "$@")

eval set -- "$ARGS"
while true; do
	case $1 in
		-h|--help)
			usage
			exit 0
			;;
		-i|--input)
			shift
			INPUT=$1
			;;
		-o|--output)
			shift
			OUTPUT=$1
			;;
		-q|--quality)
			shift
			QUALITY=$1
			;;
		-s|--no-stats)
			NOSTATS='1'
			;;
		--)
			shift
			break
			;;
		*)
			shift
			break
			;;
	esac
	shift
done

main