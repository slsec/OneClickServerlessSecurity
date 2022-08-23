# Enable - Disable serverless security
*This Script allows a customer to enable or remove ServerlessSecurity Agent*

***Please note : The function apps will restart during enabling or disabling the agent***

# Method 1

1) Open Cloudshell and Run the command to dowload script to cloudshell
```
curl -LO "https://raw.githubusercontent.com/vikenparikh/OneClickServerlessSecurity/policyForScript/SSACloudShellMethod1.ps1" -LO "https://raw.githubusercontent.com/vikenparikh/OneClickServerlessSecurity/policyForScript/Policy.json"
```

2) Run the script by using the command on cloudshell
```
./SSACloudShellMethod1.ps1
```

3) Copy the SubscriptionId for the subscription you want to change and insert it when prompted by the script

4) Then enter 0 to Disable, 1 to Enable the ServerlessSecurity Agent and wait till the deployment completes

5) Check for Success - Check if the script run was successful without any errors

# Method 2

## Prerequisites : 

1) Create a User assigned managed Identity for the subscription - [link](https://ms.portal.azure.com/#create/Microsoft.ManagedIdentity]
Or use an existing one if it exists - [link](https://ms.portal.azure.com/#view/HubsExtension/BrowseResource/resourceType/Microsoft.ManagedIdentity%2FuserAssignedIdentities)

2) Check if the managed idenity has appropriate role permissions for the subscription - Navigate to Azure role assignments

3) Copy the Id of the Managed Identity - Go to Properties from the menu on the left - 
It will be of the format - /subscriptions/{subid}/resourcegroups/{res-group-id}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/{managed-id}

## To enable or disable the script :

1) User to click enable to enable ServerlessSecurity / User to click disable to disable ServerlessSecurity

>[![EnableServerlessSecurity](https://img.shields.io/static/v1?label=enable&message=ServerlessSecurity&color=green)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fvikenparikh%2FOneClickServerlessSecurity%2Fmain%2FenableTemplate.json)

>[![DisableServerlessSecurity](https://img.shields.io/static/v1?label=disable&message=ServerlessSecurity&color=red)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fvikenparikh%2FOneClickServerlessSecurity%2Fmain%2FdisableTemplate.json)

2) Select the subscription you would like to enable/disable ServerlessSecurity

3) Select the Resource group with the managed Identity that have permission to modify the subscription

4) Paste the Id of the Managed Identity that you found in the Properties

5) Click Review+Create -> Create

6) The user will have to wait for the deploynment to finish, upon successul,
the user can see ServerlessSecurity enabled / disabled.

7) Check for Success - Check if the deployment was successful 

# Effects on Resources and Subscriptions

Running either method of the onboarding script will have the following effects on your resources:
1) Register the resource provider 'Microsoft.PolicyInsights'
2) Add the application setting 'AZURE_FUNCTIONS_SECURITY_AGENT_ENABLED' to each Azure Function in your subscription
3) Assign a custom policy and associated remediation task, described below.

Running the disable command in this repository will remove application setting from all Azure Functions, remediation task, policy assignment and policy definition.

# Policy Overview
The Azure Policy Definition in this repository will be uploaded to your subscription and assigned to the subscription scope. Additionally, a remediation task will be created for all current resources. This policy takes several actions to onboard your Functions to the Azure Functions Security Agent.
Firstly, it creates the resource group 'mdc-slsec-rg' to house resources related to the functioning of the agent. These resources include:
1) A Log Analytics Workspace for each region you have a FunctionApp deployed in. This LA Workspace contains events to process from your Function, as well as debug logs
2) A Data Collection Endpoint per region, which defines where these logs go
3) A Data Collection Rule which defines log transformations
4) A User Assigned Identity with permissions to write to the LA Workspace. This identity is added to each of your Function Apps
5) A resource lock on the Identity to prevent accidental deletion.
Please do not modify or delete any of the resources in the mdc-slsec-rg, as this will stop the security agent from working. If you wish to disable the agent or delete the resources, please run the offboarding command described above.
