# Enable - Disable serverless security
*This script allows for enabling and disabling the Serverless Security Agent*

***Please note : All function apps will Restart during enabling or disabling the agent. In the case of any errors/interruptions the script can be retried and Function Apps may restart in each attempt. Make sure to enter the correct subscription id and secure key***


1) Open Cloud Shell and run the following command:
```
curl -LO "https://raw.githubusercontent.com/vikenparikh/OneClickServerlessSecurity/main/SSAOnboard.ps1;curl -LO "https://raw.githubusercontent.com/vikenparikh/OneClickServerlessSecurity/main/Policy.json"
```
![image](https://user-images.githubusercontent.com/20373954/185518206-65a87986-b177-41fe-9501-8cc61f41b8d0.png)
![image](https://user-images.githubusercontent.com/20373954/185518266-8ba216a2-a02b-455c-a7fb-c12d43f3e88d.png)

2) Excecute the script on Cloud Shell:
```
./SSAOnboard.ps1
```
![image](https://user-images.githubusercontent.com/20373954/185518120-550d6f20-ad4a-43ee-b3c2-81050fde5c01.png)

3) Copy your SubscriptionId for the subscription you want to change and insert it when prompted.

![image](https://user-images.githubusercontent.com/20373954/185519051-159fb921-71bb-4d1d-a18f-b770785e5cab.png)

4) Enter 0 to Disable or 1 to Enable the Serverless Security Agent.

![image](https://user-images.githubusercontent.com/20373954/185519519-f8ef84a5-c076-4f9b-8697-31ade0965b1f.png)
![image](https://user-images.githubusercontent.com/20373954/185519700-f73e0ffb-cb19-4259-9944-348fac19ddc5.png)

5) (Only For Enabling the ServerlessSecurity Agent) Enter the provided secure key

6) Wait until the deployment completes and check if the script was successful.

![image](https://user-images.githubusercontent.com/20373954/185520191-ac574c27-3d32-4ba3-89f4-9bba5b6c892d.png)
![image](https://user-images.githubusercontent.com/20373954/185520510-2b8768d3-6f39-4a40-9e01-cd125f88a11e.png)

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
