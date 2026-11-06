#!/bin/bash
 
#
# createAppfmFile
# creates Developer Apps
#
# this script reads from standard input. each line is expected to contain the following:
#
# usage:
#   createApp filename

#set -e

USAGE="file_Name"
TOOLSDIR="${APITOOLS_HOME}"
. "$TOOLSDIR/lib/functions"
parseCommandline "$@"
checkArgs 1

jsonfile=${ARGS[0]}

URL="${APIGEE_HOST}/o/${ORGANIZATION}/developers/${DEVELOPER}/apps"

output=`curl -ns -S --basic -w "\n%{http_code}" -X POST "${URL}" \
	-H "Accept: application/json" \
	-H "Content-Type: application/json" \
	--data-binary "@${jsonfile}"`

RESPONSE=`echo "$output" | sed '$ d'`

STATUS_CODE=`echo "$output" | tail -n 1`
if [ "$STATUS_CODE" != "201" ]; then
	fail "$(basename "$0") failed with status $STATUS_CODE: $RESPONSE"
fi
debug "response is $RESPONSE"
