#Exit Script on error
$ErrorActionPreference = "Stop"
$WarningPrefBackup = $WarningPreference
$WarningPreference = 'SilentlyContinue'

# Get the subscription_id from managed identity and set it to a context
$selected_subscription_id = $Env:subscription_id

$PolicyName = "DefenderForServerless"
$PolicyScope = "/subscriptions/$($selected_subscription_id)"

# Get the tenant_id from managed identity and set it to a context
$tenant_id = $Env:tenant_id

Set-AzContext -SubscriptionId $selected_subscription_id -Tenant $tenant_id

# Get all functions within the subscription
$function_app_list = Get-AzFunctionApp -SubscriptionId $selected_subscription_id

# Get toggle_option from the $Env variable
$toggle_option = $Env:toggle_option

# For each function from $function_app_list, 
# set AZURE_FUNCTIONS_SECURITY_AGENT_ENABLED to 1 to enable the agent.
# remove AZURE_FUNCTIONS_SECURITY_AGENT_ENABLED to disable the agent.
switch ($toggle_option) {

    # Remove Configuration Switch to Disable
    "0" {
        For ($Cntr = 0 ; $Cntr -lt $($function_app_list.Count); $Cntr++) {
            Remove-AzFunctionAppSetting -Name $function_app_list[$Cntr].Name -ResourceGroupName $function_app_list[$Cntr].ResourceGroupName -AppSettingName "AZURE_FUNCTIONS_SECURITY_AGENT_ENABLED" | Out-Null
        };
        Write-Host "Disabled AZURE_FUNCTIONS_SECURITY_AGENT for $($function_app_list.Count) Functions with Subscription ID is: $selected_subscription_id";
        Remove-AzPolicyAssignment -Name $PolicyName -Scope $PolicyScope
        Remove-AzResourceLock -LockName 'CanNotDeleteLock-mdc-slsec-identity' -ResourceGroupName 'mdc-slsec-rg' -ResourceName 'mdc-slsec-identity' -ResourceType 'Microsoft.ManagedIdentity/userAssignedIdentities' -Force

        Write-Host "Cleaning up resources. This may take a while..."
        Remove-AzPolicyDefinition -Name $PolicyName -Force
        Remove-AzResourceGroup -Name 'mdc-slsec-rg' -Force
        break
    }

    # Update Configuration to Enable
    "1" { 
        Register-AzResourceProvider -ProviderNamespace 'Microsoft.PolicyInsights' | Out-Null  
        $PolicyDefinition = New-AzPolicyDefinition -Name $PolicyName -Policy Policy.json -Description $PolicyDescription | Out-Null
        $PolicyAssignment = New-AzPolicyAssignment -Name $PolicyName -Description $PolicyDescription -Scope $PolicyScope -PolicyDefinition $PolicyDefinition -IdentityType SystemAssigned -Location westus2 | Out-Null
        Start-AzPolicyRemediation -PolicyAssignmentId $PolicyAssignment.ResourceId -Name $PolicyName -ParallelDeploymentCount 1 -ResourceDiscoveryMode ReEvaluateCompliance | Out-Null

        For ($Cntr = 0 ; $Cntr -lt $($function_app_list.Count); $Cntr++) {
            Update-AzFunctionAppSetting -Name $function_app_list[$Cntr].Name -ResourceGroupName $function_app_list[$Cntr].ResourceGroupName -AppSetting @{"AZURE_FUNCTIONS_SECURITY_AGENT_ENABLED" = "1" } | Out-Null
        };
        Write-Host "Enabled AZURE_FUNCTIONS_SECURITY_AGENT for $($function_app_list.Count) Functions with Subscription ID is: $selected_subscription_id"; 
        break 
    }

    # Defaults to break the switch, without any changes made
    default { break }
}

$Env::SetEnvironmentVariable("AZURE_FUNCTIONS_SECURITY_AGENT_ENABLED", $null, "User")
$WarningPreference = $WarningPrefBackup