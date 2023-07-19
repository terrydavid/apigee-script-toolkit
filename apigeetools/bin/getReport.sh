#!/bin/bash

# getReport
#
# gets the analytics report requested
#
# usage:
#   getReport <report_name>

#set -e

USAGE="<statistic_diminsion_query_string>  # ouput is simple list"
TOOLSDIR="${APITOOLS_HOME}"
. "$TOOLSDIR/lib/functions"
parseCommandline "$@"
checkArgs 1

RPTID="${ARGS[0]}"

URL="${APIGEE_HOST}/o/${ORGANIZATION}/e/${ENVIRONMENT}/reports/${RPTID}"

http_get "$URL"
