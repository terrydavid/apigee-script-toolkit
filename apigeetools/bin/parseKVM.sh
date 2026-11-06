#!/bin/bash

USAGE="keyvaluemap_name kvm_key kvmkey_value"
TOOLSDIR="${APITOOLS_HOME}"
. "${APITOOLS_HOME}/lib/functions"
parseCommandline "$@"

KVMN="${PPRAMS[0]}"
file="${KVMN}-${ENVIRONMENT}-711.kvm"
debug "[pKVM]: KVMN=$KVMN; file= $file"

# Ensure the file exists
if [[ ! -f "$file" ]]; then echo "File $file not found!"; exit 1; fi

while IFS=';' read -r var1 var2; do

    # Remove leading spaces from var1
    var1="${var1#"${var1%%[![:space:]]*}"}"
    
    # Skip if var2 is empty, false, or null (after trimming)
    if [[ -z "${var2//[[:space:]]/}" || "${var2//[[:space:]]/}" == "false" ]]; then
        continue
    fi

    # Check for multiline block start
    if [[ "$var2" == *"-----BEGIN"* ]]; then
        # Capture BEGIN line and initialize multiline content
        debug "[p7kV2] Starting to collect for $var1"
        multiline_content="$var2"
        
        # Read until END
        while IFS= read -r next_line; do
            multiline_content+=$'\n'"$next_line"
            if [[ "$next_line" == *"-----END"* ]]; then
                debug "[p7kV2] Finished Collecting for $var1: \n$multiline_content"
                break
            fi
        done
        var2="$multiline_content"
    fi

    # Process variables
    debug "[p7kV2] KVMN= $KVMN; key= $var1; value= $var2"
    put711kvmValue "$KVMN" "$var1" "$var2"

done < "$file"