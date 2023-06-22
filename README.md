# Project

Script to test Synapse connectivity endpoints and Ports needed
    - Check Windows HOST File entries
    - Check DNS configuration
    - Check name resolution for all possible endpoints used by Synapse
    - Check if ports needed are open (1433 / 1443 / 443)
    - Check Internet and Self Hosted IR proxy that change name resolution from local machine to proxy
    - To make this test it might open AD auth / MFA / to be able to make tests below (Connect-AzAccount -Subscription $SubscriptionID)
        - Make API test calls to apis like management.azure.com / https://WORKSPACE.dev.azuresynapse.net
        - Try to connect to SQL and SQLOndemand APIs using port 1433

## Requirements
    - If want to run as script, might need
        - Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process
    -Import-Module DnsClient
    -Import-Module Az.Accounts -MinimumVersion 2.2.0
        - Install-Module -Name Az -Repository PSGallery -Force
    -Import-Module SQLServer
        - Install-Module -Name SqlServer -Repository PSGallery -Force"

## Data Collection
The software may collect anonymous information about you and your use of the software and send it to Microsoft. Microsoft may use this information to provide services and improve our products and services. You may turn off the telemetry as described in the repository. There are also some features in the software that may enable you and Microsoft to collect data from users of your applications. If you use these features, you must comply with applicable law, including providing appropriate notices to users of your applications together with a copy of Microsoft’s privacy statement. Our privacy statement is located at https://go.microsoft.com/fwlink/?LinkID=824704. You can learn more about data collection and use in the help documentation and our privacy statement. Your use of the software operates as your consent to these practices.

## Execution

### Option 1
    - Open Powershell ISE
    - Copy and paste script (Synapse-TestConnection.ps1)
    - Change variables
      - $WorkspaceName = 'WORKSPACENAME' # Enter your Synapse Workspace name. Not FQDN just name
      - $SubscriptionID = 'de41dc76-xxxx-xxxx-xxxx-xxxx'  # Subscription ID where Synapse Workspace is located
      - $DedicatedSQLPoolDBName = ''  # Add here DB name you are testing connection. If you keep it empty it will test connectivity agains master DB
      - $ServerlessPoolDBName = ''    # Add here DB name you are testing connection. If you keep it empty it will test connectivity agains master DB
      - $DisableAnonymousTelemetry = $false  # Set as $true if you don't want to send anonymous usage data to Microsoft

    - Execute the script

### Option 2
    - Copy (Synapse-TestConnection.ps1) script file to a folder

    - On Powershell copy below script 

        #------------------------------------------------------------------------------------------------------------------------------------------------------------
        $parameters = @{
            WorkspaceName = 'WORKSPACENAME' # Enter your Synapse Workspace name. Not FQDN just name
            SubscriptionID = 'de41dc76-xxxx-xxxx-xxxx-xxxx'  # Subscription ID where Synapse Workspace is located
            DedicatedSQLPoolDBName = ''  # Add here DB name you are testing connection. If you keep it empty it will test connectivity agains master DB
            ServerlessPoolDBName = ''  # Add here DB name you are testing connection. If you keep it empty it will test connectivity agains master DB
            DisableAnonymousTelemetry = $false  # Set as $true if you don't want to send anonymous usage data to Microsoft
        }
        
        $FilePath = 'C:\TEMP\Synapse-TestConnection.ps1'
        Invoke-Command -ScriptBlock ([Scriptblock]::Create((Get-Content -Path $FilePath -Raw))) -ArgumentList $parameters
        #------------------------------------------------------------------------------------------------------------------------------------------------------------

    - Change variables

    - Execute the script


## Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft trademarks or logos is subject to and must follow 
[Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general).
Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship.
Any use of third-party trademarks or logos are subject to those third-party's policies.


#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
#WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
