#!/bin/bash

# Azure Synapse Test Connection - Linux Version
# Tested on 
#  - Linux (Azure VM - ubuntu 23.04) - 2023-07-06
#  - Linux (Azure VM - Red Hat Enterprise Linux 8.7) - 2023-07-07

# Author: Sergio Fonseca
# Twitter @FonsecaSergio
# Email: sergio.fonseca@microsoft.com
# Last Updated: 2023-10-12

## Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.

#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
#WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


# Define the workspace name
workspacename="REPLACEWORKSPACENAME"

# Set as true if you don't want to send anonymous usage data to Microsoft
DisableAnonymousTelemetry=false
#Data Collection. The software may collect information about you and your use of the software and send it to Microsoft. Microsoft may use this information to provide services and improve our products and services. You may turn off the telemetry as described in the repository. There are also some features in the software that may enable you and Microsoft to collect data from users of your applications. If you use these features, you must comply with applicable law, including providing appropriate notices to users of your applications together with a copy of Microsoft’s privacy statement. Our privacy statement is located at https://go.microsoft.com/fwlink/?LinkID=824704. You can learn more about data collection and use in the help documentation and our privacy statement. Your use of the software operates as your consent to these practices.

############################################################################################
version="1.3"
hostsfilepath="/etc/hosts"


# Reset
Color_Off='\033[0m'       # Text Reset

# Regular Colors
Black='\033[0;30m'        # Black
Red='\033[0;31m'          # Red
Green='\033[0;32m'        # Green
Yellow='\033[0;33m'       # Yellow
Blue='\033[0;34m'         # Blue
Purple='\033[0;35m'       # Purple
Cyan='\033[0;36m'         # Cyan
White='\033[0;37m'        # White

############################################################################################
if [ "$(uname)" == "Darwin" ]; then
    SO="MACOS"
elif [ "$(uname)" == "Linux" ]; then
    SO="LINUX"
else
    SO="OTHER"
fi

# Get the Linux distribution name
get_distribution_name() {
    if [ -f "/etc/os-release" ]; then
        # Try to retrieve the distribution name from /etc/os-release
        distribution_name=$(grep -oP '(?<=^NAME=").*?(?=")' /etc/os-release)
        echo "$distribution_name"
        return
    fi

    if [ -f "/etc/lsb-release" ]; then
        # Try to retrieve the distribution name from /etc/lsb-release
        distribution_name=$(grep -oP '(?<=^DISTRIB_ID=).*' /etc/lsb-release | tr -d '="')
        echo "$distribution_name"
        return
    fi

    if [ -f "/etc/redhat-release" ]; then
        # If /etc/redhat-release exists, it is likely a Red Hat-based distribution
        echo "Red Hat-based"
        return
    fi

    # If no specific distribution information is found, output "Unknown"
    echo "Unknown"
}

# Get the Linux version
get_linux_version() {
    if [ -f "/etc/os-release" ]; then
        # Try to retrieve the version from /etc/os-release
        OSversion=$(grep -oP '(?<=^VERSION_ID=").*?(?=")' /etc/os-release)
        echo "$OSversion"
        return
    fi

    if [ -f "/etc/lsb-release" ]; then
        # Try to retrieve the version from /etc/lsb-release
        OSversion=$(grep -oP '(?<=^DISTRIB_RELEASE=).*' /etc/lsb-release | tr -d '="')
        echo "$OSversion"
        return
    fi

    if [ -f "/etc/redhat-release" ]; then
        # If /etc/redhat-release exists, extract the version from the file
        OSversion=$(sed -E 's/[^0-9.]//g' /etc/redhat-release)
        echo "$OSversion"
        return
    fi

    # If no specific version information is found, output "Unknown"
    echo "Unknown"
}

# Main script
distribution=$(get_distribution_name)
OSversion=$(get_linux_version)


echo -e "${Cyan}------------------------------------------------------------------------------------"
echo -e "Azure Synapse Connectivity Checker"
echo -e " - Version: $version"
echo -e " - SO: $SO"
echo -e "   - Distribution: $distribution"
echo -e "   - Version: $OSversion"
echo -e " - Workspacename: $workspacename"
echo -e "------------------------------------------------------------------------------------"
echo -e "Bash Version"
$(echo -e "bash --version")
echo -e "------------------------------------------------------------------------------------${Color_Off}"

############################################################################################
# Define the endpoints
EndpointTestList=()

declare -A Endpoints=(
    ["$workspacename.sql.azuresynapse.net"]="1433 1443 443 11000"
    ["$workspacename-ondemand.sql.azuresynapse.net"]="1433 1443 443 11000"
    ["$workspacename.database.windows.net"]="1433 1443 443 11000"
    ["$workspacename.dev.azuresynapse.net"]="443"
    ["web.azuresynapse.net"]="443"
    ["management.azure.com"]="443"
    ["login.windows.net"]="443"
    ["login.microsoftonline.com"]="443"
    ["aadcdn.msauth.net"]="443"
    ["graph.microsoft.com"]="443"
)

for Endpoint in $(echo "${!Endpoints[@]}" | tr ' ' '\n')
do
    Ports=(${Endpoints[$Endpoint]})
    EndpointTestList+=("$Endpoint ${Ports[*]}")
done

############################################################################################
logEvent() {
    Message=$1
    AnonymousRunId=$(uuidgen)

    if [[ $DisableAnonymousTelemetry != true ]]; then
        InstrumentationKey="d94ff6ec-feda-4cc9-8d0c-0a5e6049b581"
        body=$(jq -n \
            --arg name "$Message" \
            --arg time "$(date -u +'%Y-%m-%dT%H:%M:%S.%3NZ')" \
            --arg iKey "$InstrumentationKey" \
            --arg tags '{"ai.user.id": "'"$AnonymousRunId"'"}' \
            --arg baseType "EventData" \
            --arg ver 2 \
            --arg name "$Message" \
            '{name: $name, time: $time, iKey: $iKey, tags: ($tags | fromjson), data: {baseType: $baseType, baseData: {ver: $ver, name: $name}}}')

        # Wrap the curl command in a try-catch block
        if curl -s -X POST \
            -H "Content-Type: application/json" \
            -d "$body" \
            "https://dc.services.visualstudio.com/v2/track" > /dev/null; then
            echo "Anonymous telemetry sent"
        else
            echo "Failed to send telemetry: $?"
        fi
    else
        echo "Anonymous Telemetry is disabled" >&2
    fi
}

# Example usage:
message="Version: $version - Linux - $distribution"
logEvent "$message"

print_hostfileentries() {
    local hosts_file="$1"
    #sed -e 's/#.*//' -e 's/[[:blank:]]*$//' -e '/^$/d' "$hosts_file"
    sed -e 's/#.*//' -e 's/[[:blank:]]*$//' -e '/^$/d' "$hosts_file" | sed 's/^/ - /'
}


print_ip_for_endpoint() {
    local endpoint="$1"

    # Perform the nslookup
    result=$(nslookup "$endpoint")

    # Save the output to a variable
    output=$(echo "$result" | awk '/^Address: / {print $2; exit}')

    # Print the output
    echo -e " - NSLookup result : ${Blue}$output${Color_Off}"
}

print_port_status() {
    local endpoint="$1"
    local port="$2"
    local timeout=2

    # Create a new TCP client object
    tcpClient=$(nc -v -z -w "$timeout" "$endpoint" "$port" 2>&1)

    # Check if the port is open
    if [[ "$tcpClient" == *succeeded* ]] || [[ "$tcpClient" == *Connected* ]]; then
        echo -e "${Green} > Port $port on $endpoint is open${Color_Off}"
    else
        echo -e "${Red} > Port $port on $endpoint is closed${Color_Off}"
    fi
}

function print_CxDNSServer {
    # Get the DNS client server addresses from resolv.conf file
    DNSServers=$(grep -E '^nameserver' /etc/resolv.conf | awk '{print $2}')

    echo "DNSServers: $DNSServers"
}

function print_proxysettings 
{
    #need to TEST
    env | grep -i proxy
}

############################################################################################

echo "------------------------------------------------------------------------------------"
echo -e "${Yellow}HOST FILE ENTRIES${Color_Off}"
echo "------------------------------------------------------------------------------------"
print_hostfileentries "$hostsfilepath"

echo "------------------------------------------------------------------------------------"
echo -e "${Yellow}CX DNS SERVERS${Color_Off}"
echo "------------------------------------------------------------------------------------"
print_CxDNSServer

echo "------------------------------------------------------------------------------------"
echo -e "${Yellow}Proxy Settings (IF ANY):${Color_Off}"
echo -e " - NOT TESTED IN REAL LIFE"
echo "------------------------------------------------------------------------------------"
print_proxysettings


echo "------------------------------------------------------------------------------------"
echo -e "${Yellow}NAME RESOLUTION - NSLOOKUP${Color_Off}"
echo "------------------------------------------------------------------------------------"


for EndpointTest in "${EndpointTestList[@]}"
do
    Endpoint=$(echo "$EndpointTest" | cut -d ' ' -f 1)
    Ports=$(echo "$EndpointTest" | cut -d ' ' -f 2-)

    echo "------------------------------------------------------------------------------------"
    echo "Endpoint: $Endpoint and ports: $Ports"
    print_ip_for_endpoint "$Endpoint"

    for Port in $Ports
    do
        print_port_status "$Endpoint" "$Port"
    done
done

echo "------------------------------------------------------------------------------------"
