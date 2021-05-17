#!/bin/bash

if [ -d $APITOOLS_HOME ] ; then
	export APITOOLS_HOME="$HOME/<wkspace-dir>"
	export PATH="$PATH:${APITOOLS_HOME}/bin"
	export TOOLSDIR="${APITOOLS_HOME}"
	export APISDIR="$TOOLSDIR/apis"
	
	export DEVELOPER=${1:-"<developer-email-id>"}
	
	export ORGANIZATION=${2:-"<org>"}
	
	export ENVIRONMENT=${3:-"<env>"}

	export DEBUG="false"
	echo -n"">$HOME/.curlrc

	export FRMT="json"
	
	export ENV="<env>"
	export ORGANIZATION="<org>"
	
	export HOST_ALIAS="env-org"
	export APIGEE_HOST="https://api.enterprise.apigee.com/v1"
	export ENIVRONMENTS="\($HOST_ALIAS\)"
fi
