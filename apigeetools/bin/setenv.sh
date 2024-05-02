#!/bin/bash
# set -x

[[ -f "${HOME}/apigee/README.md" ]] && export APITOOLS_HOME="${HOME}/apigee"

[[ "_$1" == "_" ]] && exit 1

export ENVARS=$1

source ${ENVARS}

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

set - 
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

echo -en "\nAPISDIR = ${APISDIR}\n"
cd ${APISDIR}

set -