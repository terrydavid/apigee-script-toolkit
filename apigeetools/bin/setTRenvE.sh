#!/bin/bash

export MyTOKEN=

# Log in to gcloud
if [ ! $MyTOKEN ] ; then
    gcloud auth login
    export MyTOKEN="$(gcloud auth print-access-token)"
fi

set +e

ENVIRON="${1:-dev}"

export APITOOLS_HOME="$APIGEE_HOME"
export APISDIR="$HOME/Projects/thomrtrs/apis"

# Endpoints for client access
export VIRT_HOST="35.190.46.84"

export DEVELOPER="terrance.david@thomsonreuters.com"
export FRMT="json"

export ORGANIZATION="tr-api-cloud-qa"
# [[ $ENVIRON -eq "prod" ]] && export ORGANIZATION="a202210-apigee-prod"
export ENVIRONMENT="${ENVIRON}"

export SCHEME="https"
export PORT=":443"

# Apigee X
# export HOST_ALIAS="apigee"
# export DOMAIN=".googleapis.com"

# Apigee EDGE
export HOST_ALIAS="thomson-reuters-nonprod.login"
export DOMAIN=".apigee.com"

export APIGEE_HOST="${SCHEME}://${HOST_ALIAS}${DOMAIN}${PORT}/v1"

listevars

echo "TODO: create a config file for each ApiG instance and 1 command to switch"