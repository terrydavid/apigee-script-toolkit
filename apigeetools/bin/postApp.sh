#!/bin/bash

# postApp
#
# Creates a new developer app
#
# usage:
#   postApp app_name

USAGE="app_name api_product [developer]"

TOOLSDIR="${APITOOLS_HOME}"
. "$TOOLSDIR/lib/functions"
parseCommandline "$@"
checkArgs 2

APP_NAME=${ARGS[0]}
PRODUCT=${ARGS[1]}

[[ ${ARGS[2]} ]] && DEVELOPER=${ARGS[2]}

URL="${APIGEE_HOST}/o/${ORGANIZATION}/developers/${DEVELOPER}/apps/${APP_NAME}"

BODY="{ \
	\"apiProducts\": [ \"${PRODUCT}\" ], \
	\"attributes\": [  \
		{ \"name\": \"ADMIN_EMAIL\", \"value\": \"admin@example.com\" }, \
		{ \"name\": \"DisplayName\", \"value\": \"${APP_NAME}\" }, \
		{ \"name\": \"Notes\", \"value\": \"Notes for developer app\" }, \
		{ \"name\": \"MINT_BILLING_TYPE\", \"value\": \"POSTPAID\" } \
		], \
	\"callbackUrl\": \"example.com\", \
	\"name\": \"${APP_NAME}\", \
	\"scopes\": [], \
	\"status\": \"approved\" \
}"

http_get "$URL"

echo $RESPONSE
echo $STATUS_CODE
