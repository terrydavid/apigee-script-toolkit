#!/bin/bash

# set -x  # v 

function usefail () { echo $@ ;}

while getopts "d:e:hjlo:vx" Option; do
	echo -e "\nPCL[1]: Option= $Option; OPTARG= $OPTARG; OPTIND=${OPTIND}; \n\t\$@= $@"

	case $Option in

		d) echo -n "" > $HOME/.curlrc; DEBUG=0;
			[[ "$OPTARG" ]] && DEBUG="${OPTARG}"
			;;
		e) export ENVIRONMENT=$OPTARG
			export ENV=$OPTARG
			;;
		h) usage
			debug_help
			exit 0
			;;
		j) FRMT=json
			;;
		l) DEBUG=5 # Special option for "True" delete
			;;
		o) export ORGANIZATION=$OPTARG
			export ORG=$OPTARG
			;;
		v) version
			exit 0
			;;
		x) FRMT=xml
			;;

		# \?) usefail "Unknown Option: -$Option" 

		*) usefail "Unknown Option: -$Option" 
			;;

		:) usefail "Invalid OPTARG: -$Option requires an argument"
       		;;
	esac

	echo  -e "PCL[1a]: finished processing (before shift) Option $Option; \n\t\$1= $1"
	shift $((OPTIND -1))
	echo  -e "PCL[1b]: after Option $Option; \$1= $1; OPTARG= ${OPTARG}; OPTIND=${OPTIND}; \n\tARGS= ${ARGS}; \n\t\$@= $@;"
done

exec set -- "$@"

echo -e "PCL[5]: OPTS= ${OPTS[@]}; ARGS= ${ARGS[@]}; \n\t\$@= $@; \n\t\$*= $*"
set -
