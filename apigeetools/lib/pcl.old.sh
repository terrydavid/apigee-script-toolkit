







	# PPRAMS=""
	# NUMOPTS=0
	# ARGNO=0
	# export INLINE=""

	# # [[ $DEBUG -ge 4 ]] && 
	# 	debug "PCL[start]: ARGS=${ARGS}; NUMOPTS=${NUMOPTS}; PPRAMS=${PPRAMS}; \$@=$@; \$1=$1; \$2=$2; \$3=$3; \$4=$4; \$5=$5; \$*= $*"

	# while (( "$#" )); do
	# 	case "$1" in

	# 	-d[0-9]|--debug)
	# 		echo "" > $HOME/.curlrc
	# 		DEBUG="$OPTARG"
	# 		FLAGARG="$OPTARG"

	# 		# [[ $DEBUG -ge 4 ]] && debug "\${1:2:3}=${1:2:3}"
	# 		# if [[ ${1:2:3} = [0-9] ]]; then
	# 		# 	FLAGARG=${1:2:3}
	# 		# 	NUMOPTS+=1
	# 		# 	shift 				

	# 		# elif [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
	# 		# 	FLAGARG=$2
	# 		# 	NUMOPTS+=2
	# 		# 	shift 2

	# 		# else
	# 		# 	FLAGARG=9
	# 		# 	echo "Error: Argument for $1 is missing" >&2
	# 		# fi

	# 		# [[ $DEBUG -ge 4 ]] && debug "PCL[-d]: FLAGARG=${FLAGARG}; DEBUG=$DEBUG; .curlrc=`cat $HOME/.curlrc` "
	# 		# [[ "$FLAGARG" != "" ]] && export DEBUG=${FLAGARG}
	# 		[[ $DEBUG -ge 2 ]] && echo '-v' > $HOME/.curlrc
	# 		[[ $DEBUG -ge 4 ]] && debug "PCL[-d]: FLAGARG=${FLAGARG}; DEBUG=$DEBUG; .curlrc=`cat $HOME/.curlrc` "

	# 		debugOpts

	# 		[[ $DEBUG -ge 3 ]] && debug "PCL[-d]: FLAGARG=$FLAGARG; DEBUG=$DEBUG; .curlrc=`cat $HOME/.curlrc` "
	# 		;;

	# 	-e) 
	# 		# set environment
	# 		# FLAGARG=""
	# 		# if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
	# 		# 	FLAGARG=$2
	# 		# 	NUMOPTS+=2
	# 		# 	shift 2
	# 		# else
	# 		# 	echo "Error: Argument for $1 is missing" >&2
	# 		# 	exit 1
	# 		# fi
	# 		# if [[ "$FLAGARG" ]]; then
	# 			# export ENVIRONMENT=$FLAGARG
	# 		fi
	# 		export ENVIRONMENT=$OPTARG
	# 		[[ $DEBUG -eq 4 ]] && debug "PCL[-e]: ENVIRONMENT=$ENVIRONMENT"
	# 		;;

	# 	-h|--help) 
	# 		# help
	# 		usage
	# 		exit 0
	# 		;;

	# 	-i) 
	# 		export INLINE=true
	# 		shift
	# 		[[ $DEBUG -ge 4 ]] && debug "PCL[-i]: INLINE= $INLINE"
	# 		;;

	# 	-j) 
	# 		# set format to json (default)
	# 		FRMT=json
	# 		NUMOPTS+=1
	# 		shift
	# 		[[ $DEBUG -ge 4 ]] && debug "PCL[-j]: FRMT=$FRMT"
	# 		;;

	# 	-l) 
	# 		# set TRUE Delete
	# 		export TRUEDEL="true"
	# 		NUMOPTS+=1
	# 		shift
	# 		[[ $DEBUG -ge 4 ]] && debug "PCL[-l]: DEBUG=$DEBUG; TRUEDEL= $TRUEDEL"
	# 		;;

	# 	-o) 
	# 		# set organization
	# 		FLAGARG=""
	# 		if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
	# 			FLAGARG=$2
	# 			NUMOPTS+=2
	# 			shift 2
	# 		else
	# 			echo "Error: Argument for $1 is missing" >&2
	# 			exit 1
	# 		fi
	# 		if [[ "$FLAGARG" ]]; then
	# 			export ORGANIZATION=$FLAGARG
	# 		fi
	# 		[[ $DEBUG -ge 4 ]] && debug "PCL[-o]: ORGANIZATION=$ORGANIZATION"
	# 		;;

	# 	-v) 
	# 		# print version
	# 	    version
	# 	    exit 0
	# 	    ;;

	# 	-x) # set format to XML
	# 		FRMT=xml
	# 		NUMOPTS+=1
	# 		shift
	# 		[[ $DEBUG -eq 4 ]] && debug "PCL[-x]: FRMT=$FRMT"
	# 		;;

	# 	-*|--*) 
	# 		# unsupported flags
	# 		# [[ $DEBUG -ge 4 ]] && 
	# 			debug "PCL[--*]: OPTS=[${OPTS}] ARGS=[${ARGS}]; NUMOPTS=$NUMOPTS; PPRAMS=${PPRAMS}; \$1=$1; \$2=$2; \$*= $*; \$@= $@"
	# 		if [[ "$1" == *"-----BEGIN"* ]] ; then
	# 			echo "PCL: Ignoring ${1:0:12}" >&2
	# 			shift
	# 			continue
	# 		fi  # This is a kludge till I figure out the Ghost Params
	# 		echo "[PCL] Error: Unsupported flag ${1:0:12}" >&2
	# 		exit 1
	# 		;;

	# 	*)	PPRAMS="$PPRAMS $1"
	# 		[[ $DEBUG -ge 4 ]] && "PCL[*]: OPTS=[${OPTS}] ARGS=[${ARGS}]; NUMOPTS=$NUMOPTS; PPRAMS=${PPRAMS}; \$1=$1; \$2=$2; \$*= $*; \$@= $@"
	# 		shift
	# 		;;
	# 	esac

	# 	[[ $DEBUG -ge 4 ]] && 
	# 		debug "PCL[endloop]: OPTS=[${OPTS}] ARGS=[${ARGS}]; NUMOPTS=$NUMOPTS; PPRAMS=${PPRAMS}; \$1=$1; \$2=$2; \$*= $*; \$@= $@"
	# done

	# [[ $DEBUG -ge 4 ]] && 
	# 	debug "PCL[Before read ARGS]: ARGS=[${ARGS}]; NUMOPTS=$NUMOPTS; PPRAMS= $PPRAMS; \$1=$1; \$2=$2; \$*= $*; \$@=$@"

	# local IFS=', \n\r\t'; read -r -a ARGS <<< "$PPRAMS"
	# read -r -a ARGS <<< "$PPRAMS";

	# [[ $DEBUG -ge 4 ]] && 
		debug "PCL[end]: ARGS=${ARGS}; NUMOPTS=${NUMOPTS}; PPRAMS= ${PPRAMS}; \$1=$1; \$2=$2; \$*= $*; \$@=$@"
