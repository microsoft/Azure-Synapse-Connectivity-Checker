#!/bin/bash

#Test on MAC

# Define the workspace name
workspacename="REPLACEWORKSPACENAME"

echo "------------------------------------------------------------------------------------"
# Concatenate the workspace name with the domain
EndpointSynapseSQL="$workspacename.sql.azuresynapse.net"

# Perform the nslookup
result=$(nslookup "$EndpointSynapseSQL")

# Save the output to a variable
output=$(echo "$result" | awk '/^Address: / {print $2}')

# Print the output
echo "NSLookup Result for $EndpointSynapseSQL:"
echo "$output"

echo "------------------------------------------------------------------------------------"
# Concatenate the workspace name with the domain
EndpointSynapseServerless="$workspacename-ondemand.sql.azuresynapse.net"

# Perform the nslookup
result=$(nslookup "$EndpointSynapseServerless")

# Save the output to a variable
output=$(echo "$result" | awk '/^Address: / {print $2}')

# Print the output
echo "NSLookup Result for $EndpointSynapseServerless:"
echo "$output"

echo "------------------------------------------------------------------------------------"
# Concatenate the workspace name with the domain
EndpointSynapseDev="$workspacename.dev.azuresynapse.net"

# Perform the nslookup
result=$(nslookup "$EndpointSynapseDev")

# Save the output to a variable
output=$(echo "$result" | awk '/^Address: / {print $2}')

# Print the output
echo "NSLookup Result for $EndpointSynapseDev:"
echo "$output"

