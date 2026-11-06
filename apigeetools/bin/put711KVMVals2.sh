#!/usr/bin/env bash
#!/bin/bash
#
# 1. set711e (mod envs)
# 2. get711KVMaps > .txt
# 3. get711KVMNames > .keys
# 4. get711KVMValue > .kvm
#
# getKVMValue
# 	gets a KVM value for the keyname
#
#Scoped to environment:
#  https://api.enterprise.apigee.com/o/{org_name}/environments/{env_name}/keyvaluemaps
#

#set +e

USAGE="environment keyvaluemap_name"
TOOLSDIR="${APITOOLS_HOME}"
. "${APITOOLS_HOME}/lib/functions"
parseCommandline "$@"
FRMT="json"

ENVIRON=${ARGS[0]}
KVMNAME=${ARGS[1]}
# KVMKEY=${ARGS[2]}

ENVIRON=$1
KVMNAME=$2
KVMKEY=$3

BUFFER=''
COLLECTING=false
current_key=""

[[ $DEBUG -ge 1 ]] & echo "In put711KVMValues [1]; ENVIRON= ${ENVIRON}; KVMNAME= $KVMNAME; ARGS= ${ARGS[@]}"

set -x
if [[ $KVMNAME ]] ; then
    [[ $DEBUG -ge 1 ]] && echo "in put711KVMValues [3]; ENVIRON= ${ENVIRON}; KVMNAME= $KVMNAME"
    debug "parseKVM.sh $KVMNAME"
    parseKVM.sh "$KVMNAME"
    [[ $DEBUG -ge 1 ]] && echo "in put711KVMValues [5]"

else
    [[ $DEBUG -ge 1 ]] && echo "in put711KVMValues [4]"
    for mn in `cat ${ENVIRON}-711-map-names.txt`; do
        debug "parseKVM.sh KVMNAME= $mn"
        parseKVM.sh "$mn"
    done
fi
set -
