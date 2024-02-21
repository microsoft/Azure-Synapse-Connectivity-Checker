#Requires -Version 5

<#   
.NOTES     
    Author: Sergio Fonseca
    Twitter @FonsecaSergio
    Email: sergio.fonseca@microsoft.com
    Last Updated: 2024-02-21

    ## Copyright (c) Microsoft Corporation.
    #Licensed under the MIT license.

    #Fabric Test Connection

    #THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    #FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
    #WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

.SYNOPSIS   
    Check last version and documentation at https://github.com/microsoft/Azure-Synapse-Connectivity-Checker
    
    Editions
        - Synapse
            - Windows (Powershell)
            - MAC (Bash)
            - Linux (Bash)
        - Fabric
            - Windows (Powershell)
            - MAC (Bash) - TO BE DONE
            - Linux (Bash) - TO BE DONE

    
    REQUIRES
        IF want to run as script
            - Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process
        -Import-Module DnsClient
        -SQLCMD 
            - https://learn.microsoft.com/en-us/sql/tools/sqlcmd/sqlcmd-utility?view=sql-server-ver16&tabs=odbc%2Cwindows&pivots=cs1-powershell#download-and-install-sqlcmd

#> 

using namespace System.Net

# Parameter region for when script is run directly
$FabricEndpoint = "xxxx-xxxx.datawarehouse.pbidedicated.windows.net"
$AADUser = "xxxx@domain.com"
$DatabaseName = "master"

# Optional parameters (default values will be used if omitted)
$DisableAnonymousTelemetry = $true  # Set as $true if you don't want to send anonymous usage data to Microsoft
#Data Collection. The software may collect information about you and your use of the software and send it to Microsoft. Microsoft may use this information to provide services and improve our products and services. You may turn off the telemetry as described in the repository. There are also some features in the software that may enable you and Microsoft to collect data from users of your applications. If you use these features, you must comply with applicable law, including providing appropriate notices to users of your applications together with a copy of Microsoft’s privacy statement. Our privacy statement is located at https://go.microsoft.com/fwlink/?LinkID=824704. You can learn more about data collection and use in the help documentation and our privacy statement. Your use of the software operates as your consent to these practices.


# Parameter region when Invoke-Command is used
$parameters = $args[0]

if ($null -ne $parameters) {
    $FabricEndpoint = $parameters['FabricEndpoint']
    $AADUser = $parameters['AADUser']
    $DatabaseName = $parameters['DatabaseName']    
    $DisableAnonymousTelemetry = $parameters['DisableAnonymousTelemetry']
}

if([string]::IsNullOrEmpty($FabricEndpoint) -or $FabricEndpoint -eq "xxxx-xxxx.datawarehouse.pbidedicated.windows.net") 
{
    Write-Error "ERROR:: Fabric Endpoint is mandatory"
    Break
}

Clear-Host

####################################################################################################################################################
#LOG VERSIONS
New-Variable -Name VERSION -Value "1.5" -Option Constant -ErrorAction Ignore
New-Variable -Name AnonymousRunId -Value ([guid]::NewGuid()).Guid -Option Constant -ErrorAction Ignore

Write-Host ("Edition: Fabric") 
Write-Host ("Current version: " + $VERSION)
Write-Host ("PS version: " + $psVersionTable.PSVersion)
Write-Host ("PS OS version: " + $psVersionTable.OS)
Write-Host ("System.Environment OS version: " + [System.Environment]::OSVersion.Platform)
Write-Host ("FabricEndpoint: " + $FabricEndpoint)
####################################################################################################################################################




####################################################################################################################################################
#region Telemetry


<#
.SYNOPSIS
Sends a ANONYMOUS TELEMETRY event to Azure Application Insights.

.DESCRIPTION
The logEvent function sends a custom event to Azure Application Insights. The event contains a message and an anonymous run ID. If the anonymous run ID is not provided, a new GUID is generated.

.PARAMETER Message
The message to be included in the event.

.PARAMETER AnonymousRunId
The anonymous run ID to be included in the event. If not provided, a new GUID is generated.

.EXAMPLE
logEvent -Message "This is a test message" -AnonymousRunId "12345"

#>
function logEvent {
    param (
        [String]$Message,
        [String]$AnonymousRunId = ([guid]::NewGuid()).Guid
    )

    if (!$DisableAnonymousTelemetry) 
    {
        try {
            $InstrumentationKey = "d94ff6ec-feda-4cc9-8d0c-0a5e6049b581"        
            $body = New-Object PSObject `
            | Add-Member -PassThru NoteProperty name 'Microsoft.ApplicationInsights.Event' `
            | Add-Member -PassThru NoteProperty time $([System.dateTime]::UtcNow.ToString('o')) `
            | Add-Member -PassThru NoteProperty iKey $InstrumentationKey `
            | Add-Member -PassThru NoteProperty tags (New-Object PSObject | Add-Member -PassThru NoteProperty 'ai.user.id' $AnonymousRunId) `
            | Add-Member -PassThru NoteProperty data (New-Object PSObject `
                | Add-Member -PassThru NoteProperty baseType 'EventData' `
                | Add-Member -PassThru NoteProperty baseData (New-Object PSObject `
                    | Add-Member -PassThru NoteProperty ver 2 `
                    | Add-Member -PassThru NoteProperty name $Message));
            $body = $body | ConvertTo-JSON -depth 5;
            Invoke-WebRequest -Uri 'https://dc.services.visualstudio.com/v2/track' -ErrorAction SilentlyContinue -Method 'POST' -UseBasicParsing -body $body > $null
        }
        catch {
            #Do nothing
    
            #Write-Host "ERROR ($($_.Exception))"
        }                   
    }
    else {
        write-host "Anonymous Telemetry is disabled" -ForegroundColor Yellow
    }
}

$Message = "Edition: Fabric - Version: " + $VERSION + " - SO: Windows"
logEvent -Message $Message -AnonymousRunId $AnonymousRunId

####################################################################################################################################################
<#
.SYNOPSIS
Sends a ANONYMOUS TELEMETRY event to Azure Application Insights.

.DESCRIPTION
The logEvent function sends a custom event to Azure Application Insights. The event contains a message and an anonymous run ID. If the anonymous run ID is not provided, a new GUID is generated.

.PARAMETER Message
The message to be included in the event.

.PARAMETER AnonymousRunId
The anonymous run ID to be included in the event. If not provided, a new GUID is generated.

.EXAMPLE
logEvent -Message "This is a test message" -AnonymousRunId "12345"

#>

#NEED TO BE DONE
function logException
{
    param (
        [String]$Message,
        [String]$AnonymousRunId = ([guid]::NewGuid()).Guid
    )
    try {
        $InstrumentationKey = "d94ff6ec-feda-4cc9-8d0c-0a5e6049b581"        
        $body = New-Object PSObject `
        | Add-Member -PassThru NoteProperty name 'Microsoft.ApplicationInsights.Event' `
        | Add-Member -PassThru NoteProperty time $([System.dateTime]::UtcNow.ToString('o')) `
        | Add-Member -PassThru NoteProperty iKey $InstrumentationKey `
        | Add-Member -PassThru NoteProperty tags (New-Object PSObject | Add-Member -PassThru NoteProperty 'ai.user.id' $AnonymousRunId) `
        | Add-Member -PassThru NoteProperty data (New-Object PSObject `
            | Add-Member -PassThru NoteProperty baseType 'EventData' `
            | Add-Member -PassThru NoteProperty baseData (New-Object PSObject `
                | Add-Member -PassThru NoteProperty ver 2 `
                | Add-Member -PassThru NoteProperty name $Message));
        $body = $body | ConvertTo-JSON -depth 5;
        Invoke-WebRequest -Uri 'https://dc.services.visualstudio.com/v2/track' -ErrorAction SilentlyContinue -Method 'POST' -UseBasicParsing -body $body > $null
    }
    catch {
        #Do nothing

        #Write-Host "ERROR ($($_.Exception))"
    }        
}

#endregion Telemetry

####################################################################################################################################################
#CHECK IF MACHINE IS WINDOWS
<#
.SYNOPSIS
    Tests the connection on Windows machines.

.DESCRIPTION
    This function tests the connection on Windows machines by checking the operating system version. If the operating system is not Windows, it will throw an error and exit the function.

.PARAMETER None

.EXAMPLE
    Test-ConnectionOnWindows
#>
function Test-ConnectionOnWindows {
    [String]$OS = [System.Environment]::OSVersion.Platform
    Write-Host "SO: $($OS)"

    if (-not(($OS.Contains("Win"))))
    {
        Write-Error "Only can be used on Windows Machines"
        Break
    }
}
Test-ConnectionOnWindows

####################################################################################################################################################
# Check if the DnsClient module is available and import it if it is not
if (-not(Get-Module -Name DnsClient -ListAvailable)) {
    try {
        Import-Module DnsClient -ErrorAction Stop
    }
    catch {
        Write-Host "   - ERROR::Import-Module DnsClient"  -ForegroundColor Red
        Write-Host "     - $($_.Exception.Message)" -ForegroundColor Red
    }
}


####################################################################################################################################################
#region OTHER PARAMETERS / CONSTANTS

New-Variable -Name TestPortConnectionTimeoutMs -Value 1000 -Option Constant -ErrorAction Ignore
New-Variable -Name SQLConnectionTimeout -Value 15 -Option Constant -ErrorAction Ignore
New-Variable -Name SQLQueryTimeout -Value 15 -Option Constant -ErrorAction Ignore
New-Variable -Name HostsFile -Value "$env:SystemDrive\Windows\System32\Drivers\etc\hosts" -Option Constant -ErrorAction Ignore

#endregion OTHER PARAMETERS / CONSTANTS
$Summary = New-Object System.Text.StringBuilder




####################################################################################################################################################
#region Class

#----------------------------------------------------------------------------------------------------------------------
Class Port
{
    [int]$Port
    [string]$Result = "NOT TESTED"

    Port () {}
    Port ([string]$PortInput) {$this.Port = $PortInput}
}

#----------------------------------------------------------------------------------------------------------------------
Class Endpoint
{
    [String]$Name
    [Port[]]$PortsNeeded
 
    Endpoint () {}
    Endpoint ([string]$Name, [Port[]]$PortsNeeded) 
    {
        $this.Name = $Name
        $this.PortsNeeded = $PortsNeeded
    }

    Endpoint ([string]$Name, [int[]]$PortsNeeded) 
    {
        $this.Name = $Name
        $this.PortsNeeded = $PortsNeeded
    }
}

#----------------------------------------------------------------------------------------------------------------------
Class EndpointTest
{
    [Endpoint]$Endpoint
    [String]$CXResolvedIP
    [String]$CXHostFileIP
    [String]$CXResolvedCNAME

    [bool]$isAnyPortClosed = $false

    EndpointTest () {}
    EndpointTest ([Endpoint]$EndpointToBeTested) 
    {
        $this.Endpoint = $EndpointToBeTested
    }

    #----------------------------------------------------------------------------------------------------------------------
    [void] Resolve_DnsName_CXDNS ()
    {
        try 
        {
            $DNSResults = (Resolve-DnsName -Name $this.Endpoint.Name -DnsOnly -Type A -QuickTimeout -ErrorAction Stop)
            $this.CXResolvedIP = @($DNSResults.IP4Address)[0]
            if ($DNSResults.NameHost.Count -gt 0 -and $null -ne $this.CXResolvedIP -and $this.CXResolvedIP -ne "") 
            {
                $this.CXResolvedCNAME = @($DNSResults.NameHost)[$DNSResults.NameHost.Count - 1]
            }
        }
        catch 
        {
            Write-Host "   - ERROR:: Trying to resolve DNS for $($this.Endpoint.Name) from Customer DNS" -ForegroundColor DarkGray
            Write-Host "     - $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    #----------------------------------------------------------------------------------------------------------------------
    #https://copdips.com/2019/09/fast-tcp-port-check-in-powershell.html
    [void] Test_Ports ([Int]$Timeout = 1000)
    {
        $IPtoTest = $this.CXResolvedIP

        #Check what IP will be used for test
        if($null -ne $this.CXHostFileIP -and $this.CXHostFileIP -ne "")
        {
            $IPtoTest = $this.CXHostFileIP
        } 

        # Loop through each port needed by the endpoint
        foreach ($Port in $this.Endpoint.PortsNeeded)
        {
            try 
            {
                # Create a new TCP client object
                $tcpClient = New-Object System.Net.Sockets.TcpClient

                # Check if the CX endpoint IP address has been resolved
                if($null -eq $IPtoTest -or $IPtoTest -eq "")
                {                    
                    # If the IP address is not valid, set the result to "NOT VALID IP - NAME NOT RESOLVED"
                    #Write-Host " -INFO:: NOT Testing Port / IP NOT VALID - $($this.Endpoint.Name) / IP($($this.CXResolvedIP)):PORT($($Port.Port))" -ForegroundColor Yellow
                    $Port.Result = "CANNOT RESOLVE NAME - DNS ISSUE"
                }
                else
                {
                    $portOpened = $false

                    # Attempt to connect to the port asynchronously
                    $portOpened = $tcpClient.ConnectAsync($IPtoTest, $Port.Port).Wait($Timeout)

                    # If the port is open, set the result to "CONNECTED"
                    if($portOpened -eq $true) {
                        $Port.Result = "CONNECTED"
                    }
                    # If the port is closed, set the result to "CLOSED"
                    else{
                        $Port.Result = "CLOSED"
                    }                   
                } 


                # Close the TCP client object
                $tcpClient.Close()
            }
            catch 
            {
                # If an error occurs, set the result to "CLOSED"
                $Port.Result = "CLOSED"
                Write-Host " -ERROR:: Testing Port $($this.Endpoint.Name) / IP($($IPtoTest)):PORT($($Port.Port))" -ForegroundColor DarkGray

                # Check if the error is due to a non-existent host
                if ($null -ne $_.Exception.InnerException.InnerException)
                {
                    if ($_.Exception.InnerException.InnerException.ErrorCode -eq 11001) { #11001 No such host is known                        
                        Write-Host "  -ERROR:: Test-Port: ($($this.Endpoint.Name) / $($IPtoTest) : $($Port.Port)) - $($_.Exception.InnerException.InnerException.Message)" -ForegroundColor Red
                    }
                }
                else {
                    Write-Host "  -ERROR:: Test-Port: $($_.Exception.Message)" -ForegroundColor Red
                }                
            }          
        }
    }

    #----------------------------------------------------------------------------------------------------------------------
    [void] PrintTest_Endpoint ($HostsFileEntries) 
    {
        # Print the DNS information for the endpoint
        Write-Host "   ----------------------------------------------------------------------------"
        Write-Host "   - DNS for ($($this.Endpoint.Name))"
        Write-Host "      - CX DNS:($($this.CXResolvedIP)) / NAME:($($this.CXResolvedCNAME))"

        $HostsFileEntry = $null
        $_HaveHostsFileEntry = $false

        # Check if the endpoint has an entry in the hosts file
        if ($HostsFileEntries.Count -gt 0) {
            foreach ($HostsFileEntry in $HostsFileEntries)
            {
                if ($HostsFileEntry.HOST -eq $this.Endpoint.Name) {
                    $_HaveHostsFileEntry = $true
                    Write-Host "      - CX HOST FILE:($($HostsFileEntry.IP)) / NAME:($($HostsFileEntry.HOST))" -ForegroundColor Red
                    break
                }    
            }     
        }

        if ($_HaveHostsFileEntry)
        {# HAVE HOST FILE ENTRY           
            if ($HostsFileEntry.IP -ne $this.PublicIP) 
            { 
                #Write-Host "      - INFO:: VM HOST FILE ENTRY AND PUBLIC DNS ARE NOT SAME" -ForegroundColor Yellow 
            }

            Write-Host "      - INFO:: ENDPOINT FIXED ON HOSTS FILE" -ForegroundColor Yellow
        }
        else
        {# DOES NOT HAVE HOST FILE ENTRY
            if ($null -eq $this.CXResolvedIP) 
            { 
                # If the CX resolved IP is null, log an error message to the console
                Write-Host "      - ERROR:: CX NAME RESOLUTION DIDN'T WORK" -ForegroundColor Red 
            }
            else 
            {
                # Check if the CX endpoint is using a public or private endpoint
                if (
                    $this.CXResolvedCNAME -like "*.cloudapp.*" -or `
                    $this.CXResolvedCNAME -like "*.control.*" -or `
                    $this.CXResolvedCNAME -like "*.trafficmanager.net*" -or `
                    $this.CXResolvedCNAME -like "*msedge.net" -or `
                    $this.CXResolvedCNAME -like "*.akadns.net"
                    ) 
                { 
                    Write-Host "      - INFO:: CX USING PUBLIC ENDPOINT" -ForegroundColor Cyan 
                }
                elseif ($this.CXResolvedCNAME -like "*.privatelink.*") 
                { 
                    Write-Host "      - INFO:: CX USING PRIVATE ENDPOINT" -ForegroundColor Yellow 
                }                   
            } 
        }
    }

    #----------------------------------------------------------------------------------------------------------------------
    [void] PrintTest_Ports ()
    {
        if ($null -eq $this.CXHostFileIP -or $this.CXHostFileIP -eq "")
        {
            Write-host "    - TESTS FOR ENDPOINT - $($this.Endpoint.Name) - CX DNS IP ($($this.CXResolvedIP))"
        }
        else
        {
            Write-host "    - TESTS FOR ENDPOINT - $($this.Endpoint.Name) - CX HOSTFILE IP ($($this.CXHostFileIP))"
        }

        foreach ($Port in $this.Endpoint.PortsNeeded)
        {
            if($Port.Result -eq "CONNECTED")
                {
                    Write-host "      - PORT $(($Port.Port).ToString().PadRight(4," ")) - RESULT: $($Port.Result)"  -ForegroundColor Green 
                }
            elseif($Port.Result -eq "CLOSED" -or $Port.Result -contains "NOT VALID IP")
                { 
                    $this.isAnyPortClosed = $true;
                    Write-host "      - PORT $(($Port.Port).ToString().PadRight(4," ")) - RESULT: $($Port.Result)"  -ForegroundColor Red
                }
            else
                {
                    $this.isAnyPortClosed = $true; 
                    Write-host "      - PORT $(($Port.Port).ToString().PadRight(4," ")) - RESULT: $($Port.Result)"  -ForegroundColor Yellow
                }
        }       
    }
}

#endregion Class



####################################################################################################################################################
#region Endpoints to be tested

$EndpointTestList = @()

$Endpoints = [ordered]@{
    "$($FabricEndpoint)" = @(1433)
    "login.windows.net" = @(443)
    "login.microsoftonline.com" = @(443)
    "aadcdn.msauth.net" = @(443)
    "graph.microsoft.com" = @(443)
}

foreach ($Endpoint in $Endpoints.Keys) 
{
    $Ports = $Endpoints[$Endpoint]
    $EndpointTestList += [EndpointTest]::new([Endpoint]::new($Endpoint, @($Ports)))
}

#endregion Endpoints to be tested



####################################################################################################################################################
Write-Host "------------------------------------------------------------------------------" -ForegroundColor Yellow
Write-Host "COLLECTING DATA" -ForegroundColor Yellow
Write-Host "------------------------------------------------------------------------------" -ForegroundColor Yellow

####################################################################################################################################################
#region - HostsFile

#----------------------------------------------------------------------------------------------------------------------
<#
.SYNOPSIS
Reads the hosts file and returns the IP and Host entries as custom objects.

.DESCRIPTION
This function reads the hosts file and returns the IP and Host entries as custom objects. It uses a regular expression pattern to match IP and Host entries in the hosts file.

.PARAMETER None

.INPUTS
None

.OUTPUTS
Custom objects with the IP and Host properties.

.EXAMPLE
Get-HostsFilesEntries

This command reads the hosts file and returns the IP and Host entries as custom objects.
#>
function Get-HostsFilesEntries 
{
    try {
        # This regular expression pattern matches IP and Host entries in the hosts file
        $Pattern = '^(?<IP>\d{1,3}(\.\d{1,3}){3})\s+(?<Host>.+)$'

        # Read the hosts file and parse each line using a regular expression
        Get-Content -Path $HostsFile | ForEach-Object {
            if ($_ -match $Pattern) {
                # Create a custom object with the IP and Host properties
                [PSCustomObject]@{
                    IP = $Matches.IP
                    Host = $Matches.Host
                }
            }
        }
    }
    catch {
        # Handle any errors that occur during the execution of the function
        Write-Host "   - ERROR:: Get-HostsFilesEntries" -ForegroundColor Red
        Write-Host "     - $($_.Exception.Message)" -ForegroundColor Red   
    }
}

$HostsFileEntries = @(Get-HostsFilesEntries)

#----------------------------------------------------------------------------------------------------------------------
<#
.SYNOPSIS
Retrieves the DNS server addresses from the local machine.

.DESCRIPTION
This function retrieves the DNS server addresses from the local machine. It first calls the `Get-DnsClientServerAddress` cmdlet to get the DNS client server addresses. It then filters out loopback and Bluetooth interfaces, as well as empty server addresses. It selects unique server addresses and expands the property. Finally, it returns the DNS server addresses.

.PARAMETER None
This function does not accept any parameters.

.EXAMPLE
PS C:\> Get-DnsCxServerAddresses
Returns a list of DNS server addresses from the local machine.

#>
function Get-DnsCxServerAddresses 
{   
    try {
        # Get the DNS client server addresses
        $DNSServers = Get-DnsClientServerAddress -ErrorAction Stop

        # Filter out loopback and Bluetooth interfaces, and empty server addresses
        $DNSServers = $DNSServers | Where-Object {
            (!($_.InterfaceAlias).contains("Loopback")) -and 
            (!($_.InterfaceAlias).contains("Bluetooth")) -and
            ("" -ne $_.ServerAddresses)
        }

        # Select unique server addresses and expand the property
        $DNSServers = $DNSServers | Select-Object -Unique ServerAddresses -ExpandProperty ServerAddresses
    
        # Return the DNS server addresses
        return @($DNSServers)
    }
    catch {
        # If an error occurs, write an error message to the console
        Write-Host "   - ERROR:: Get-DnsCxServerAddresses" -ForegroundColor Red
        Write-Host "     - $($_.Exception.Message)" -ForegroundColor Red
    }
}

$DnsCxServerAddresses = Get-DnsCxServerAddresses
#Get-DnsClientServerAddress | Where-Object ServerAddresses

#----------------------------------------------------------------------------------------------------------------------
# Test name resolution against CX DNS
foreach ($EndpointTest in $EndpointTestList)
{
    $EndpointTest.Resolve_DnsName_CXDNS()
}

#----------------------------------------------------------------------------------------------------------------------
# Checking Ports
foreach ($EndpointTest in $EndpointTestList)
{
    $EndpointTest.Test_Ports($TestPortConnectionTimeoutMs)
}





####################################################################################################################################################
# RESULTS
####################################################################################################################################################
Write-Host "------------------------------------------------------------------------------" -ForegroundColor Yellow
Write-Host "RESULTS " -ForegroundColor Yellow
Write-Host "------------------------------------------------------------------------------" -ForegroundColor Yellow

####################################################################################################################################################
#region RESULTS - HOSTS FILE

function printHostsFileEntries 
{
    Write-Host "  ----------------------------------------------------------------------------"
    Write-Host "  HOSTS FILE [$($HostsFile)]"
    
    if ($HostsFileEntries.Count -gt 0) {
        foreach ($HostsFileEntry in $HostsFileEntries)
        {
            $isFoundOnList = $false
    
            #Write-Host "HostsFileEntry = $($HostsFileEntry)"
            foreach ($EndpointTest in $EndpointTestList)
            {
                #Write-Host "EndpointTest = $($EndpointTest.Endpoint.Name)"
                
                if ($HostsFileEntry.HOST.Contains($EndpointTest.Endpoint.Name)) 
                {
                    Write-Host "   - IP [$($HostsFileEntry.IP)] / NAME [$($HostsFileEntry.HOST)]" -ForegroundColor Red    
                    $isFoundOnList = $true
    
                    #Document the IP found on the HostsFile
                    $EndpointTestList[$EndpointTestList.IndexOf($EndpointTest)].CXHostFileIP = ($HostsFileEntry.IP)
                }
            }
            if ($isFoundOnList -eq $false)
            {
                Write-Host "   - IP [$($HostsFileEntry.IP)] / NAME [$($HostsFileEntry.HOST)]"
            }
        }     
    }
    else {
        Write-Host "   - NO RELATED ENTRY" -ForegroundColor Green
    }   
}

printHostsFileEntries

#endregion RESULTS - HOSTS FILE

####################################################################################################################################################
#region RESULTS - DNS SERVERS

function printDNSServers 
{
    Write-Host "  ----------------------------------------------------------------------------"
    Write-Host "  DNS SERVERS"
    foreach ($DnsCxServerAddress in $DnsCxServerAddresses)
    {
        #https://docs.microsoft.com/en-us/azure/virtual-network/what-is-ip-address-168-63-129-16
        if ($DnsCxServerAddress -eq "168.63.129.16") {
            Write-Host "   - DNS [$($DnsCxServerAddress)] AZURE DNS" -ForegroundColor Cyan
        }
        else {
            Write-Host "   - DNS [$($DnsCxServerAddress)] CUSTOM" -ForegroundColor Cyan
        } 
           
    }
    Write-Host "  ----------------------------------------------------------------------------"
    Get-DnsClientServerAddress | Where-Object ServerAddresses
    Write-Host "  ----------------------------------------------------------------------------"
        
}

printDNSServers 

#endregion RESULTS - DNS SERVERS

####################################################################################################################################################
#region RESULTS - PROXY SETTINGS
Write-Host "  ----------------------------------------------------------------------------"
Write-Host "  Computer Internet Settings - LOOK FOR PROXY SETTINGS"

<#
.SYNOPSIS
Retrieves and displays the browser proxy settings for the current user.

.DESCRIPTION
This function retrieves and displays the Internet Explorer proxy settings from the registry for the current user. It displays an info message if there is no proxy enabled and no auto-config URL, a warning message with the proxy server and exceptions if a proxy is enabled, and a warning message with the auto-config URL if there is one. If there is an error retrieving the settings, it displays an error message with the exception message.

.EXAMPLE
Get-BrowserProxySettings

#>
function Get-BrowserProxySettings 
{
    try {
        # Retrieve the Internet Explorer settings from the registry
        $IESettings = Get-ItemProperty -Path "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -ErrorAction Stop

        # If there is no proxy enabled and no auto-config URL, display an info message
        if (($IESettings.ProxyEnable -eq 0) -and ($null -eq $IESettings.AutoConfigURL)) 
        {
            Write-Host "   - INFO:: NO INTERNET PROXY ON SERVER / BROWSER" -ForegroundColor Green
        }

        # If a proxy is enabled, display a warning message with the proxy server and exceptions
        if ($IESettings.ProxyEnable -eq 1)
        {
            Write-Host "   - WARN:: PROXY ENABLED ON SERVER $($IESettings.ProxyServer)" -ForegroundColor Red
            Write-Host "   - WARN:: PROXY EXCEPTIONS $($IESettings.ProxyOverride)" -ForegroundColor Red

            [void]$Summary.AppendLine(">>----------------------------------------------------------------------------")
            [void]$Summary.AppendLine(">> - ALERT(ID08)::PROXY ENABLED ON SERVER $($IESettings.ProxyServer)'")
            [void]$Summary.AppendLine(">>   - When Client have proxy does not matter name resolution and port. Connection is done IN the PROXY SERVER")
            [void]$Summary.AppendLine(">>----------------------------------------------------------------------------")
            [void]$Summary.AppendLine("")   

        }    

        # If there is an auto-config URL, display a warning message with the URL
        if ($null -ne $IESettings.AutoConfigURL)
        {
            Write-Host "   - WARN:: PROXY SCRIPT $($IESettings.AutoConfigURL)" -ForegroundColor Red

            [void]$Summary.AppendLine(">>----------------------------------------------------------------------------")
            [void]$Summary.AppendLine(">> - ALERT(ID09)::PROXY SCRIPT $($IESettings.AutoConfigURL)'")
            [void]$Summary.AppendLine(">>   - When Client have proxy does not matter name resolution and port. Connection is done IN the PROXY SERVER")
            [void]$Summary.AppendLine(">>----------------------------------------------------------------------------")
            [void]$Summary.AppendLine("")   

        }

        Write-Host "   - Additional method to get proxy setting" -ForegroundColor Yellow
        netsh winhttp show proxy -ErrorAction Stop

    }
    catch {
        # If there is an error retrieving the settings, display an error message with the exception message
        Write-Host "   - ERROR:: Not able to check Proxy settings" -ForegroundColor Red
        Write-Host "     - $($_.Exception.Message)" -ForegroundColor Red
    }
}

Get-BrowserProxySettings



####################################################################################################################################################
<#
.SYNOPSIS
Retrieves and displays the SHIR proxy settings.

.DESCRIPTION
This function retrieves the SHIR (Self-Hosted Integration Runtime) proxy settings by searching the Integration Runtime event log for the most recent 15 instances of event ID 26 with a message containing "Http Proxy is set to". It then displays the results in the console.

.PARAMETER None
This function does not accept any parameters.

.EXAMPLE
Get-SHIRProxySettings
#>
function Get-SHIRProxySettings 
{
    try {
        $ProxyEvents = Get-EventLog `
            -LogName "Integration Runtime" `
            -InstanceId "26" `
            -Message "Http Proxy is set to*" `
            -Newest 15 `
            -ErrorAction Stop

        Write-Host "  ----------------------------------------------------------------------------"
        Write-Host "  SHIR Proxy Settings" 
            $ProxyEvents | Select-Object TimeGenerated, Message


    }
    Catch [Exception]
    {
        #DO NOTHING, BELOW JUST DEBUG

        <#
        $theError = $_
        
        Switch($theError.Exception.GetType().FullName)
        {
            System.Management.Automation.CmdletInvocationException
            {
                Write-Host "   - WARN:: NOT A PROBLEM IF NOT Self Hosted IR Machine" -ForegroundColor Yellow
                Write-Host "     - $($theError)" -ForegroundColor DarkGray
            }        
            default{
                Write-Host "   - ERROR:: ($($theError.Exception.GetType().FullName)) - NOT A PROBLEM IF NOT Self Hosted IR Machine" -ForegroundColor Yellow
                Write-Host "     - $($theError)" -ForegroundColor Yellow      
            }
        }
        #>
    }
}

Get-SHIRProxySettings

Write-Host "  ----------------------------------------------------------------------------"
#endregion RESULTS - PROXY SETTINGS

####################################################################################################################################################
#region RESULTS - NAME RESOLUTIONS

Write-Host "  ----------------------------------------------------------------------------"
Write-Host "  NAME RESOLUTION "

foreach ($EndpointTest in $EndpointTestList)
{
    $EndpointTest.PrintTest_Endpoint($HostsFileEntries)
}

#endregion RESULTS - NAME RESOLUTIONS

####################################################################################################################################################
#region RESULTS - PORTS OPEN

Write-Host "  ----------------------------------------------------------------------------"
Write-Host "  PORTS OPEN (Used CX DNS or Host File entry listed above)"

$isAnyPortClosed = $false
foreach ($EndpointTest in $EndpointTestList)
{
    $EndpointTest.PrintTest_Ports()

    if ($EndpointTest.isAnyPortClosed) 
        { $isAnyPortClosed = $true }
}

if ($isAnyPortClosed) {
    [void]$Summary.AppendLine(">>----------------------------------------------------------------------------")
    [void]$Summary.AppendLine(">> - ERROR(ID06):: IF ANY PORT IS CLOSED NEED TO MAKE SURE YOUR CLIENT SIDE FIREWALL IS OPEN")
    [void]$Summary.AppendLine("")
    [void]$Summary.AppendLine(">>CHECK")
    [void]$Summary.AppendLine(">> - https://learn.microsoft.com/en-us/fabric/data-warehouse/connectivity#authentication-to-warehouses-in-fabric")
    [void]$Summary.AppendLine(">>")
    [void]$Summary.AppendLine(">>CAN ALSO TEST MANUALLY LIKE BELOW")
    [void]$Summary.AppendLine(">> NAME RESOLUTION")
    [void]$Summary.AppendLine(">> - NSLOOKUP xxxx-xxxx.datawarehouse.pbidedicated.windows.net")
    [void]$Summary.AppendLine(">> PORT IS OPEN")
    [void]$Summary.AppendLine(">> - Test-NetConnection -Port 1433 -ComputerName xxxx-xxxx.datawarehouse.pbidedicated.windows.net")
    [void]$Summary.AppendLine(">>----------------------------------------------------------------------------")
    [void]$Summary.AppendLine("")

}


#endregion RESULTS - PORTS OPEN



####################################################################################################################################################
Write-Host "------------------------------------------------------------------------------" -ForegroundColor Yellow
Write-Host "TEST API CALLs" -ForegroundColor Yellow
Write-Host "------------------------------------------------------------------------------" -ForegroundColor Yellow

####################################################################################################################################################
<#
.SYNOPSIS
Tests a SQL connection to a specified server.

.DESCRIPTION
Tests a SQL connection to a specified server using either a SQL token or a SQL user and password.

 Will test connectiong depending on auth method choosen
  - Integrated Auth - Will use current user $IntegratedAuth = $true
  - SQL User + Password - Will use $SQL_user and $SQL_password
  - SQL Token - Will use $SQL_token

.PARAMETER ServerName
The name of the SQL server to test the connection to.

.PARAMETER DatabaseName
The name of the database to connect to. Default is "master".

.PARAMETER AADUser
Set to use AAD auth, Ex user@domain.com. Default is $null.

.PARAMETER SQL_token
The SQL token to use for authentication. If not provided, a SQL user and password will be used.

.PARAMETER SQL_user
The SQL user to use for authentication. Default is "SynapseConnectivityCheckerScript".

.PARAMETER SQL_password
The SQL password to use for authentication. Default is "SynapseConnectivityCheckerScript123".

.PARAMETER SQLConnectionTimeout
The timeout for the SQL connection in seconds. Default is 15.

.PARAMETER SQLQueryTimeout
The timeout for the SQL query in seconds. Default is 15.

.EXAMPLE
TestSQLConnection -ServerName "localhost" -DatabaseName "master" -SQL_user "myuser" -SQL_password "mypassword"

.NOTES
#>
function TestSQLConnection 
{
    param (
        [string]$ServerName,
        [string]$DatabaseName="master",
        [string]$AADUser=$null,
        [string]$SQL_token=$null,
        [string]$SQL_user="SynapseConnectivityCheckerScript",
        [string]$SQL_password="SynapseConnectivityCheckerScript123",
        [int]$SQLConnectionTimeout = 15,
        [int]$SQLQueryTimeout = 15
    )
    
    $Query = "
    SET NOCOUNT ON
    BEGIN TRY
        EXEC('SELECT TOP 1 connection_id, GETUTCDATE() as DATE 
        FROM sys.dm_exec_connections 
        WHERE session_id = @@SPID')
    END TRY
    BEGIN CATCH
        IF (ERROR_MESSAGE()= 'Catalog view ''dm_exec_connections'' is not supported in this version.')
        BEGIN
            BEGIN TRY
                EXEC('SELECT TOP 1 SESSION_ID() connection_id, GETUTCDATE() as DATE 
                FROM sys.dm_pdw_exec_connections 
                WHERE session_id = SESSION_ID()')
            END TRY
            BEGIN CATCH
                THROW
            END CATCH
        END
        ELSE
        BEGIN
            THROW
        END
    END CATCH"
    
    ####################################################################################################################################################
    # Check if SQLCMD is installed and version
    ####################################################################################################################################################
    try 
    {
        $output = sqlcmd -?

        if ($output -like "*SQL Server Command Line Tool*") 
        {
            $versionLine = $output | Select-String -Pattern "Version"
            $SQLCMDversion = $versionLine -replace "Version", "" -replace " ", ""
            Write-Host "   - INFO:: SQLCMD is installed. Version: $($SQLCMDversion)" -ForegroundColor Cyan

            #Check if version is 13.1 or higher
            #  https://learn.microsoft.com/en-us/sql/tools/sqlcmd/sqlcmd-utility?view=sql-server-ver16&tabs=odbc%2Cwindows&pivots=cs1-powershell#-g-1
            #    The -G option requires at least sqlcmd version 13.1
            #  https://learn.microsoft.com/en-us/azure/azure-sql/database/authentication-aad-overview?view=azuresql#additional-considerations
            #    Beginning with version 15.0.1, sqlcmd utility and bcp utility support Active Directory Interactive authentication with multifactor authentication.

            $MinSQLCMDversion = "15.0.1"
            $minVersion = New-Object System.Version($MinSQLCMDversion)
            $currentVersion = New-Object System.Version($SQLCMDversion -replace "[^0-9.]", "") #Remove all non numeric characters
            
            if ($currentVersion -lt $minVersion) {
                Write-Host "    - ERROR:: Current SQLCMD version ($($currentVersion)) is less than the minimum required version ($($minVersion))" -ForegroundColor Red
                throw "Current SQLCMD version ($($currentVersion)) is less than the minimum required version ($($minVersion))"
            } else {
                Write-Host "    - INFO:: Current SQLCMD version ($($currentVersion)) meets the minimum required version ($($minVersion))" -ForegroundColor Cyan
            }
        }
        else {
            Write-Host "   - ERROR:: SQLCMD is not installed."  -ForegroundColor Red
            Write-Host "   - ERROR::  - Download and install sqlcmd - https://learn.microsoft.com/en-us/sql/tools/sqlcmd/sqlcmd-utility?view=sql-server-ver16&tabs=odbc%2Cwindows&pivots=cs1-powershell#download-and-install-sqlcmd"  -ForegroundColor Red       
            throw "SQLCMD is not installed."
        }
    } catch {
        $theError = $_
        Write-Host "   - ERROR:: TestSQLConnection:: ($($theError.Exception.GetType().FullName))" -ForegroundColor Red
        Write-Host "   - ERROR:: TestSQLConnection:: ($($theError)" -ForegroundColor Red
        throw $theError
    }
    ####################################################################################################################################################

    $maxRetries = 3
    $retryCount = 0
    $retryDelay = 5 # seconds


    Try
    {
        # Will test connectiong depending on auth method choosen
        # Integrated Auth - Will use user $AADUser to do interactive login
        # SQL User + Password - Will use $SQL_user and $SQL_password
        # SQL Token - Will use $SQL_token

        if ($null -ne $AADUser) #Integrated Auth
        {
            Write-Host "   - WARN:: Interactive user logon for ($($AADUser))"  -ForegroundColor Yellow

            do {
                try {                    
                    $result = sqlcmd -S $ServerName -d $DatabaseName -Q $Query -l $SQLConnectionTimeout -t $SQLQueryTimeout -G -U $AADUser 2>&1

                    if ($LASTEXITCODE -eq 0) {
                        write-host "   - SUCESS :: " -ForegroundColor Green
                        
                        foreach ($resultline in $result)
                        {
                            write-host "     > $($resultline)" -ForegroundColor Green
                        }
                    }
                    else {
                        write-host "   - ERROR - Exit code ($($LASTEXITCODE)):: " -ForegroundColor Red
                        foreach ($resultline in $result)
                        {
                            write-host "     > $($resultline)" -ForegroundColor Red
                        }

                        [void]$Summary.AppendLine(">>----------------------------------------------------------------------------")
                        [void]$Summary.AppendLine(">> - ERROR(ID08):: Connection failed using SQLCMD to Server ($($ServerName)) using AAD User ($($AADUser))")
                        foreach ($resultline in $result)
                        {
                            [void]$Summary.AppendLine("        > $($resultline)")
                        }
                        [void]$Summary.AppendLine(">>   - CHECK")                        
                        [void]$Summary.AppendLine(">>     - https://learn.microsoft.com/en-us/fabric/data-warehouse/connectivity#authentication-to-warehouses-in-fabric")
                        [void]$Summary.AppendLine(">>     - https://learn.microsoft.com/en-us/fabric/data-warehouse/troubleshoot-synapse-data-warehouse#transient-connection-errors")
                        [void]$Summary.AppendLine(">>     - https://support.fabric.microsoft.com/pt-PT/support/")
                        [void]$Summary.AppendLine(">>     - https://support.fabric.microsoft.com/en-US/known-issues//")
                        [void]$Summary.AppendLine(">>----------------------------------------------------------------------------")
                        
                    }

                    break # exit the loop if the command succeeds
                } catch {

                    $retryCount++
                    if ($retryCount -lt $maxRetries) {
                        Write-Host "Retrying in $retryDelay seconds..."
                        Start-Sleep -Seconds $retryDelay
                    } else {
                        Write-Host "Maximum retries reached. Aborting."
                        throw # re-throw the exception if the maximum retries are reached
                    }
                }
            } while ($retryCount -lt $maxRetries)
        }

        <#
        elseif ( ($null -eq $SQL_token) -or ("" -eq $SQL_token)) #SQL User + Password
        {
            Write-Host "   - WARN:: SQL TOKEN NOT VALID. TESTING CONNECTION WITH FAKE SQL USER + PASSWORD, it will fail but we can check if can reach server"  -ForegroundColor Yellow
            
            do {
                try {
                    $result = Invoke-Sqlcmd `
                        -ServerInstance $ServerName `
                        -Database $DatabaseName `
                        -Username $SQL_user `
                        -Password $SQL_password `
                        -Query $Query `
                        -ConnectionTimeout $SQLConnectionTimeout `
                        -QueryTimeout $SQLQueryTimeout `
                        -ErrorAction Stop

                    Write-Host "   - SUCESS:: Connection connection_id($($result.connection_id)) / UTC date($($result.DATE))" -ForegroundColor Green
                    break # exit the loop if the command succeeds
                } catch {

                    $retryCount++
                    if ($retryCount -lt $maxRetries) {
                        Write-Host "Retrying in $retryDelay seconds..."
                        Start-Sleep -Seconds $retryDelay
                    } else {
                        Write-Host "Maximum retries reached. Aborting."
                        throw # re-throw the exception if the maximum retries are reached
                    }
                }
            } while ($retryCount -lt $maxRetries)
            
        }
        else #SQL Token
        {
            do {
                try {
                    $result = Invoke-Sqlcmd `
                        -ServerInstance $ServerName `
                        -Database $DatabaseName `
                        -AccessToken $SQL_token `
                        -Query $Query `
                        -ConnectionTimeout $SQLConnectionTimeout `
                        -QueryTimeout $SQLQueryTimeout `
                        -ErrorAction Stop

                    Write-Host "   - SUCESS:: Connection connection_id($($result.connection_id)) / UTC date($($result.DATE))" -ForegroundColor Green
                    break # exit the loop if the command succeeds
                } catch {

                    $retryCount++
                    if ($retryCount -lt $maxRetries) {
                        Write-Host "Retrying in $retryDelay seconds..."
                        Start-Sleep -Seconds $retryDelay
                    } else {
                        Write-Host "Maximum retries reached. Aborting."
                        throw # re-throw the exception if the maximum retries are reached
                    }
                }
            } while ($retryCount -lt $maxRetries)
            
        }
        #>
    }
    Catch [Exception]
    {
        $theError = $_

        Switch($theError.Exception.GetType().FullName)
        {
            System.Management.Automation.ValidationMetadataException
            {
                Write-Host "   - ERROR:: ($($theError.Exception.GetType().FullName)):: TEST SQL ($($ServerName)) ENDPOINT" -ForegroundColor Red
                $theError
            }
            System.Data.SqlClient.SqlException
            {
                Write-Host "   - ERROR:: ($($theError.Exception.GetType().FullName)):: TEST SQL ($($ServerName)) ENDPOINT"  -ForegroundColor Red
                Write-Host "     - Error: ($(@($theError.Exception.Errors)[0].Number)) / State: ($(@($theError.Exception.Errors)[0].State)) / Message: ($($theError.Exception.Message))" -ForegroundColor Red
                Write-Host "     - ClientConnectionId: $($theError.Exception.ClientConnectionId)" -ForegroundColor Red

                if ($theError.Exception.Message -like "*Login failed for user 'SynapseConnectivityCheckerScript'*")
                {
                    [void]$Summary.AppendLine(">>----------------------------------------------------------------------------")
                    [void]$Summary.AppendLine(">> - ALERT(ID07)::($($ServerName)) Login failed for user 'SynapseConnectivityCheckerScript'")
                    [void]$Summary.AppendLine(">>   - Your AAD auth failed so we used fake user + pass to test connectivity. If we get this error at least we could reach Synapse Gateway")
                    [void]$Summary.AppendLine(">>   - Test to connect SSMS - Download last version from https://learn.microsoft.com/en-us/sql/ssms/download-sql-server-management-studio-ssms")
                    [void]$Summary.AppendLine(">>----------------------------------------------------------------------------")
                    [void]$Summary.AppendLine("")   
                }

                if ($theError.Exception.Message -like "*Login failed for user '<token-identified principal>'*")
                {
                    [void]$Summary.AppendLine(">>----------------------------------------------------------------------------")
                    [void]$Summary.AppendLine(">> - ERROR(ID01)::($($ServerName)) Login failed for user '<token-identified principal>")
                    [void]$Summary.AppendLine(">>   - CHECK")
                    [void]$Summary.AppendLine(">>     - https://techcommunity.microsoft.com/t5/azure-database-support-blog/aad-auth-error-login-failed-for-user-lt-token-identified/ba-p/1417535")
                    [void]$Summary.AppendLine(">>----------------------------------------------------------------------------")
                    [void]$Summary.AppendLine("")   
                }

                if ($theError.Exception.Message -like "*The server was not found or was not accessible*")
                {
                    [void]$Summary.AppendLine(">>----------------------------------------------------------------------------")
                    [void]$Summary.AppendLine(">> - ERROR(ID02)::($($ServerName)) The server was not found or was not accessible")
                    [void]$Summary.AppendLine(">>   - CHECK")
                    [void]$Summary.AppendLine(">>     - https://techcommunity.microsoft.com/t5/azure-synapse-analytics-blog/synapse-connectivity-series-part-1-inbound-sql-dw-connections-on/ba-p/3589170")
                    [void]$Summary.AppendLine(">>     - https://techcommunity.microsoft.com/t5/azure-synapse-analytics-blog/synapse-connectivity-series-part-2-inbound-synapse-private/ba-p/3705160")
                    [void]$Summary.AppendLine(">>----------------------------------------------------------------------------")
                    [void]$Summary.AppendLine("")   
                }

                if ($theError.Exception.Message -like "*Client with IP address * is not allowed to access the server*")
                {
                    [void]$Summary.AppendLine(">>----------------------------------------------------------------------------")
                    [void]$Summary.AppendLine(">> - ERROR(ID03)::($($ServerName)) Client with IP address 'XXX.XXX.XXX.XXX' is not allowed to access the server")
                    [void]$Summary.AppendLine(">>   - CHECK")
                    [void]$Summary.AppendLine(">>     - https://techcommunity.microsoft.com/t5/azure-synapse-analytics-blog/synapse-connectivity-series-part-1-inbound-sql-dw-connections-on/ba-p/3589170")
                    [void]$Summary.AppendLine(">>     - https://techcommunity.microsoft.com/t5/azure-synapse-analytics-blog/synapse-connectivity-series-part-2-inbound-synapse-private/ba-p/3705160")
                    [void]$Summary.AppendLine(">>----------------------------------------------------------------------------")
                    [void]$Summary.AppendLine("")   
                }

            }
            default{
                Write-Host "   - ERROR:: ($($theError.Exception.GetType().FullName)):: TEST SQL ($($ServerName)) ENDPOINT"  -ForegroundColor Red
                Write-Host "     - Error: ($(@($theError.Exception.Errors)[0].Number)) / State: ($(@($theError.Exception.Errors)[0].State)) / Message: ($($theError.Exception.Message))" -ForegroundColor Red
                Write-Host "     - ClientConnectionId: $($theError.Exception.ClientConnectionId)" -ForegroundColor Red
            }
        }
    }
}

Write-Host "  ----------------------------------------------------------------------------"
Write-Host "  -Testing SQL connection ($($FabricEndpoint)) / [$($DatabaseName)] DB on Port 1433" -ForegroundColor DarkGray

if ($null -ne $FabricEndpoint)
{
    try {
        TestSQLConnection `
        -ServerName $FabricEndpoint `
        -DatabaseName $DatabaseName `
        -SQLConnectionTimeout $SQLConnectionTimeout `
        -SQLQueryTimeout $SQLQueryTimeout `
        -AADUser $AADUser
    }
    catch {
        <#Do nothing. Exception already done on function#>
    }
}


# #endregion TEST API CALLs

#>

####################################################################################################################################################
# Summary
####################################################################################################################################################
Write-Host "------------------------------------------------------------------------------" -ForegroundColor Yellow
Write-Host "Summary " -ForegroundColor Yellow
Write-Host "------------------------------------------------------------------------------" -ForegroundColor Yellow

Write-Host $Summary.ToString() -ForegroundColor Cyan


####################################################################################################################################################
#CLEANUP
Write-Host "------------------------------------------------------------------------------" -ForegroundColor Yellow
Write-Host "CLEAN UP" -ForegroundColor Yellow

Get-PSSession | Remove-PSSession | Out-Null
[System.GC]::Collect()         
[GC]::Collect()
[GC]::WaitForPendingFinalizers()
####################################################################################################################################################

Write-Host "------------------------------------------------------------------------------" -ForegroundColor Yellow
Write-Host "END OF SCRIPT" -ForegroundColor Yellow
Write-Host "------------------------------------------------------------------------------" -ForegroundColor Yellow
 
