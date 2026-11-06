#!/bin/bash
# -*- mode:shell-script; coding:utf-8; -*-
#
# Delete an organization from an OPDK installation. 
#
# This script will destroy data. 
#
# This is not fully tested. 
# 
# To delete an organization, this script: 
# 
# - inquires the API proxies
# - for each APIproxy, undeploys if necessary, and then deletes the proxy
# - inquires environments
# - for each environment, inquires vhosts, then deletes each one
# - inquires message processors and postgres servers
# - for each environment, removes association to each MP and PG
# - for each environment, deletes the environment
# - gets the list of PODs for the org
# - removes the association between pod and org
# - deletes the org
#
# Copyright (c) 2015 by Dino Chiesa and Apigee Corporation
# All rights reserved.
#
# This code is licensed under a Revised BSD-style 3-clause license:
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
#    - Redistributions of source code must retain the above copyright
#      notice, this list of conditions and the disclaimer that follows.
#
#    - Redistributions in binary form must reproduce the above copyright
#      notice, this list of conditions and the disclaimer that follows in
#      the documentation and/or other materials provided with the
#      distribution.
#
#    - The name of the contributors may not be used to endorse or promote
#      products derived from this software without specific prior written
#      permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
# IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
# TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
# PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
# TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
#
#
# Created: <Fri Jun 19 17:07:14 2015>
# Last Updated: <2015-June-22 14:07:24>
#


MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. ${MYDIR}/json-parse.sh

EDGE_BINDIR=/opt/apigee4/bin
. ${EDGE_BINDIR}/apigee-env.sh
. ${EDGE_BINDIR}/apigee-lib.sh
sleeptime=1
verbosity=2
TAB=$'\t'

if [ -z "$MSIP" ]; then
  echo "No MSIP (management server ip-address/fqdn) found in ${BIN_DIR}/apigee-env.sh."
  echo "Run this script after running apigee-setup.sh."
  exit 1
fi

usage() {
        CMD=`basename $0`
        echo "Usage:"
        echo "$CMD [-o org-name] [-u admin] [-p password] [-q] [-v"
  echo "            -o  org-name:   name of existing organization to delete"
  echo "              password:   password of global system admin"
  echo "              admin:      administrator user-name (email)"
  echo "  -q        quiet; decrease verbosity by 1"
  echo "  -v        verbose; increase verbosity by 1"
        exit 1
}



## function MYCURL_Q
## Print the curl command, omitting sensitive parameters, then run it.
## There are side effects:
## 1. puts curl output into file named ${CURL_OUT}. If the CURL_OUT
##    env var is not set prior to calling this function, it is created
##    and the name of a tmp file in /tmp is placed there.
## 2. puts curl http_status into variable CURL_RC
function MYCURL_Q() {
  local outargs
  local allargs
  local ix
  local ix2
  local re
  re="^(-[du]|--user)$" # the curl options to not echo
  # grab the curl args, but skip the basic auth and the payload, if any.
  while [ "$1" ]; do
      allargs[$ix2]=$1
      let "ix2+=1"
      if [[ $1 =~ $re ]]; then
        shift
        allargs[$ix2]=$1
        let "ix2+=1"
      else
        outargs[$ix]=$1
        let "ix+=1"
      fi
      shift
  done

  [ -z "${CURL_OUT}" ] && CURL_OUT=`mktemp /tmp/apigee-pushapi.curl.out.XXXXXX`

  if [ $verbosity -gt 1 ]; then
    # emit the curl command, without the auth + payload
    echo
    echo "curl ${outargs[@]}"
  fi
  # run the curl command
  CURL_RC=`curl -s -w "%{http_code}" -o "${CURL_OUT}" "${allargs[@]}"`
  if [ $verbosity -gt 1 ]; then
    # emit the http status code
    echo "==> ${CURL_RC}"
    echo
  fi
}


undeploy_and_delete_api() {
    local proxyname
    local output_parsed
    local m
    local deployments
    local rev
    local env
    proxyname=$1

    MYCURL_Q -u "${ADMIN_EMAIL}:${APW}" -X GET http://${MSIP}:${PORT}/v1/o/${ORG_NAME}/apis/$proxyname/deployments
    if [ ${CURL_RC} -ne 200 ]; then
        echo An unknown error occurred.
        cat ${CURL_OUT}
        echo
        exit 1
    fi

    output_parsed=`cat ${CURL_OUT} | json_tokenize | json_parse`
    echo parsed=$output_parsed
    echo
    deployed_envs=`echo "${output_parsed}" | grep \"environment\" | grep -v \"revision\" | grep \"name\" | sed -E 's/\"//g'| sed -E 's/.+environment,[0-9]+,name.'"${TAB}"'//g'`
    deployed_revs=`echo "${output_parsed}" | grep \"environment\" | grep \"revision\" | grep \"name\" | sed -E 's/\"//g'| sed -E 's/.+environment,[0-9]+,revision,[0-9]+,name.'"${TAB}"'//g'`

    declare -a rev_array=(${deployed_revs})
    declare -a env_array=(${deployed_envs})

    m=${#rev_array[@]} 
    if [ $verbosity -gt 1 ]; then
        echo found ${m} deployed revisions
    fi

    deployments=() 
    let m-=1
    while [ $m -ge 0 ]; do
        #echo "${env_array[$m]}=${rev_array[$m]}"
        deployments+=("${env_array[$m]}=${rev_array[$m]}")
        let m-=1
    done

    # echo ${deployments}
    # iterate through all deployments
    if [ ${#deployments[@]} -gt 0 ] ; then
        for deployment in ${deployments[@]}; do
            env=`expr "$deployment" : '\([^=]*\)'`
            rev=`expr "$deployment" : '[^=]*=\([^=]*\)'`
            echo api ${proxyname}: undeploying revision ${rev} from ${env}...
            # MYCURL_Q -u "${ADMIN_EMAIL}:${APW}" -X POST "http://${MSIP}:${PORT}/v1/o/${ORG_NAME}/apis/$proxyname/revisions/${rev}/deployments?action=undeploy&env=${env}"
            # if [ ${CURL_RC} -ne 200 ]; then
            #     echo The undeploy failed.
            #     echo
            #     exit 1
            # fi
        done
        echo "undeployed all revisions..."
        sleep 1
    else
        echo "No revisions to undeploy..."
        sleep 1
    fi

    # Delete the proxy (all revisions)
    echo api ${proxyname}: deleting all revisions ...
    # MYCURL_Q -u "${ADMIN_EMAIL}:${APW}" -X DELETE "http://${MSIP}:${PORT}/v1/o/${ORG_NAME}/apis/$proxyname"
    # if [ ${CURL_RC} -ne 200 ]; then
    #     echo The delete failed.
    #     echo
    #     exit 1
    # fi

}



get_mp_uuids() {
    echo finding UUIDs of Message Processors
    MYCURL_Q -u "${ADMIN_EMAIL}:${APW}" -X GET "http://${MSIP}:${PORT}/v1/servers?region=dc-1&pod=gateway"

    if [ ${CURL_RC} -ne 200 ]; then
        echo The inquiry failed.
        echo
        exit 1
    fi

    MESSAGEPROCESSORS=( $(cat ${CURL_OUT} | grep -A 1 -B 0 "message-processor" | grep uUID | sed -E 's/\"//g' | sed -E 's/uUID : //g') )

    echo "Message Processors: "
    echo $MESSAGEPROCESSORS
}


get_pg_uuids() {
    echo finding UUIDs of Postgres servers
    MYCURL_Q -u "${ADMIN_EMAIL}:${APW}" -X GET "http://${MSIP}:${PORT}/v1/servers?region=dc-1&pod=analytics"

    if [ ${CURL_RC} -ne 200 ]; then
        echo The inquiry failed.
        echo
        exit 1
    fi

    PGSERVERS=( $(cat ${CURL_OUT} | grep -A 1 -B 0 "postgres-server" | grep uUID | sed -E 's/\"//g' | sed -E 's/uUID : //g') )

    echo "PG Servers: "
    echo $PGSERVERS
}


delete_all_vhosts() {
    local env
    local vhost
    local VHOSTS
    env=$1

    echo querying virtual hosts...
    MYCURL_Q -u "${ADMIN_EMAIL}:${APW}" -X GET \
        http://${MSIP}:${PORT}/v1/o/${ORG_NAME}/e/$env/virtualhosts

    if [ ${CURL_RC} -ne 200 ]; then
        echo The inquiry failed.
        echo
        exit 1
    fi

    VHOSTS=$( ( cat ${CURL_OUT} | sed 's/[ \"]//g' | sed 's/,/ /g' | sed 's/^\[//' | sed 's/\]$//' ) )

    for vhost in ${VHOSTS}; do
        echo
        echo ============================================ 
        echo Delete VHOST $vhost
        MYCURL_Q -u "${ADMIN_EMAIL}:${APW}" -X DELETE \
            http://${MSIP}:${PORT}/v1/o/${ORG_NAME}/e/$env/virtualhosts/$vhost
        echo
        echo

        if [ ${CURL_RC} -ne 200 ]; then
            echo The delete failed.
            echo
            exit 1
        fi
    done
    sleep ${sleeptime}
}

remove_servers_from_env() {
    local env
    local mp
    local pg
    local SERVERS
    local server
    env=$1

    echo Query servers for env ${env} ...
    MYCURL_Q -u "${ADMIN_EMAIL}:${APW}" -X GET \
        http://${MSIP}:${PORT}/v1/o/${ORG_NAME}/e/$env/servers

    if [ ${CURL_RC} -ne 200 ]; then
        echo The query failed.
        echo
        exit 1
    fi
    SERVERS=$( ( cat ${CURL_OUT} | sed 's/[ \"]//g' | sed 's/,/ /g' | sed 's/^\[//' | sed 's/\]$//' ) )

    for mp in ${MESSAGEPROCESSORS}; do
        for server in ${SERVERS}; do
            if [ $server = $mp ]; then 
              echo removing association of MP ${mp} to env ${env}
              MYCURL_Q -u "${ADMIN_EMAIL}:${APW}" -X POST \
                -H "Content-Type: application/x-www-form-urlencoded" \
                http://${MSIP}:${PORT}/v1/o/${ORG_NAME}/e/$env/servers \
                -d "action=remove&uuid=$mp"
              if [ ${CURL_RC} -ne 200 ]; then
                  echo The action failed.
                  echo
                  exit 1
              fi
            fi
        done
    done

    for pg in ${PGSERVERS}; do
        echo removing association of Postgres ${pg} to env ${env}
        MYCURL_Q -u "${ADMIN_EMAIL}:${APW}" -X POST \
            -H "Content-Type: application/x-www-form-urlencoded" \
            http://${MSIP}:${PORT}/v1/o/${ORG_NAME}/e/$env/servers \
            -d "action=remove&uuid=$pg"
        if [ ${CURL_RC} -ne 200 ]; then
            echo The action failed.
            echo
            exit 1
        fi

        # ## I don't think so.
        # echo removing PG from Analytics pod  
        # MYCURL_Q -u "${ADMIN_EMAIL}:${APW}" -X POST \
        #     -H "Content-Type: application/x-www-form-urlencoded" \
        #     "http://${MSIP}:${PORT}/v1/servers?region=dc-1&pod=analytics" \
        #     -d "action=remove&uuid=$pg"

    done
}

get_pod_list() {
    echo querying pods....
    MYCURL_Q -u "${ADMIN_EMAIL}:${APW}" -X GET http://${MSIP}:${PORT}/v1/o/${ORG_NAME}/pods
    PODS=$( ( cat ${CURL_OUT} | grep name | sed 's/\"name\"//g' | sed 's/[ \":,]//g' ) )
}

get_env_list() {
    echo querying environments....
    MYCURL_Q -u "${ADMIN_EMAIL}:${APW}" -X GET http://${MSIP}:${PORT}/v1/o/${ORG_NAME}/e
    ENVIRONMENTS=$( ( cat ${CURL_OUT} | sed 's/[ \"]//g' | sed 's/,/ /g' | sed 's/^\[//' | sed 's/\]$//' ) )
}

get_apiproxies() {
    echo querying APIs in the organization...
    MYCURL_Q -u "${ADMIN_EMAIL}:${APW}" -X GET http://${MSIP}:${PORT}/v1/o/${ORG_NAME}/apis
    if [ ${CURL_RC} -ne 200 ]; then
        echo cannot inquire APIs... Cannot continue. 
        echo 
        exit 1
    fi

    APIS=`cat ${CURL_OUT} | sed 's/[ \"]//g' | sed 's/,/ /g' | sed 's/^\[//' | sed 's/\]$//'`
    #println "$APIS"
}


while getopts "p:m:o:a:u:h" opt; do
  case $opt in
    # variable options
    p)  APW=$OPTARG ;;
    u)  ADMIN_EMAIL=$OPTARG ;;
    o)  ORG_NAME=$OPTARG ;;
    ##a)  ORG_ADMIN=$OPTARG ;;
    h)  usage ;;
        *)  usage
  esac
done

PORT="${APIGEE_PORT_HTTP_MS}"

[ -z "${ORG_NAME}" ] && ORG_NAME=`get_input "Enter organization name" mand=y default=example`
##[ -z "${ORG_ADMIN}" ] && ORG_ADMIN=`get_input "Enter organization admin name" default=${ADMIN_EMAIL}`

##[ ms_reachable ] && [ -z "${APW}" ] && enter_APW

[ -z "${ADMIN_EMAIL}" ] && echo "you must specify an email account." && exit 1
[ -z "${APW}" ] && enter_APW
[ -z "${APW}" ] && echo "you must specify a password." && exit 1


get_apiproxies
for api in ${APIS}; do
  echo
  echo ============================================ 
  echo APIPROXY $api
  undeploy_and_delete_api $api 
  echo
  echo
  echo
#  sleep ${sleeptime}
done

get_env_list
for env in ${ENVIRONMENTS}; do
    echo
    echo ============================================ 
    echo $env
    delete_all_vhosts $env
    echo
done

get_mp_uuids
get_pg_uuids

for env in ${ENVIRONMENTS}; do
    echo
    echo ============================================ 
    echo $env
    # remove_servers_from_env $env
    echo
    echo Update Analytics Group axgroup001
    MYCURL_Q -u "${ADMIN_EMAIL}:${APW}" -X DELETE \
        "http://${MSIP}:${PORT}/v1/analytics/groups/ax/axgroup001/scopes?org=${ORG_NAME}&env=$env"
    if [ ${CURL_RC} -ne 200 ]; then
        echo cannot update AX group... Cannot continue. 
        echo 
        exit 1
    fi

    echo Delete the environment ${env}
    MYCURL_Q -u "${ADMIN_EMAIL}:${APW}" -X DELETE \
        "http://${MSIP}:${PORT}/v1/o/${ORG_NAME}/e/$env" 

    if [ ${CURL_RC} -ne 200 ]; then
        echo cannot delete environment ${env}... Cannot continue. 
        echo 
        exit 1
    fi
done


get_pod_list
for pod in ${PODS}; do
    echo Removing org association to pod ${pod}
    MYCURL_Q -u "${ADMIN_EMAIL}:${APW}" -X POST \
        -H "Content-Type: application/x-www-form-urlencoded" \
        http://${MSIP}:${PORT}/v1/o/${ORG_NAME}/pods \
        -d "action=remove&region=dc-&pod=${pod}"
    if [ ${CURL_RC} -ne 200 ]; then
        echo cannot remove association to pod ${pod}... Cannot continue. 
        echo 
        exit 1
    fi
done


echo "Finally, delete the organization..."
MYCURL_Q -u "${ADMIN_EMAIL}:${APW}" -X DELETE \
    http://${MSIP}:${PORT}/v1/o/${ORG_NAME}
if [ ${CURL_RC} -ne 200 ]; then
    echo cannot delete organization ${ORG_NAME}... 
    echo 
    exit 1
fi

exit 0

