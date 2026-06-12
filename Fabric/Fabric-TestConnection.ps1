#Requires -Version 5

<#   
.NOTES     
    Author: Sergio Fonseca
    Twitter @FonsecaSergio
    Email: sergio.fonseca@microsoft.com
    Last Updated: 2026-06-09

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

#> 

using namespace System.Net

####################################################################################################################################################
# Parameter region for when script is run directly
$FabricEndpoint = "xxxx-xxxx.datawarehouse.fabric.microsoft.com" # Enter your Fabric SQL Endpoint
$WorkspaceID = "xxxxxxxxxxxxxxxxxx" # You can get id from Fabric URL like https://app.fabric.microsoft.com/groups/<WORKSPACEID>/mirroredwarehouses/xxxxxxx?experience=power-bi
####################################################################################################################################################

# Parameter region when Invoke-Command is used
$parameters = $args[0]

if ($null -ne $parameters) {
    $FabricEndpoint = $parameters['FabricEndpoint']
    $WorkspaceID = $parameters['WorkspaceID']
}

####################################################################################################################################################
# CHECK MANDATORY PARAMETERS
if([string]::IsNullOrEmpty($FabricEndpoint) -or $FabricEndpoint -eq "xxxx-xxxx.datawarehouse.fabric.microsoft.com") 
{
    Write-Error "ERROR:: Fabric Endpoint is mandatory"
    Break
}
if([string]::IsNullOrEmpty($WorkspaceID) -or $WorkspaceID -eq "xxxxxxxxxxxxxxxxxx") 
{
    Write-Error "ERROR:: Workspace ID is mandatory"
    Break
}

####################################################################################################################################################
# Initialization
Clear-Host

####################################################################################################################################################
#Variables and Constants
New-Variable -Name VERSION -Value "1.7" -Option Constant -ErrorAction Ignore
New-Variable -Name AnonymousRunId -Value ([guid]::NewGuid()).Guid -Option Constant -ErrorAction Ignore

New-Variable -Name TestPortConnectionTimeoutMs -Value 1000 -Option Constant -ErrorAction Ignore
New-Variable -Name SQLConnectionTimeout -Value 15 -Option Constant -ErrorAction Ignore
New-Variable -Name SQLQueryTimeout -Value 15 -Option Constant -ErrorAction Ignore
New-Variable -Name HostsFile -Value "$env:SystemDrive\Windows\System32\Drivers\etc\hosts" -Option Constant -ErrorAction Ignore

New-Variable -Name RedirectEndpoint -Value "" -ErrorAction Ignore
New-Variable -Name accessToken -ErrorAction Ignore
New-Variable -Name accessTokenExpiresOn -ErrorAction Ignore
New-Variable -Name refreshToken -ErrorAction Ignore
New-Variable -Name sqlAccessToken -ErrorAction Ignore
New-Variable -Name sqlAccessTokenExpiresOn -ErrorAction Ignore

$Summary = New-Object System.Text.StringBuilder

####################################################################################################################################################
#LOG VERSIONS

Write-Host ("Edition: Fabric") 
Write-Host ("Current version: " + $VERSION)
Write-Host ("PS version: " + $psVersionTable.PSVersion)
Write-Host ("PS OS version: " + $psVersionTable.OS)
Write-Host ("System.Environment OS version: " + [System.Environment]::OSVersion.Platform)
Write-Host ("FabricEndpoint: " + $FabricEndpoint)



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
Write-Host "------------------------------------------------------------------------------" -ForegroundColor Yellow
Write-Host "COLLECTING DATA" -ForegroundColor Yellow
Write-Host "------------------------------------------------------------------------------" -ForegroundColor Yellow


####################################################################################################################################################
# Get Power BI access token via Microsoft identity platform device code flow (native, no MicrosoftPowerBIMgmt module required)
# Docs: https://learn.microsoft.com/azure/active-directory/develop/v2-oauth2-device-code
#
# NOTE on multi-resource tokens:
#   Entra ID issues ONE access token per token request, and all scopes in that request must belong
#   to the SAME resource/audience. You cannot ask for a Power BI token AND a SQL token in a single
#   /devicecode call (you'll get AADSTS28000 "more than one resource").
#   Instead, we ask for `offline_access` on the first call so we also get a REFRESH TOKEN, then we
#   silently exchange that refresh token for additional access tokens (e.g. database.windows.net).
<#
.SYNOPSIS
    Acquires a Power BI access token (and refresh token) using the OAuth 2.0 device code flow.

.DESCRIPTION
    Uses the well-known Microsoft Azure PowerShell public client ID (1950a258-227b-4e31-a9cf-717495945fc2)
    against the /common tenant and the Power BI service scope. Prompts the user to authenticate in a
    browser using a device code, then polls the token endpoint until a token is returned.

    Returns a PSCustomObject with:
      - AccessToken   : the access_token string
      - RefreshToken  : the refresh_token string (present when `offline_access` was requested)
      - ExpiresOn     : approximate UTC expiry time of the access token
      - Tenant        : tenant used (echoed for downstream refresh calls)
      - ClientId      : client id used (echoed for downstream refresh calls)
#>
function Get-PowerBIAccessTokenNative {
    param(
        [string]$Tenant   = "common",
        [string]$ClientId = "1950a258-227b-4e31-a9cf-717495945fc2", # Microsoft Azure PowerShell (public client)
        [string]$Scope    = "https://analysis.windows.net/powerbi/api/.default offline_access openid profile"
    )

    Write-Host "Check browser - Acquiring Power BI access token" -ForegroundColor Cyan       

    $deviceCodeUrl = "https://login.microsoftonline.com/$Tenant/oauth2/v2.0/devicecode"
    $tokenUrl      = "https://login.microsoftonline.com/$Tenant/oauth2/v2.0/token"

    $deviceCodeResp = Invoke-RestMethod -Method Post -Uri $deviceCodeUrl -ContentType "application/x-www-form-urlencoded" -Body @{
        client_id = $ClientId
        scope     = $Scope
    } -ErrorAction Stop

    Write-Host ""
    Write-Host "   - $($deviceCodeResp.message)" -ForegroundColor Yellow
    Write-Host ""

    # Polling interval (in SECONDS) returned by the server, typically 5s. Per RFC 8628.
    $interval  = [int]$deviceCodeResp.interval
    if ($interval -le 0) { $interval = 5 }
    $expiresIn = [int]$deviceCodeResp.expires_in
    # Cap local wait at 3 minutes so the script doesn't hang for the full server-side window
    $maxWaitSeconds = 3*60
    if ($expiresIn -gt $maxWaitSeconds) { $expiresIn = $maxWaitSeconds }
    $deadline  = (Get-Date).AddSeconds($expiresIn)

    :poll while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds $interval
        try {
            $tokenResp = Invoke-RestMethod -Method Post -Uri $tokenUrl -ContentType "application/x-www-form-urlencoded" -Body @{
                grant_type  = "urn:ietf:params:oauth:grant-type:device_code"
                client_id   = $ClientId
                device_code = $deviceCodeResp.device_code
            } -ErrorAction Stop

            if ($tokenResp.access_token) {
                return [PSCustomObject]@{
                    AccessToken  = $tokenResp.access_token
                    RefreshToken = $tokenResp.refresh_token
                    ExpiresOn    = (Get-Date).AddSeconds([int]$tokenResp.expires_in)
                    Tenant       = $Tenant
                    ClientId     = $ClientId
                }
            }
        }
        catch {
            # In Windows PowerShell 5.1, the response body is exposed via $_.ErrorDetails.Message
            # (the underlying response stream is already consumed by Invoke-RestMethod).
            $errBody = $null
            $rawBody = $_.ErrorDetails.Message
            if (-not $rawBody) {
                try {
                    $stream = $_.Exception.Response.GetResponseStream()
                    if ($null -ne $stream) {
                        $reader  = New-Object System.IO.StreamReader($stream)
                        $rawBody = $reader.ReadToEnd()
                    }
                } catch { }
            }
            if ($rawBody) {
                try { $errBody = $rawBody | ConvertFrom-Json } catch { }
            }

            switch ($errBody.error) {
                "authorization_pending"  {
                    Write-Host "     . waiting for sign-in..." -ForegroundColor DarkGray
                    continue poll
                }
                "slow_down"              {
                    $interval += 5
                    Write-Host "     . server asked to slow down; interval now $interval s" -ForegroundColor DarkGray
                    continue poll
                }
                "expired_token"          { throw "Device code expired before user authenticated." }
                "authorization_declined" { throw "User declined the authentication request." }
                default {
                    Write-Host "Token endpoint error: $($_.Exception.Message) - body: $rawBody" -ForegroundColor Red
                }
            }
        }
    }
    Write-Host "Timed out waiting for user to complete device code authentication." -ForegroundColor Red
}

<#
.SYNOPSIS
    Silently exchanges a refresh token for an access token scoped to a different resource.

.DESCRIPTION
    Entra ID does not allow asking for two different resources in a single token request, but a
    refresh token issued together with `offline_access` can be redeemed for additional access
    tokens against other resources without re-prompting the user. This helper performs that
    refresh_token grant and returns the new access token (and the rotated refresh token, since
    Entra ID rotates refresh tokens on each use for public clients).

.PARAMETER RefreshToken
    The refresh token obtained from a prior interactive auth (e.g. Get-PowerBIAccessTokenNative).

.PARAMETER Scope
    The new scope to request. Typically "<resource>/.default offline_access".

.PARAMETER Tenant
    Tenant authority to use. Defaults to "common".

.PARAMETER ClientId
    Client ID to use. MUST match the client that originally obtained the refresh token.
#>
function Get-AccessTokenFromRefreshToken {
    param(
        [Parameter(Mandatory = $true)][string]$RefreshToken,
        [Parameter(Mandatory = $true)][string]$Scope,
        [string]$Tenant   = "common",
        [string]$ClientId = "1950a258-227b-4e31-a9cf-717495945fc2"
    )

    $tokenUrl = "https://login.microsoftonline.com/$Tenant/oauth2/v2.0/token"

    try {
        $tokenResp = Invoke-RestMethod -Method Post -Uri $tokenUrl -ContentType "application/x-www-form-urlencoded" -Body @{
            grant_type    = "refresh_token"
            client_id     = $ClientId
            refresh_token = $RefreshToken
            scope         = $Scope
        } -ErrorAction Stop

        return [PSCustomObject]@{
            AccessToken  = $tokenResp.access_token
            RefreshToken = $tokenResp.refresh_token   # Entra ID rotates the RT on each use for public clients
            ExpiresOn    = (Get-Date).AddSeconds([int]$tokenResp.expires_in)
            Tenant       = $Tenant
            ClientId     = $ClientId
        }
    }
    catch {
        # Surface the AAD error body when available so the caller knows WHY the refresh failed
        # (e.g. invalid_grant -> refresh token expired / revoked / consent missing for new resource).
        $rawBody = $_.ErrorDetails.Message
        if (-not $rawBody) {
            try {
                $stream = $_.Exception.Response.GetResponseStream()
                if ($null -ne $stream) {
                    $reader  = New-Object System.IO.StreamReader($stream)
                    $rawBody = $reader.ReadToEnd()
                }
            } catch { }
        }
        throw "Refresh token exchange failed for scope ($Scope): $($_.Exception.Message) - body: $rawBody"
    }
}

<#
.SYNOPSIS
    Returns $true when the supplied token expiry timestamp is still valid (with a safety buffer).

.DESCRIPTION
    A token is considered valid only if ExpiresOn is not null AND is at least BufferSeconds in the
    future. The buffer prevents reusing a token that will expire mid-request.
#>
function Test-AccessTokenValid {
    param(
        $ExpiresOn,
        [int]$BufferSeconds = 60
    )
    if ($null -eq $ExpiresOn) { return $false }
    try {
        return ((Get-Date) -lt ([datetime]$ExpiresOn).AddSeconds(-$BufferSeconds))
    }
    catch {
        return $false
    }
}

# Acquire a Power BI access token if we don't have one, or if the existing one is expired / near expiry.
if ([string]::IsNullOrEmpty($accessToken)) {
    Write-Host "   - INFO:: No existing Power BI access token found, acquiring a new one" -ForegroundColor DarkGray
    $tokenResult           = Get-PowerBIAccessTokenNative
    $accessToken           = $tokenResult.AccessToken
    $refreshToken          = $tokenResult.RefreshToken
    $accessTokenExpiresOn  = $tokenResult.ExpiresOn
}
elseif (-not (Test-AccessTokenValid -ExpiresOn $accessTokenExpiresOn)) {
    Write-Host "   - INFO:: Existing Power BI access token is expired or near expiry (ExpiresOn=$accessTokenExpiresOn), acquiring a new one" -ForegroundColor Yellow
    $tokenResult           = Get-PowerBIAccessTokenNative
    $accessToken           = $tokenResult.AccessToken
    $refreshToken          = $tokenResult.RefreshToken
    $accessTokenExpiresOn  = $tokenResult.ExpiresOn
}
else {
    Write-Host "   - INFO:: Reusing existing Power BI access token (expires $accessTokenExpiresOn)" -ForegroundColor Green
}


####################################################################################################################################################
#Get Capacity ID from Workspace ID
<#
.SYNOPSIS
    Resolves the Power BI / Fabric capacity redirect endpoint for a given workspace ID.

.DESCRIPTION
    Acquires an access token via the device code flow, calls the Power BI REST API to look up
    the workspace's CapacityId, and returns a PSCustomObject with CapacityId and RedirectEndpoint.
    Writes progress / errors to the host. Returns $null on failure.

.PARAMETER WorkspaceID
    The Power BI / Fabric workspace (group) GUID.

.EXAMPLE
    $info = Get-FabricCapacityRedirectEndpoint -WorkspaceID $WorkspaceID
    $RedirectEndpoint = $info.RedirectEndpoint
#>
function Get-FabricCapacityRedirectEndpoint {
    param(
        [Parameter(Mandatory = $true)]
        [string]$WorkspaceID
    )

    try {
        # Power BI REST API - Get Group (workspace) by ID
        # https://learn.microsoft.com/rest/api/power-bi/groups/get-groups
        $workspace = Invoke-RestMethod `
            -Method Get `
            -Uri "https://api.powerbi.com/v1.0/myorg/groups/$WorkspaceID" `
            -Headers @{ Authorization = "Bearer $accessToken" } `
            -ErrorAction Stop

        $CapacityId       = $workspace.capacityId
        $CapacityIdClean  = $CapacityId -replace "-", ""
        $RedirectEndpoint = "$CapacityIdClean.pbidedicated.windows.net"

        Write-Host "Capacity ID: $CapacityId"

        return $RedirectEndpoint
    }
    catch {
        Write-Host "   - ERROR::Failed to get Capacity ID from Workspace ID"  -ForegroundColor Red
        Write-Host "     - $($_.Exception.Message)" -ForegroundColor Red

        return $null
    }
}

<#
.SYNOPSIS
    Prompts the user to manually enter a Capacity ID and returns the corresponding redirect endpoint.

.DESCRIPTION
    Used as a fallback when the Power BI REST API call to look up the workspace's CapacityId fails
    (e.g. insufficient permissions, network/auth issues). The user can find the Capacity ID in the
    Fabric Admin Portal -> Capacity settings, or via the Fabric workspace settings page.

    Accepts the Capacity ID in either GUID format (with dashes) or already stripped of dashes,
    validates it, and returns the redirect endpoint string. Returns $null if the user provides
    no input or the input is not a valid GUID.
#>
function Read-FabricCapacityRedirectEndpointFromUser {
    Write-Host ""
    Write-Host "   - INFO:: You can find the Capacity ID in the Fabric Admin Portal under Capacity settings," -ForegroundColor Yellow
    Write-Host "            or in the Fabric workspace settings (License info -> Capacity)." -ForegroundColor Yellow
    $capacityIdInput = Read-Host "   - Please type the Capacity ID (GUID) and press Enter (leave empty to skip)"

    if ([string]::IsNullOrWhiteSpace($capacityIdInput)) {
        Write-Host "   - WARN:: No Capacity ID provided, skipping redirect endpoint resolution" -ForegroundColor Yellow
        return $null
    }

    $capacityIdInput = $capacityIdInput.Trim()

    # Accept input with or without dashes; validate as GUID after normalizing.
    $capacityIdNoDashes = $capacityIdInput -replace "-", ""
    $parsedGuid = [guid]::Empty
    if (-not [guid]::TryParse($capacityIdInput, [ref]$parsedGuid) -and
        -not [guid]::TryParse($capacityIdNoDashes, [ref]$parsedGuid)) {
        Write-Host "   - ERROR:: '$capacityIdInput' is not a valid GUID" -ForegroundColor Red
        return $null
    }

    $CapacityIdClean  = $parsedGuid.ToString("N")  # 32 hex chars, no dashes
    $RedirectEndpoint = "$CapacityIdClean.pbidedicated.windows.net"

    Write-Host "   - INFO:: Using Capacity ID: $($parsedGuid.ToString())" -ForegroundColor Cyan
    return $RedirectEndpoint
}

$RedirectEndpoint = Get-FabricCapacityRedirectEndpoint -WorkspaceID $WorkspaceID

if ($null -eq $RedirectEndpoint) {
    Write-Host "   - INFO:: Falling back to manual Capacity ID entry" -ForegroundColor Yellow
    $RedirectEndpoint = Read-FabricCapacityRedirectEndpointFromUser
}

Write-Host "Redirect Endpoint: $RedirectEndpoint"


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
    <#
    [void] Resolve_DnsName_CXDNS_Powershell ()
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
    #>



    #----------------------------------------------------------------------------------------------------------------------
    # Native .NET implementation using [System.Net.Dns]::GetHostEntry().
    # - Works cross-platform (Windows / Linux / macOS) on Windows PowerShell 5.1 and PowerShell 7+.
    # - Does NOT require the Windows-only DnsClient module (no Resolve-DnsName dependency).
    # - GetHostEntry returns:
    #     * HostName    -> the canonical name returned by the resolver (effectively the final CNAME).
    #     * AddressList -> all resolved IP addresses; we pick the first IPv4 (InterNetwork) entry.
    [void] Resolve_DnsName_CXDNS () {
        if ($null -eq $this.Endpoint.Name -or $this.Endpoint.Name -eq "") {
            Write-Host "   - ERROR:: Endpoint name is null or empty, cannot resolve DNS" -ForegroundColor Red
            return
        }
        try {
            $hostEntry = [System.Net.Dns]::GetHostEntry($this.Endpoint.Name)

            $ipv4 = $hostEntry.AddressList |
                Where-Object { $_.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork } |
                Select-Object -First 1

            if ($null -ne $ipv4) {
                $this.CXResolvedIP = $ipv4.ToString()
            }

            # If the resolver followed a CNAME chain, HostName will differ from the queried name.
            if ($null -ne $hostEntry.HostName -and $hostEntry.HostName -ne $this.Endpoint.Name) {
                $this.CXResolvedCNAME = $hostEntry.HostName
            }
        }
        catch {
            # PowerShell wraps the underlying .NET exception in a MethodInvocationException, so the
            # real System.Net.Sockets.SocketException is on $_.Exception.InnerException.
            # SocketError.HostNotFound == 11001 ("No such host is known.") on Windows.
            $inner = $_.Exception.InnerException
            if ($inner -is [System.Net.Sockets.SocketException] -and
                $inner.SocketErrorCode -eq [System.Net.Sockets.SocketError]::HostNotFound) {
                Write-Host "   - ERROR:: DNS resolution failed for $($this.Endpoint.Name) - host not found" -ForegroundColor Yellow
            }
            else {
                Write-Host "   - ERROR:: Trying to resolve DNS for $($this.Endpoint.Name) from Customer DNS" -ForegroundColor Yellow
                Write-Host "     - $($_.Exception.Message)" -ForegroundColor DarkGray
            }
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
    "$($RedirectEndpoint)"= @(1433)
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
    #Write-Host "Testing DNS resolution for ($($EndpointTest.Endpoint.Name)) against CX DNS..." -ForegroundColor Cyan
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


#region Check if ZScaler is running
<#
.SYNOPSIS
    Checks whether ZScaler processes are running on the local machine.

.DESCRIPTION
    Looks for processes whose name matches "zscaler" or "zs" and prints a friendly
    message indicating whether ZScaler is running or not.
#>
function Test-ZScalerRunning {
    Write-Host "  ----------------------------------------------------------------------------"
    Write-Host "  Checking for ZScaler processes running on the machine"

    try {
        $zsProcesses = @(Get-Process -ErrorAction Stop | Where-Object {
                $_.ProcessName -match "zscaler|zs"
            })

        if ($zsProcesses.Count -gt 0) {
            Write-Host "   - WARN:: Can see ZScaler running" -ForegroundColor Yellow
            foreach ($p in $zsProcesses) {
                Write-Host "     - Process: $($p.ProcessName) (PID $($p.Id))" -ForegroundColor Yellow
            }
        }
        else {
            Write-Host "   - INFO:: No ZScaler service running" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "   - ERROR:: Test-ZScalerRunning" -ForegroundColor Red
        Write-Host "     - $($_.Exception.Message)" -ForegroundColor Red
    }
}

Test-ZScalerRunning
#endregion Check if ZScaler is running

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
    Get-DnsClientServerAddress | Where-Object ServerAddresses | Select-Object InterfaceAlias, InterfaceIndex, AddressFamily, ServerAddresses | Format-Table -AutoSize
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

        Write-Host ""
        Write-Host "   - Running additional method to check proxy setting - using (netsh winhttp show proxy)" -ForegroundColor Yellow
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
        # Native .NET implementation using System.Diagnostics.EventLog.
        # - Avoids the legacy Get-EventLog cmdlet (deprecated; not available in PowerShell 7+ on non-Windows,
        #   and removed/limited in some newer Windows PowerShell scenarios).
        # - Reads the "Integration Runtime" classic event log directly.
        # - Filters by InstanceId == 26 and Message starting with "Http Proxy is set to",
        #   then returns the newest 15 matching entries.
        # - Note: System.Diagnostics.EventLog is Windows-only; SHIR only runs on Windows, so this is fine.

        $logName = "Integration Runtime"

        if (-not [System.Diagnostics.EventLog]::SourceExists -and -not [System.Diagnostics.EventLog]::Exists($logName)) {
            # Log doesn't exist on this machine (not a SHIR host) -> nothing to do.
            return
        }

        if (-not [System.Diagnostics.EventLog]::Exists($logName)) {
            return
        }

        $eventLog = New-Object System.Diagnostics.EventLog $logName
        try {
            # EventLog.Entries is a live, lazily-enumerated collection ordered oldest -> newest.
            # Walk it from the newest end backwards and collect up to 15 matches.
            $entries  = $eventLog.Entries
            $total    = $entries.Count
            $matches  = New-Object System.Collections.Generic.List[object]

            for ($i = $total - 1; $i -ge 0 -and $matches.Count -lt 15; $i--) {
                $entry = $entries[$i]
                if ($entry.InstanceId -eq 26 -and $entry.Message -like "Http Proxy is set to*") {
                    $matches.Add([PSCustomObject]@{
                        TimeGenerated = $entry.TimeGenerated
                        Message       = $entry.Message
                    })
                }
            }

            Write-Host "  ----------------------------------------------------------------------------"
            Write-Host "  SHIR Proxy Settings"
            $matches | Select-Object TimeGenerated, Message
        }
        finally {
            $eventLog.Dispose()
        }
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
Write-Host "   - NOTE that this only tests TCP not TLS, so even if port 1433 is open there could be other issues related to TLS handshake that are not covered by this test" -ForegroundColor Yellow
Write-Host ""
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
Write-Host "TEST TCP TLS CALLs" -ForegroundColor Yellow
Write-Host "------------------------------------------------------------------------------" -ForegroundColor Yellow

####################################################################################################################################################
# Port 1433 speaks TDS (not HTTP), so we cannot use Invoke-WebRequest/curl which expect an HTTP response.
# Instead, perform a raw TLS handshake using SslStream to validate that TLS works end-to-end.
#
# Common failure mode: "A call to SSPI failed, see inner exception."
#   This is an SChannel-side failure that happens BEFORE our managed RemoteCertificateValidationCallback
#   ever runs. The real reason is in the INNERMOST Win32Exception (NativeErrorCode = SChannel/SECURITY_STATUS).
#   Typical root causes on Windows:
#     - 0x80090326 SEC_E_ILLEGAL_MESSAGE         -> TLS version / cipher / curve mismatch (most common; server requires TLS 1.2+ but client SChannel default doesn't offer it)
#     - 0x80090325 SEC_E_UNTRUSTED_ROOT          -> server cert chain doesn't build to a trusted root in LocalMachine/CurrentUser store
#     - 0x80090327 SEC_E_CERT_UNKNOWN            -> generic cert validation failure inside SChannel
#     - 0x80090331 SEC_E_ALGORITHM_MISMATCH      -> FIPS / hardened crypto policy stripped required ciphers
#     - 0x8009030F SEC_E_MESSAGE_ALTERED         -> something is rewriting TLS (TLS-inspecting proxy / ZScaler / firewall MITM)
#   We therefore (a) explicitly negotiate TLS 1.2 / 1.3 instead of relying on SChannel defaults, and
#   (b) walk the full inner-exception chain so the SChannel error code is visible.

<#
.SYNOPSIS
    Walks the full InnerException chain and prints each layer (Type, Message, HResult, native code).
#>
function Write-ExceptionChain {
    param([Parameter(Mandatory = $true)]$Exception)

    $ex    = $Exception
    $depth = 0
    while ($null -ne $ex) {
        $hresult = ('0x{0:X8}' -f $ex.HResult)
        Write-Host ("     - [{0}] {1}: {2} (HResult={3})" -f $depth, $ex.GetType().FullName, $ex.Message, $hresult) -ForegroundColor Red

        # Win32Exception / SocketException expose the raw OS error code (this is where SChannel SECURITY_STATUS shows up).
        if ($ex -is [System.ComponentModel.Win32Exception]) {
            $win32 = [System.ComponentModel.Win32Exception]$ex
            Write-Host ("       NativeErrorCode = {0} (0x{0:X8})" -f $win32.NativeErrorCode) -ForegroundColor Red
        }
        elseif ($ex -is [System.Net.Sockets.SocketException]) {
            $sockEx = [System.Net.Sockets.SocketException]$ex
            Write-Host ("       SocketErrorCode = {0} / ErrorCode = {1}" -f $sockEx.SocketErrorCode, $sockEx.ErrorCode) -ForegroundColor Red
        }

        $ex = $ex.InnerException
        $depth++
    }
}

function Test-TlsHandshake {
    param(
        [string]$ComputerName,
        [int]$Port = 1433,
        [int]$TimeoutMs = 15000
    )

    $tcpClient = $null
    $sslStream = $null
    try {
        Write-Host "  -Testing TLS handshake against ($($ComputerName):$($Port))" -ForegroundColor DarkGray

        # Diagnostic: what TLS versions is .NET/SChannel willing to use on this machine?
        # On Windows PowerShell 5.1 the default ServicePointManager often only includes Ssl3/Tls (1.0),
        # which Azure SQL / Fabric reject -> SSPI handshake failure with SEC_E_ILLEGAL_MESSAGE.
        Write-Host "   - INFO:: [Net.ServicePointManager]::SecurityProtocol = $([Net.ServicePointManager]::SecurityProtocol)" -ForegroundColor DarkGray

        $tcpClient = New-Object System.Net.Sockets.TcpClient
        if (-not $tcpClient.ConnectAsync($ComputerName, $Port).Wait($TimeoutMs)) {
            Write-Host "   - ERROR:: TCP connect timed out after $TimeoutMs ms" -ForegroundColor Red
            return
        }
        Write-Host "   - INFO:: TCP connected" -ForegroundColor Cyan

        # Accept any cert so we can still see what was negotiated (we just want to validate the TLS path).
        # NOTE: this callback only fires AFTER SChannel has parsed the server hello + cert. If SChannel
        # itself rejects the handshake (e.g. no shared TLS version), we get an SSPI error before this
        # callback is ever invoked.
        $sslStream = New-Object System.Net.Security.SslStream($tcpClient.GetStream(), $false, ({ param($s,$c,$ch,$e) $true } -as [System.Net.Security.RemoteCertificateValidationCallback]))

        # Explicitly request TLS 1.2 / 1.3 instead of letting SChannel pick the default set.
        # - PowerShell 5.1 / older .NET Framework defaults to SslProtocols.Default = Ssl3 | Tls (1.0),
        #   which Azure SQL / Fabric SQL endpoints reject -> "SSPI failed" with no useful inner message.
        # - Tls13 enum exists in .NET Framework 4.8+ and .NET 5+. We build the value via bitwise OR
        #   so the script still parses on runtimes that don't define Tls13 (we fall back to Tls12 only).
        $tls12 = [System.Security.Authentication.SslProtocols]::Tls12
        $protocols = $tls12
        try {
            $tls13 = [System.Security.Authentication.SslProtocols]::Tls13
            $protocols = $tls12 -bor $tls13
        } catch {
            # Tls13 not available on this runtime; stick with Tls12.
        }

        # Use the richer AuthenticateAsClient overload so we can pin the protocol set explicitly.

        Write-Host "   - INFO:: Using TLS protocols: $protocols" -ForegroundColor DarkGray

        $sslStream.AuthenticateAsClient($ComputerName, $null, $protocols, $false)

        Write-Host "   - SUCCESS:: TLS handshake completed" -ForegroundColor Green
        Write-Host "     - Protocol      : $($sslStream.SslProtocol)" -ForegroundColor Green
        Write-Host "     - CipherAlgo    : $($sslStream.CipherAlgorithm) ($($sslStream.CipherStrength) bits)" -ForegroundColor Green
        Write-Host "     - HashAlgo      : $($sslStream.HashAlgorithm)" -ForegroundColor Green
        $cert = $sslStream.RemoteCertificate
        if ($null -ne $cert) {
            $cert2 = [System.Security.Cryptography.X509Certificates.X509Certificate2]$cert
            Write-Host "     - Cert Subject  : $($cert2.Subject)" -ForegroundColor Green
            Write-Host "     - Cert Issuer   : $($cert2.Issuer)" -ForegroundColor Green
            Write-Host "     - Cert NotAfter : $($cert2.NotAfter)" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "   - ERROR:: TLS handshake failed: $($_.Exception.Message)" -ForegroundColor Red
        # Walk the FULL inner-exception chain. For "A call to SSPI failed", the real diagnosis is
        # the innermost Win32Exception whose NativeErrorCode is the SChannel SECURITY_STATUS code.
        Write-ExceptionChain -Exception $_.Exception

        Write-Host "     - HINT:: If NativeErrorCode is 0x80090326 (SEC_E_ILLEGAL_MESSAGE) the server" -ForegroundColor Yellow
        Write-Host "             rejected the TLS hello - usually TLS 1.2 disabled in SChannel registry," -ForegroundColor Yellow
        Write-Host "             FIPS policy stripping ciphers, or a TLS-inspecting proxy (e.g. ZScaler)" -ForegroundColor Yellow
        Write-Host "             rewriting the handshake. Check:" -ForegroundColor Yellow
        Write-Host "               HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client" -ForegroundColor Yellow
        Write-Host "             ('Enabled'=1, 'DisabledByDefault'=0) and any .NET Framework 'SchUseStrongCrypto' settings." -ForegroundColor Yellow
    }
    finally {
        if ($null -ne $sslStream) { $sslStream.Dispose() }
        if ($null -ne $tcpClient) { $tcpClient.Close() }
    }
}

Test-TlsHandshake -ComputerName $FabricEndpoint -Port 1433
Test-TlsHandshake -ComputerName $RedirectEndpoint -Port 1433


####################################################################################################################################################
Write-Host "------------------------------------------------------------------------------" -ForegroundColor Yellow
Write-Host "TEST SIMPLE SQL CONNECTION" -ForegroundColor Yellow
Write-Host "------------------------------------------------------------------------------" -ForegroundColor Yellow


####################################################################################################################################################
# Open a real TDS connection using an AAD access token (SqlConnection.AccessToken).
# Why: SSPI errors during "TLS auth" are typically the SQL driver falling back to Windows
# Integrated Security / Kerberos after the TLS handshake (e.g. wrong SPN, no Kerberos ticket,
# wrong logged-in identity). Passing an AAD token explicitly skips SSPI/Kerberos entirely,
# which lets us tell apart:
#   - Network / TLS path issues          -> already covered by Test-TlsHandshake
#   - Auth/identity (SSPI/Kerberos) issues -> this test will SUCCEED while integrated auth FAILS
#   - Server-side login issues           -> this test will FAIL with a SQL login error (not SSPI)
#
# Note: $accessToken acquired earlier is scoped to Power BI (analysis.windows.net) and is NOT
# accepted by the SQL endpoint. We reuse the device-code helper with the SQL scope.
<#
.SYNOPSIS
    Tests a SQL connection using an AAD access token (bypasses SSPI/Kerberos).

.DESCRIPTION
    Opens a System.Data.SqlClient.SqlConnection against the given endpoint and assigns the
    provided AAD access token to SqlConnection.AccessToken, then runs a trivial query.
    This validates the full TDS login path using AAD auth, without any reliance on the
    logged-in Windows identity, SPN registration, or Kerberos tickets.

.PARAMETER ComputerName
    SQL endpoint FQDN (e.g. the Fabric DW SQL endpoint or the capacity redirect endpoint).

.PARAMETER Port
    TCP port. Defaults to 1433.

.PARAMETER Database
    Database name. Defaults to "master".

.PARAMETER AccessToken
    AAD access token with audience https://database.windows.net/ (scope .../.default).

.PARAMETER ConnectionTimeoutSec
    SQL connection timeout in seconds.
#>
function Test-SqlConnectionWithToken {
    param(
        [Parameter(Mandatory = $true)][string]$ComputerName,
        [int]$Port = 1433,
        [string]$Database = "master",
        [Parameter(Mandatory = $true)][string]$AccessToken,
        [int]$ConnectionTimeoutSec = 15
    )

    $conn = $null
    try {
        Write-Host "  -Testing SQL connection with AAD access token against ($($ComputerName):$($Port))" -ForegroundColor DarkGray

        # Encrypt=True + TrustServerCertificate=False -> normal Azure SQL / Fabric posture.
        # No Integrated Security, no User Id / Password -> SqlClient will only use the supplied
        # AccessToken to authenticate (no SSPI / Kerberos fallback).
        $connStr = "Server=tcp:$ComputerName,$Port;Database=$Database;Encrypt=True;TrustServerCertificate=False;Connection Timeout=$ConnectionTimeoutSec;"

        $conn = New-Object System.Data.SqlClient.SqlConnection $connStr
        $conn.AccessToken = $AccessToken
        $conn.Open()

        # ClientConnectionId is the GUID the SQL driver assigns to this physical TDS connection.
        # It's the SAME id the server logs in sys.dm_exec_connections.client_connection_id and
        # the same id surfaced in SqlException.ClientConnectionId on errors, so capturing it on
        # success makes it easy to correlate client-side logs with server-side telemetry.
        Write-Host "   - INFO:: ClientConnectionId (from .NET) : $($conn.ClientConnectionId)" -ForegroundColor Cyan

        $cmd = $conn.CreateCommand()
        $cmd.CommandTimeout = $ConnectionTimeoutSec
        # Also pull connection_id from the server side via sys.dm_exec_connections. It should
        # match the .NET ClientConnectionId above; if it doesn't, something proxied/rewrote the
        # connection between us and the SQL engine.
        $cmd.CommandText = @"
SELECT
    @@SERVERNAME                                  AS srv,
    SUSER_SNAME()                                 AS login_name,
    GETUTCDATE()                                  AS utc,
    CONVERT(nvarchar(64), CONNECTIONPROPERTY('client_net_address')) AS client_ip,
    (SELECT TOP 1 CONVERT(nvarchar(36), c.connection_id)
       FROM sys.dm_exec_connections c
      WHERE c.session_id = @@SPID)                AS connection_id
"@
        $reader = $cmd.ExecuteReader()
        try {
            if ($reader.Read()) {
                Write-Host "   - SUCCESS:: SQL connection via AAD token completed" -ForegroundColor Green
                Write-Host "     - ServerName    : $($reader['srv'])" -ForegroundColor Green
                Write-Host "     - LoginName     : $($reader['login_name'])" -ForegroundColor Green
                Write-Host "     - UTC           : $($reader['utc'])" -ForegroundColor Green
                Write-Host "     - ClientIP      : $($reader['client_ip'])" -ForegroundColor Green
                Write-Host "     - ConnectionId  : $($reader['connection_id'])" -ForegroundColor Green
            }
        }
        finally {
            $reader.Close()
        }
    }
    catch {
        Write-Host "   - ERROR:: SQL connection via AAD token failed: $($_.Exception.Message)" -ForegroundColor Red
        if ($_.Exception -is [System.Data.SqlClient.SqlException]) {
            $sqlEx = [System.Data.SqlClient.SqlException]$_.Exception
            Write-Host "     - SQL Number/State : $($sqlEx.Number) / $($sqlEx.State)" -ForegroundColor Red
            Write-Host "     - ClientConnectionId: $($sqlEx.ClientConnectionId)" -ForegroundColor Red
        }
        if ($null -ne $_.Exception.InnerException) {
            Write-Host "     - Inner: $($_.Exception.InnerException.Message)" -ForegroundColor Red
        }
    }
    finally {
        if ($null -ne $conn) { $conn.Dispose() }
    }
}

# Acquire an AAD token scoped to Azure SQL (audience expected by Fabric SQL endpoints).
# We silently redeem the refresh token from the initial Power BI device-code auth, so the user
# is NOT prompted a second time. Entra ID only issues one access token per request and all
# scopes must share a single resource, so we cannot ask for Power BI + SQL in one shot.

if (-not [string]::IsNullOrEmpty($sqlAccessToken) -and (Test-AccessTokenValid -ExpiresOn $sqlAccessTokenExpiresOn)) {
    Write-Host "   - INFO:: Reusing previously acquired AAD token for SQL tests (expires $sqlAccessTokenExpiresOn)" -ForegroundColor Cyan
}
else {
    if (-not [string]::IsNullOrEmpty($sqlAccessToken)) {
        Write-Host "   - INFO:: Existing SQL AAD token is expired or near expiry (ExpiresOn=$sqlAccessTokenExpiresOn), acquiring a new one" -ForegroundColor Yellow
    }
    else {
        Write-Host "   - INFO:: No existing SQL AAD token found, acquiring a new one" -ForegroundColor Yellow
    }

    if (-not [string]::IsNullOrEmpty($refreshToken)) {
        try {
            #Write-Host "   - INFO:: Silently exchanging refresh token for SQL-scoped access token" -ForegroundColor Cyan
            $sqlTokenResult = Get-AccessTokenFromRefreshToken `
                -RefreshToken $refreshToken `
                -Scope        "https://database.windows.net/.default offline_access"

            $sqlAccessToken          = $sqlTokenResult.AccessToken
            $sqlAccessTokenExpiresOn = $sqlTokenResult.ExpiresOn
            # Entra ID rotates the refresh token on each use; keep the newest one for any further refreshes.
            $refreshToken            = $sqlTokenResult.RefreshToken
        }
        catch {
            Write-Host "   - WARN:: Silent refresh for SQL scope failed, falling back to device code: $($_.Exception.Message)" -ForegroundColor Yellow
            try {
                $sqlTokenResult          = Get-PowerBIAccessTokenNative -Scope "https://database.windows.net/.default offline_access"
                $sqlAccessToken          = $sqlTokenResult.AccessToken
                $sqlAccessTokenExpiresOn = $sqlTokenResult.ExpiresOn
                $refreshToken            = $sqlTokenResult.RefreshToken
            }
            catch {
                Write-Host "   - ERROR:: Failed to acquire SQL AAD access token: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
    else {
        try {
            $sqlTokenResult          = Get-PowerBIAccessTokenNative -Scope "https://database.windows.net/.default offline_access"
            $sqlAccessToken          = $sqlTokenResult.AccessToken
            $sqlAccessTokenExpiresOn = $sqlTokenResult.ExpiresOn
            $refreshToken            = $sqlTokenResult.RefreshToken
        }
        catch {
            Write-Host "   - ERROR:: Failed to acquire SQL AAD access token: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

if (-not [string]::IsNullOrEmpty($sqlAccessToken)) {
    Test-SqlConnectionWithToken -ComputerName $FabricEndpoint   -Port 1433 -AccessToken $sqlAccessToken
}
else {
    Write-Host "   - WARN:: Skipping SQL-with-token tests because no SQL access token was acquired." -ForegroundColor Yellow
}




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
#Remove-Variable -Name accessToken -ErrorAction SilentlyContinue 
#Remove-Variable -Name sqlAccessToken -ErrorAction SilentlyContinue 
[System.GC]::Collect()         
[GC]::Collect()
[GC]::WaitForPendingFinalizers()
####################################################################################################################################################

Write-Host "------------------------------------------------------------------------------" -ForegroundColor Yellow
Write-Host "END OF SCRIPT" -ForegroundColor Yellow
Write-Host "------------------------------------------------------------------------------" -ForegroundColor Yellow
 
