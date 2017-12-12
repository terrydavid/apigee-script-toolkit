#!/bin/bash
APIGEE_TOOLS_VERSION='3.1.2'
# General approach
#	"get..." routines will retrieve formatted individual elements of the type
#	"get...s" routines will retrieve a list of elements of the type (TODO: change these all to "list...")
#	"list..." routines will retrieve a list of elements of the type
#	"json" formatting is actually a dimensioned array of elements (TODO: make parser recursive)

noop() {
	echo > /dev/null
}

error() {
	echo -e "ERROR: $(basename "$0"): $*" >&2
}

warn() {
	echo -e "Warning: $(basename "$0"): $*" >&2
}

debug() {
	[[ 
			"$DEBUG" != "false" && 
			"$DEBUG" != "" && 
			"$DEBUG" != "2" 
	]] && 
		echo -e "DEBUG[$DEBUG]: $(basename "$0"): $*" >&2
}

fail() {
	local RETVAL=$2
	if [ "$RETVAL" = "" ]; then
		RETVAL=1
	fi
	error "$1"
	exit $RETVAL
}

usefail() {
	local RETVAL=$2
	if [ "$RETVAL" = "" ]; then
		RETVAL=1
	fi
	error "$1"
	usage
	exit $RETVAL
}

version() {
    echo "$(basename "$0") version $APIGEE_TOOLS_VERSION"  
}

usage() {
	echo "usage: $(basename "$0") [-cd:e:hjlo:vx] $USAGE" >&2
	echo >&2
	echo "    -d[0-9] set Debug output 0=off; 2='curl'; 9=help" >&2
	echo "    -e set ENVIRONMENT" >&2
	echo "    -h print this Help message" >&2
	echo "    -j input/output data in Json format" >&2
	echo "    -l execute a %true% deLete" >&2
	echo "    -o set ORGANIZATION" >&2
	echo "    -v display Version information" >&2
	echo "    -x input/output data in Xml format" >&2
}

parseCommandline() {
	debug "PCL[-3]: DEBUG= $DEBUG; OPTARG= $OPTARG";
	while getopts "d:e:hjlo:vx" Option
	do
		case $Option in
		d)
			echo "" > $HOME/.curlrc
			debug "PCL[-2]: DEBUG= $DEBUG; OPTARG= $OPTARG"
			if [[ "$OPTARG" ]]; then
				DEBUG=${OPTARG}
			else 
				[ "$DEBUG" == "false" -o "$DEBUG" == "" ] && DEBUG="1"
			fi
			debug "PCL[-1]: DEBUG= $DEBUG; OPTARG= $OPTARG"
			case $DEBUG in 
				0) echo -n "" > $HOME/.curlrc ; export DEBUG=false ;;
				1) echo "-v" > $HOME/.curlrc ;;
				2) DEBUG=2 ; echo "2 is show 'curl' command only" ;;
				5) DEBUG=5 ; echo "5 is special true DELETE code" ;;
				7) echo "--trace" > $HOME/.curlrc ;;
				8) echo "--trace-ascii -" > $HOME/.curlrc ;;
				9) echo '
					0) "Turn Debug Off"
					1) "Turn Debug On (stays on until changed)"
					2) "Show 'curl' command only"
					5) "Issue true DELETE (other runs a GET)"
					7) "Adds '--trace' to $HOME/.curlrc"
					8) "Adds '--trace-ascii -' to $HOME/.curlrc"
					9) "Show this DEBUG Help"
					*) "Invalid DEBUG LEVEL"' ;;
				*) echo -en "\n\n Invalid DEBUG LVL: $DEBUG \n\n" ; exit 1 ;;
			esac
			;;
		e)
			ENVIRONMENT=$OPTARG
			;;
		h) 
			usage
			exit 0
			;;
		j)
			FRMT=json
			;;
		l)
			DEBUG=5 # Special option for "True" delete
			;;
		o)
			ORGANIZATION=$OPTARG
			;;
		v)
		    version
		    exit 0
		    ;;
		x)
			FRMT=xml
			;;
		esac
		shift
	done

	HOST_ALIAS="${ORGANIZATION}-${ENVIRONMENT}"
	debug "PCL[0]: HOST_ALIAS= $HOST_ALIAS"
	
	ARGS=("$@")
	debug "PCL[1]: ARGS= $ARGS; $@; $* "
	debug "PCL[2]: OPTS= ${OPTS[@]}; ARGS= ${ARGS[@]}"
}

checkArgs() {
	debug "ARGS=${ARGS[@]}"
}

findEnv() {
    if [ "_$1" == "_" ]; then
		usefail "no host specified"
    fi
	find -L ${TOOLSDIR} -name "$1"
}

loadConfig() {
	[[
		"_$ORGANIZATION" != "_" && 
		"_$ENVIRONMENT" != "_" && 
		"_$HOST_ALIAS" != "_" &&  
		"_$APIGEE_HOST" != "_" &&  
		"_$APITOOLS_HOME" != "_" &&  
		"_$TOOLSDIR" != "_" &&  
		"_$APISDIR" != "_" &&  
		"_$DEVELOPER" != "_" &&  
		"_$DEBUG" != "_" &&  
		"_$FRMT" != "_" &&  
		"_$MOST" != "_" &&  
		"_$PATH" != "_" &&  
		"_$ENV" != "_" # &&  
		#"_$ORG" != "_"
	]] && return
    usefail "Environment Settings Not Found:
		$ORGANIZATION 
		$ENVIRONMENT 
		$HOST_ALIAS  
		$APIGEE_HOST  
		$APITOOLS_HOME  
		$TOOLSDIR  
		$APISDIR  
		$DEVELOPER  
		$DEBUG  
		$FRMT  
		$MOST  
		$PATH  
		$ENV  
		$ORG
    "
}

loadTestParams() {
	local HOST="$1"
    if [ "$HOST" = "" ]; then
		usefail "no host environment specified"
	else
		debug "Loading Test Params for $1"
    fi

	local ENVIRON=`findEnv $HOST`
	local DIR=`dirname $ENVIRON`
	local ENV=$(basename $DIR ".d")
	local ENVCONFIG="$DIR/$ENV"
	local TESTCONFIG="$DIR/${ENV}.tp"

	debug "loading environment Test Params $TESTCONFIG"
    source "$TESTCONFIG"

    return $?

	local usrTParams="${HOME}/.apigee-tools/environments/$1.tp"
	if [ -e "$usrTParams" ]; then
		debug "loading environment config $usrTParams"
		source "$usrTParams"
	else
		debug "no environment config $usrTParams"
	fi
}

rest() {
	# All calls to rest must supply a Verb and a fully qualified URL 
	#   (Headers, output format; and curl options are specified in caller routine)
	#   (Output includes response and status code)
	local VERB=$1
	local URL=$2
	if [ "$FRMT" != "xml" -a "$FRMT" != "json" ] ; then
		FRMT=json
		debug "No FRMT [$FRMT]: setting to 'json'"
	fi
	local ACCPT="application/$FRMT"

	debug "[1] VERB=$VERB; URL=$URL; Headers: $HDRS ; curlOPTS: $curlOPTS ; ~/.curlrc = [`cat $HOME/.curlrc`]"

	case $VERB in
	"DELETE") ;;
	"GET") ;;
	"POST")
		if [ "$(echo $HDRS | grep Content-Type)" = 0 ] ; then
			HDRS="-HContent-Type:application/${FRMT} ${HDRS}"
		fi 
		debug "[POST] Headers: $HDRS ; curlOPTS: $curlOPTS ; ~/.curlrc = [`cat $HOME/.curlrc`]"
		;;
	*) fail "Invalid VERB=[$VERB] for curl call" ;;
	esac

	debug "[2] VERB=$VERB; URL=$URL; Headers: $HDRS ; curlOPTS: $curlOPTS ; ~/.curlrc = [`cat $HOME/.curlrc`]"

	# Non .netrc version
	#local output=$([ "$DEBUG" != "false" ] && set -x;curl -sSu "$CREDENTIALS" -X $VERB -H "Accept: $ACCPT" -w "\n%{http_code}\n" "${URL}" ${HDRS} ${curlOPTS};set -)

	# .netrc version
	local output=$([ "$DEBUG" != "false" -a "$DEBUG" != "" ] && set -x; curl -nsS -X ${VERB} ${URL} -HAccept:${ACCPT} ${HDRS} -w "\n%{http_code}\n" ${curlOPTS} ; set -)

	if [ "$output" != "" ] ; then
		STATUS_CODE=`echo "$output" | tail -n 1`
		rawRESPONSE=`echo "$output" | sed '$ d'`

		case $STATUS_CODE in
			"200"|"201")  # TODO: Need to do this as a "SUCCESS_CODES" list
				#echo -e "CURL Succeeded: STATUS_CODE= $STATUS_CODE"
				debug "CURL Succeeded: STATUS_CODE= $STATUS_CODE"
				;;
			*) fail "CURL call failed: STATUS_CODE= $STATUS_CODE; Output= \n$output"
				;;
		esac

		if [ "$FRMT" = "json" ] && [ "$rawResponse" != "" ] ; then
			RESPONSE=`echo "$rawRESPONSE" | "$TOOLSDIR/lib/jp.sh"`
			debug "rest: STATUS_CODE [${STATUS_CODE}]: \n\tRESPONSE= \n$RESPONSE\n\n\t"
		else
			RESPONSE=`echo "$rawRESPONSE"`
			debug "rest: STATUS_CODE [${STATUS_CODE}]: \n\tRESPONSE= \n$RESPONSE\n\n\t"
		fi
	else
		fail "CURL call failed: Output= $output"
	fi

	debug "\n\tRawOutput= \n$output\n\t"
}

http_get() {
	# $2=URL (full)
	rest GET $1
}

http_post() {
	# $2=URL (full)
	rest POST $1
}

http_delete() {
	# $1=URL (full)
	VERB=GET
	[ "$DEBUG" = "5" ] && VERB=DELETE
	debug "http_delete: $VERB $1"
	rest $VERB $1
}

getApigee() {
	# $1 = HOST_ALIAS (curr not used: config loaded "APIGEE_HOST")
	# $2 = host relative URL
	local RESOURCE_PATH="$2"

	local URL="${APIGEE_HOST}${RESOURCE_PATH}"
	http_get "$URL"
}

trims() {
	sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

uri_escape() {
	local y ; y="$@" ;
	echo -n ${y/\\/\\\\} | while read -n1 ; do 
		[[ $REPLY =~ [A-Za-z0-9] ]] && printf "$REPLY" || printf "%%%x" \'"$REPLY" ;
	done ; echo ;
}

xmlValueOf() {
	local field=$1
	local sp='s/[\<\/]*\('${field}'\)[\/\>]*//g'
	debug "xmlValueOf ${field} from stream $sp"
	grep "${field}" | sed "$sp" 
}

jsonValueOf() {
	local field=$1
	echo "BEGIN { RS = \"[\\n\\r]+\" } ; /${field}/ {print \$2}" >awk.inf
	debug "jsonValueOf ${field} from stream `cat awk.inf`"
	awk -f awk.inf -
}

jsonValueSet() {
	local field=$1
	local value=$2
	echo "BEGIN { RS = \"[\\n\\r]+\" } ; /${field}/ {print \$2}" >awk.inf
	debug "jsonValueOf $field from stream `cat awk.inf`"
	awk -f awk.inf -
	sed 's/\("name"[:, "]*$field'
}

listify() {
	[ "$FRMT" = "xml" ] && xmlValueOf $1
	[ "$FRMT" = "json" ] && jsonValueOf $1
}

export STATUS_CODE
export RESPONSE
export curlOPTS
export HDRS
