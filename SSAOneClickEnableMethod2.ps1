#Exit Script on error
$ErrorActionPreference = "Stop"
$WarningPrefBackup = $WarningPreference
$WarningPreference = 'SilentlyContinue'

# Get the subscription_id from managed identity and set it to a context
$selected_subscription_id = $Env:subscription_id

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
"0" { For ($Cntr = 0 ; $Cntr -lt $($function_app_list.Count); $Cntr++) {
Remove-AzFunctionAppSetting -Name $function_app_list[$Cntr].Name -ResourceGroupName $function_app_list[$Cntr].ResourceGroupName -AppSettingName "AZURE_FUNCTIONS_SECURITY_AGENT_ENABLED" | Out-Null
};Write-Host "Disabled AZURE_FUNCTIONS_SECURITY_AGENT for $($function_app_list.Count) Functions with Subscription ID is: $selected_subscription_id"; break }

# Update Configuration to Enable
"1" { 
Register-AzResourceProvider -ProviderNamespace 'Microsoft.PolicyInsights'    
New-AzPolicyDefinition -Name "DefenderForServerless" -Description "Policy to deploy resources required to enable the Defender for Serverless product" -Policy <path_to_policy.json> -Mode "indexed"
New-AzPolicyAssignment -Name "DefenderForServerless" -Description "Policy to deploy resources required to enable the Defender for Serverless product" -Scope "Subscription" -PolicyDefinition <pol_def_id> -AssignIdentity

Start-AzPolicyRemediation -PolicyAssignmentId "<pol_assingment_id>" -Name "DefenderForServerless" -ParallelDeploymentCount 1 -ResourceDiscoveryMode ReEvaluateCompliance


For ($Cntr = 0 ; $Cntr -lt $($function_app_list.Count); $Cntr++) {
Update-AzFunctionAppSetting -Name $function_app_list[$Cntr].Name -ResourceGroupName $function_app_list[$Cntr].ResourceGroupName -AppSetting @{"AZURE_FUNCTIONS_SECURITY_AGENT_ENABLED" = "1"} | Out-Null
};
Write-Host "Enabled AZURE_FUNCTIONS_SECURITY_AGENT for $($function_app_list.Count) Functions with Subscription ID is: $selected_subscription_id"; 
break }

# Defaults to break the switch, without any changes made
default {break}
}

$Env::SetEnvironmentVariable("AZURE_FUNCTIONS_SECURITY_AGENT_ENABLED",$null,"User")
$WarningPreference = $WarningPrefBackup