#!/bin/bash

[[ -f "${HOME}/apigee/../README.md" ]] && export APITOOLS_HOME="${HOME}/apigee"

# if [ ${APITOOLS_HOME} ] ; then

# 	export ORGANIZATION="lite"
# 	export ENVIRONMENT="stage"
# 	export DEVELOPER="terry.david@540.co"
# 	export SCHEME="https"
# 	export HOST_ALIAS="mgmt-api.prod"
# 	#export HOST_ALIAS="${ORGANIZATION}-${ENVIRONMENT}"; export PORT=":8080"
# 	export DOMAIN=".lite-portal.com"
# 	export PORT=""

# else
# 	echo "NO APITOOLS_HOME Directory: [${APITOOLS_HOME}]"
# 	exit 1
# fi
# set -x

export ENVARS=$1

source $HOME/apigee/config/${ENVARS}

export TOOLSDIR="${APITOOLS_HOME}"
export APISDIR="${HOME}/Projects/${APRJCT}/${ORGANIZATION}/${ENVIRONMENT}/apis"
if [[ ! -d $APISDIR ]] ; then
    if [[ ! -d ${HOME}/Projects/${APRJCT}/${ORGANIZATION}/${ENVIRONMENT} ]] ; then
        if [[ ! -d ${HOME}/Projects/${APRJCT}/${ORGANIZATION} ]] ; then
            mkdir ${HOME}/Projects/${APRJCT}/${ORGANIZATION}
        fi
        mkdir ${HOME}/Projects/${APRJCT}/${ORGANIZATION}/${ENVIRONMENT}
    fi
    mkdir ${APISDIR}
fi

export DEBUG=0
chmod 600 $HOME/.curlrc
echo -n "" >$HOME/.curlrc

export FRMT="json"
export APIGEE_HOST="${SCHEME}://${HOST_ALIAS}${DOMAIN}${PORT}/v1"
export ORG=${ORGANIZATION}
export ENV=${ENVIRONMENT}
export PATH="${PATH}:${APITOOLS_HOME}/bin"
export CDPATH="${CDPATH}:${APISDIR}"
export MOST="${APIGEE_HOST}"

source $HOME/.aliases

echo -en "APITOOLS ${APITOOLS_HOME} is set @\n\t${APISDIR}\n"
cd ${APISDIR}

set -