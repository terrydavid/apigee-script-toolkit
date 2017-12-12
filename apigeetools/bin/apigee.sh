#!/bin/bash

export MOST="https://api.enterprise.apigee.com/v1"
export APITOOLS_HOME="$HOME/apigee"
export PATH="$PATH:$APITOOLS_HOME/bin"

export TOOLSDIR="${APITOOLS_HOME}"
export APISDIR="$HOME/apigee/apis"

#export ORGANIZATION="tdavid"
#export DEVELOPER="tdavid99@gmail.com"

#export ORGANIZATION="th-innovation"
export ORGANIZATION="bcbsma-nonprod"
export ORGANIZATION="bcbsma"
export DEVELOPER="terrance.david@perficient.com"

# Debugging
export DEBUG="false"
echo -n "" >$HOME/.curlrc

# default Data format for input & output: json OR xml
export FRMT="xml"
export FRMT="json"

# Some aliases are based on these env vars
source $HOME/.aliases

if [ -d $APITOOLS_HOME ] ; then
	export ENV=$ORGANIZATION
	export ENVIRONMENT="dev"
	export HOST_ALIAS="$ORGANIZATION-$ENVIRONMENT"
	export APIGEE_HOST="$MOST"
	export ENVIRONMENTS="\($HOST_ALIAS\)"
else
	echo "NO [$APITOOLS_HOME] Directory"
fi

