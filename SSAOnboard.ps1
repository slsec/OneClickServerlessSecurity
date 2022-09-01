$ErrorActionPreferenceBackup = $ErrorActionPreference
$WarningPrefBackup = $WarningPreference
$OldAzContext = Get-AzContext
$OldAzContextSubscriptionId = $OldAzContext[0].Subscription.Id

try {
    #Exit Script on error
    $ErrorActionPreference = "Stop"
    $WarningPreference = 'SilentlyContinue'

    # Describe to the User what that Script does
    Write-Host "This is a Script to enable or disable Defender for Serverless Application (Azure Functions) within a Subscription. `n Prior to running this script please contact Microsoft's Servelress Security team to initiate the onboarding process for a specific subscription and recieve the subscription's specific configuration key."

    # Prompt Customer to enter the subscription_id and set it to a context (Remove extra whitespaces at start/end)
    $selected_subscription_id = (Read-Host -Prompt "`n Enter the subscription_id you would like to enable/disable the Defender for Serverless Application for" -MaskInput).Trim()
    Set-AzContext -Subscription $selected_subscription_id | Out-Null

    $PolicyName = "DefenderForServerless"
    $PolicyScope = "/subscriptions/$($selected_subscription_id)"

    # For each function from $function_app_list, 
    # set AZURE_FUNCTIONS_SECURITY_AGENT_ENABLED to 1 to enable the agent.
    # remove AZURE_FUNCTIONS_SECURITY_AGENT_ENABLED to disable the agent.
    # (Remove extra whitespaces at start/end)
    $toggle_option = (Read-Host -Prompt "`n Enter 0 to Disable, 1 to Enable, any other input will do nothing and exit.`n Note: enablement/disablement of the defender will result in function restart....").Trim()

    if ($toggle_option -eq 1) {
        # Subscription's specific configuration key (Remove extra whitespaces at start/end)
        $ss_config_value = (Read-Host -Prompt "`n Enter subscription's specific configuration key." -MaskInput).Trim()
    }

    Write-Host "`n Selected Subscription ID is: $selected_subscription_id"
    Write-Host "`n Entered subscription's specific configuration key is: $ss_config_value"
    
    if([string]::IsNullOrWhiteSpace($ss_config_value)) {
        Write-Host "The subscription specific configuration key cannot be empty.`n The Script will exit now, Please Run the script again to retry!"
        Exit
    }

    $confirm_deploy = (Read-Host -Prompt "`n Enter Yes to Confirm the Change, any other input will exit").Trim()
    if($confirm_deploy -ne "Yes" -and $confirm_deploy -ne "yes") {
        Write-Host "The Script will Now Exit. Please Run the script again to retry!"
        Exit
    }

    Write-Host "Please wait while deployment is complete..."

    # Get all functions within the subscription
    $function_app_list = Get-AzFunctionApp -SubscriptionId $selected_subscription_id

    switch ($toggle_option) {

        # Remove Configuration Switch to Disable
        0 {
            $PrcntComplete = 0
            $TotalFunctions = $function_app_list.Count
            
            #Create Function Jobs in Background
            $FunctionChangeJobs = New-Object System.Collections.ArrayList
            For ($Cntr = 0 ; $Cntr -lt $TotalFunctions; $Cntr++) {
                $FunctionChangeJobBlockOp = {
                    param($function_app_list, $Cntr)
                    try {
                        Remove-AzFunctionAppSetting -Name $function_app_list[$Cntr].Name -ResourceGroupName $function_app_list[$Cntr].ResourceGroupName -AppSettingName "AZURE_FUNCTIONS_SECURITY_AGENT_ENABLED", "SERVERLESS_SECURITY_OFFLOAD_TO_EH", "SERVERLESS_SECURITY_CONFIG" | Out-Null
                    }
                    catch {
                        Write-Host ("Error Disabling Defender for Function - "+$function_app_list[$Cntr].Name.ToString()) -ForegroundColor Red;
                    }
                }
                #Add To a jobs list to track completion and clean up
                $FunctionChangeJobs.Add((Start-ThreadJob -Scriptblock $FunctionChangeJobBlockOp -ThrottleLimit 5 -ArgumentList $function_app_list,$Cntr).Id) | Out-Null;
            }

            #Track Jobs Completion
            $TotalFunctionChangeJobs = $FunctionChangeJobs.Count
            $TotalFunctionsRemaining = $FunctionChangeJobs.Count
            $CheckCompleted = "Completed"
            while ($TotalFunctionsRemaining -gt 0) {
                $TotalFunctionsRemaining = $FunctionChangeJobs.Count
                For ($Cntr = 0 ; $Cntr -lt $TotalFunctionChangeJobs; $Cntr++) {
                    $ThisJob = Get-Job $FunctionChangeJobs[$Cntr]
                    if($ThisJob.State -eq $CheckCompleted)
                        {
                            $TotalFunctionsRemaining -=1
                            if($ThisJob.HasMoreData){
                                $ReceiveJobData = Receive-Job $FunctionChangeJobs[$Cntr]
                                if($null -ne $ReceiveJobData) 
                                    {Write-Host $ReceiveJobData}
                            }
                        }
                }
                $PrcntComplete = (($TotalFunctionChangeJobs-$TotalFunctionsRemaining)*100/$TotalFunctionChangeJobs)
                Write-Progress -Id 2 -Activity "Disabling Defender for Functions" -Status "$($TotalFunctionChangeJobs-$TotalFunctionsRemaining)/$TotalFunctionChangeJobs Functions completed" -PercentComplete $PrcntComplete -CurrentOperation ("Disabling Defender for $TotalFunctionsRemaining Functions Remaining")
            }
            # Clean Jobs
            For ($Cntr = 0 ; $Cntr -lt $TotalFunctionChangeJobs; $Cntr++) {
                Remove-Job $FunctionChangeJobs[$Cntr]
            }
            $FunctionChangeJobs.Clear()

            Remove-AzPolicyAssignment -Name $PolicyName -Scope $PolicyScope
            Remove-AzPolicyDefinition -Name $PolicyName -Force

            Write-Host "Cleaning up resources. This may take a while..."
            Remove-AzResourceLock -LockName 'CanNotDeleteLock-mdc-slsec-identity' -ResourceGroupName 'mdc-slsec-rg' -ResourceName 'mdc-slsec-identity' -ResourceType 'Microsoft.ManagedIdentity/userAssignedIdentities' -Force
            Remove-AzResourceGroup -Name 'mdc-slsec-rg' -Force
            Write-Host "Disabled Defender for Serverless Security Successfully";
            break;
        }

        # Update Configuration to Enable
        1 { 
            Register-AzResourceProvider -ProviderNamespace 'Microsoft.PolicyInsights' | Out-Null # Needed to create policies
            $PolicyDescription = "Policy to deploy resources required to enable the Defender for Serverless product"
            $PolicyDefinition = New-AzPolicyDefinition -Name $PolicyName -Policy Policy.json -Description $PolicyDescription
            # The policy assignment needs to be created early on so its identity has time to propagate 
            $PolicyAssignment = New-AzPolicyAssignment -Name $PolicyName -Description $PolicyDescription -Scope $PolicyScope -PolicyDefinition $PolicyDefinition -Location westus2 -AssignIdentity
            
            $UpdateFunctionAppSetting = @{}
            $UpdateFunctionAppSetting.Add("AZURE_FUNCTIONS_SECURITY_AGENT_ENABLED", "1")
            $UpdateFunctionAppSetting.Add("SERVERLESS_SECURITY_OFFLOAD_TO_EH", "True")
            $UpdateFunctionAppSetting.Add("SERVERLESS_SECURITY_CONFIG", $ss_config_value)

            $PrcntComplete = 0
            $TotalFunctions = $function_app_list.Count
            
            #Create Function Jobs in Background
            $FunctionChangeJobs = New-Object System.Collections.ArrayList
            For ($Cntr = 0 ; $Cntr -lt $TotalFunctions; $Cntr++) {
                $FunctionChangeJobBlockOp = {
                    param($function_app_list,$UpdateFunctionAppSetting,$Cntr)
                    try {
                        Update-AzFunctionAppSetting -Name $function_app_list[$Cntr].Name -ResourceGroupName $function_app_list[$Cntr].ResourceGroupName -AppSetting $UpdateFunctionAppSetting | Out-Null;
                        }
                    catch {
                        Write-Host ("Error Enabling Defender for Function - "+$function_app_list[$Cntr].Name.ToString()) -ForegroundColor Red;
                    }
                }
                #Add To a jobs list to track completion and clean up
                $FunctionChangeJobs.Add((Start-ThreadJob -Scriptblock $FunctionChangeJobBlockOp -ThrottleLimit 5 -ArgumentList $function_app_list,$UpdateFunctionAppSetting,$Cntr).Id) | Out-Null;
            }

            #Track Jobs Completion
            $TotalFunctionChangeJobs = $FunctionChangeJobs.Count
            $TotalFunctionsRemaining = $FunctionChangeJobs.Count
            $CheckCompleted = "Completed"
            while ($TotalFunctionsRemaining -gt 0) {
                $TotalFunctionsRemaining = $FunctionChangeJobs.Count
                For ($Cntr = 0 ; $Cntr -lt $TotalFunctionChangeJobs; $Cntr++) {
                    $ThisJob = Get-Job $FunctionChangeJobs[$Cntr]
                    if($ThisJob.State -eq $CheckCompleted)
                        {
                            $TotalFunctionsRemaining -=1
                            if($ThisJob.HasMoreData){
                                $ReceiveJobData = Receive-Job $FunctionChangeJobs[$Cntr]
                                if($null -ne $ReceiveJobData) 
                                    {Write-Host $ReceiveJobData}
                            }
                        }
                }
                $PrcntComplete = (($TotalFunctionChangeJobs-$TotalFunctionsRemaining)*100/$TotalFunctionChangeJobs)
                Write-Progress -Id 2 -Activity "Enabling Defender for Functions" -Status "$($TotalFunctionChangeJobs-$TotalFunctionsRemaining)/$TotalFunctionChangeJobs Functions completed" -PercentComplete $PrcntComplete -CurrentOperation ("Enabling Defender for $TotalFunctionsRemaining Functions Remaining")
            }
            # Clean Jobs
            For ($Cntr = 0 ; $Cntr -lt $TotalFunctionChangeJobs; $Cntr++) {
                Remove-Job $FunctionChangeJobs[$Cntr]
            }
            $FunctionChangeJobs.Clear()
            
            # https://docs.microsoft.com/en-us/azure/governance/policy/how-to/remediate-resources?tabs=azure-powershell#grant-permissions-to-the-managed-identity-through-defined-roles
            $RoleDefinitionIds = $PolicyDefinition.Properties.policyRule.then.details.roleDefinitionIds 
            if ($RoleDefinitionIds.Count -gt 0) {
                $RoleDefinitionIds | ForEach-Object {
                    $RoleDefId = $_.Split("/") | Select-Object -Last 1
                    try {
                        New-AzRoleAssignment -Scope $PolicyScope -ObjectId $PolicyAssignment.Identity.PrincipalId -RoleDefinitionId $RoleDefId
                    }
                    catch [Microsoft.Azure.Management.Authorization.Models.ErrorResponseException] {
                        "Role Assingment $RoleDefId already exists. Continuing"
                    }
                }
            }
            Start-AzPolicyRemediation -PolicyAssignmentId $PolicyAssignment.ResourceId -Name $PolicyName -ParallelDeploymentCount 1 -ResourceDiscoveryMode ReEvaluateCompliance
            Write-Host "Enabled Defender for Serverless Security Successfully"; 
            break;
        }

        # Defaults to break the switch, without any changes made
        default { break }
    }
}
catch {
    Write-Host "Error, Please try again!"
}

finally {
    # Reset preferenceS and context
    if($WarningPrefBackup) {$WarningPreference = $WarningPrefBackup}
    if($ErrorActionPreferenceBackup) {$ErrorActionPreferenceBackup = $ErrorActionPreferenceBackup}
    if($OldAzContextSubscriptionId) {Set-AzContext -Subscription $OldAzContextSubscriptionId}
}