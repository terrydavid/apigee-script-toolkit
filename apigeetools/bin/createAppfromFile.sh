#!/bin/bash
 
#
# createApps
# creates Developer Apps
#
# this script reads from standard input. each line is expected to contain the following:
# 
#   display_name
#   api_product
#   app_name
#   consumer_key
#   consumer_secret
#
# usage:
#   createApps host_alias

#set -e

USAGE="host_alias"
TOOLSDIR="${APITOOLS_HOME}"

. "$TOOLSDIR/config/global"
. "$TOOLSDIR/lib/functions"

parseCommandline "$@"
checkArgs 1
jsonfile=${ARGS[0]}

URL="${APIGEE_HOST}/o/${ORGANIZATION}/developers/${DEVELOPER}/apps"

output=`curl -ns -S --basic -u "$CREDENTIALS" -X POST -H "Accept: application/json" -H "Content-Type: application/json" --data-binary "@${jsonfile}" -w "\n%{http_code}" "${URL}"`

RESPONSE=`echo "$output" | sed '$ d'`

STATUS_CODE=`echo "$output" | tail -n 1`
if [ "$STATUS_CODE" != "201" ]; then
	fail "$(basename "$0") failed with status $STATUS_CODE: $RESPONSE"
fi
debug "response is $RESPONSE"
