parseCommandline() {

	echo "[PCL 1] \$@=$@"
	debug 
	echo "PCL[start]: ARGS=${ARGS}; NUMOPTS=${NUMOPTS}; PPRAMS=${PPRAMS}; \$1=$1; \$2=$2; \$3=$3; \$4=$4; \$5=$5; \$@=$@; \$*= $*"
	echo "[PCL 2] \$@=$@"

	while getopts "d:e:hijlo:vx" opt; do
		debug "[PCL]: OPTION= $opt"
		read -p "Beginning of PCL: OPTION= $opt; DEBUG= $DEBUG; InLINE= $INLINE"

		case $opt in 
			d) # Set up Debugging
				echo "PCL[-d]: opt= $opt; DEBUG= $DEBUG; InLINE= $INLINE; \$@= $@;"
				echo "" > $HOME/.curlrc
				export DEBUG=$OPTARG
				[[ $DEBUG -ge 1 ]] && debug "\${1:2:3}=${1:2:3}"
				[[ $DEBUG -ge 1 ]] && echo '-v' > $HOME/.curlrc
				[[ $DEBUG -ge 1 ]] && debug "PCL[-d]: opt= $opt; OPTARG=${OPTARG}; DEBUG=${DEBUG}; .curlrc=`cat $HOME/.curlrc` "
				debugOpts
				[[ $DEBUG -ge 1 ]] && debug "PCL[-d]: opt= $opt; OPTARG=${OPTARG}; DEBUG=${DEBUG}; .curlrc=`cat $HOME/.curlrc` "
				read -p "PCL[-d]: opt= $opt; DEBUG= $DEBUG; InLINE= $INLINE"
				;;

			e) # set environment
				export ENVIRONMENT=$OPTARG
				[[ $DEBUG -eq 4 ]] && debug "PCL[-e]: ENVIRONMENT=$ENVIRONMENT"
				;;

			h) # help
				usage
				exit 0
				;;

			i) # Use "MyTOKEN for Auth"
				export INLINE=true
				[[ $DEBUG -ge 4 ]] && debug "PCL[-i]: INLINE= $INLINE;  \$@=$@"
				read -p "PCL[-i]: opt= $opt; DEBUG= $DEBUG; InLINE= $INLINE; \$@=$@;"				shift
				echo "PCL[-i.2]: opt= $opt; DEBUG= $DEBUG; InLINE= $INLINE; \$@=$@;"
				;;

			j) # set format to json (default)
				FRMT=json
				[[ $DEBUG -ge 4 ]] && debug "PCL[-j]: FRMT=$FRMT"
				;;

			l) # set TRUE Delete
				export TRUEDEL="true"
				[[ $DEBUG -ge 4 ]] && debug "PCL[-l]: DEBUG=$DEBUG; TRUEDEL= $TRUEDEL"
				;;

			o) # set organization
				export ORGANIZATION=$OPTARG
				[[ $DEBUG -ge 4 ]] && debug "PCL[-o]: ORGANIZATION=$ORGANIZATION"
				;;

			v) # print version
				version
				exit 0
				;;

			x) # set format to XML
				FRMT=xml
				NUMOPTS+=1
				[[ $DEBUG -eq 4 ]] && debug "PCL[-x]: FRMT=$FRMT"
				;;

			*) # unsupported flags
				# [[ $DEBUG -ge 4 ]] && 
					debug "PCL[--*]: opt= $opt; OPTS=[${OPTS}] ARGS=[${ARGS}]; NUMOPTS=${NUMOPTS}; PPRAMS=${PPRAMS}; \$1=$1; \$2=$2; \$*= $*; \$@= $@"
				if [[ "$1" == *"-----BEGIN"* ]] ; then
					echo "PCL: Ignoring ${1:0:12}" >&2
					continue
				fi  # This is a kludge till I figure out the Ghost Params
				echo "[PCL] Error: Unsupported flag ${1:0:12}" >&2
				exit 1
				;;

			# *) # other args => params	
			# 	PPRAMS="$PPRAMS $1"
			# 	;;
		esac
		[[ $DEBUG -ge 1 ]] && 
			echo "PCL[*]: opt= $opt; OPTS=${OPTS} ARGS=${ARGS}; NUMOPTS=${NUMOPTS}; PPRAMS=${PPRAMS}; \$1=$1; \$2=$2; \$*= $*; \$@= $@"
	done
	echo "End of PCL; DEBUG= $DEBUG; InLINE= $INLINE"
	shift $((OPTIND - 1))
	read -p "End of PCL: opt= $opt; DEBUG= $DEBUG; InLINE= $INLINE; OPTIND= $OPTIND; \$@= $@; \$*= $*; ARGS= ${ARGS[@]}; NUMOPTS= $NUMOPTS; PPRAMS= $PPRAMS"
}
