#!/bin/bash
#
# read a yaml file and extract the NameValuePairs section
# NameValuePairs:
#   driver: "simulator"
#   latitude: "37.4219999"

# Read the YAML file
data=$(cat config.yaml)

# Extract the NameValuePairs section from the YAML file
name_value_pairs=$(echo "$data" | grep -A1 'NameValuePairs' | tail -n 1)

# Prepare the command arguments
args=""
while read -r line; do
    name=$(echo "$line" | awk -F: '{print $1}' | tr -d ' ')
    value=$(echo "$line" | awk -F: '{print $2}' | tr -d ' ')
    args+=" --$name $value"
done <<< "$name_value_pairs"

# Call weectl with all the arguments
weectl $args
