parseLine () {
    local mn=$1

    collecting=false
    buffer=""
    current_key=""

    while IFS= read -r line; do
    # If currently collecting a multi-line block
        if $collecting; then
            buffer+=$'\n'"$line"

            if [[ "$line" == -----END* ]]; then
                # Finished collecting block
                echo "{ \"name\" : \"$current_key\", \"value\" : \"$buffer\" }"
                collecting=false
                buffer=""
                current_key=""
            fi
            continue
        fi

        # Skip empty lines
        [[ -z "${line// }" ]] && continue

        # Skip lines without ';'
        [[ "$line" != *";"* ]] && continue

        key="${line%%;*}"
        value="${line#*;}"

        # Trim key
        KVMKEY="$(echo "$key" | xargs)"

        # Check if value starts a BEGIN block
        if [[ "$value" == -----BEGIN* ]]; then
            collecting=true
            current_key="$key"
            buffer="$value"
            continue
        fi

        # Otherwise normal single-line case
        KVMVAL="$(echo "$value" | xargs)"

        debug "pL[76] ${mn} ${KVMKEY} ${KVMVAL}"
        [[ $KVMVAL ]] && echo "{ \"name\" : \"$KVMKEY\", \"value\" : \"$KVMVAL\" }"

        # [[ $KVMVAL ]] && put711KVMValue ${mn} ${KVMKEY} ${KVMVAL} # moved to putMapYals
    done
}
