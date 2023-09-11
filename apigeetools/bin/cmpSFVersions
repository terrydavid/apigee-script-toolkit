#!/bin/bash

# cmpSFVersions
#

# usage:
#   cmpSFVersions ApiProxyName Rev-A Rev-B
#set -e

USAGE="sharedflowname [revA [revB]] 
If only sFlow name is provided compares LATEST_VERSION to DEPLOYED_VERSION  
If sFlow name and <revA> are provided compares LATEST_VERSION to revA 
If sFlow name, <revA> and <revB> are provided, compares revA to revB"

TOOLSDIR="${APITOOLS_HOME}"
. "$TOOLSDIR/lib/functions"
parseCommandline "$@"
checkArgs 2

SFLOW="${ARGS[0]}"
REVA="${ARGS[1]}"
REVB="${ARGS[2]}"

[[ ! ${SFLOW} ]] && usefail "No SFLOW found"

if [[ ! "${REVA}" ]] ; then
	REVA=`getSFRevisionLatest "$SFLOW"`
fi
debug "REVA=$REVA"

if [[ ! "${REVB}" ]] ; then
	REVB=`getSFRevisionDeployed "$SFLOW"`
fi
debug "REVB=$REVB"

[[ "$REVA" == "$REVB" ]] && usefail "Versions are the same"

printf "%-35s%6s%10s\n" "SFLOW" "Latest" "Deployed"
printf "%-35s%6s%10s%s\n" "$SFLOW" "$REVA" "$REVB" "$TAG"

# set -x
cd "${APISDIR}/../shFlows"

dlSFlow "$SFLOW" "$REVA" "$SFLOW"-"$REVA".zip # 2>/dev/null
unzip -oq $SFLOW-$REVA.zip -d $SFLOW-$REVA # 2>&1 >/dev/null

dlSFlow "$SFLOW" "$REVB" "$SFLOW"-"$REVB".zip # 2>/dev/null
unzip -oq $SFLOW-$REVB.zip -d $SFLOW-$REVB # 2>&1 >/dev/null

diff -br "$SFLOW-$REVA/" "$SFLOW-$REVB/" | grep -v '\(evision\|ersion\|anifest\)'
cd -
set -