# Enable - Disable serverless security
*This Script allows a customer to enable or remove ServerlessSecurity Agent*

***Please note : The function apps will Restart during enabling or disabling the agent. In case of any errors/interruptions, the script can be retried, and function apps could restart in each attempt. Make sure to enter the correct subscription id and secure key***


1) Open Cloudshell and Run the command to dowload script to cloudshell
```
curl -LO "https://raw.githubusercontent.com/vikenparikh/OneClickServerlessSecurity/main/SSACloudShellMethod1.ps1"
```
![image](https://user-images.githubusercontent.com/20373954/185518206-65a87986-b177-41fe-9501-8cc61f41b8d0.png)
![image](https://user-images.githubusercontent.com/20373954/185518266-8ba216a2-a02b-455c-a7fb-c12d43f3e88d.png)

2) Run the script by using the command on cloudshell
```
./CloudShellMethod1.ps1
```
![image](https://user-images.githubusercontent.com/20373954/185518120-550d6f20-ad4a-43ee-b3c2-81050fde5c01.png)

3) Copy the SubscriptionId for the subscription you want to change and insert it when prompted by the script

![image](https://user-images.githubusercontent.com/20373954/185519051-159fb921-71bb-4d1d-a18f-b770785e5cab.png)

4) Then enter 0 to Disable, 1 to Enable the ServerlessSecurity Agent

![image](https://user-images.githubusercontent.com/20373954/185519519-f8ef84a5-c076-4f9b-8697-31ade0965b1f.png)
![image](https://user-images.githubusercontent.com/20373954/185519700-f73e0ffb-cb19-4259-9944-348fac19ddc5.png)

5) (Only For Enabling the ServerlessSecurity Agent) Enter the provided secure key

6) Wait till the deployment completes and check if the script run was successful.

![image](https://user-images.githubusercontent.com/20373954/185520191-ac574c27-3d32-4ba3-89f4-9bba5b6c892d.png)
![image](https://user-images.githubusercontent.com/20373954/185520510-2b8768d3-6f39-4a40-9e01-cd125f88a11e.png)