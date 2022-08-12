@description('The resource Id of the managed Identity to use for deployment')
param managedIdentityForDeployment string

param utcValue string = utcNow()

@description('Disable Serverless security')
resource disablesecurity 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'disablesecurity'
  kind: 'AzurePowerShell'
  location: resourceGroup().location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityForDeployment}' : {}
    }
  }
  properties: {
    azPowerShellVersion: '7.2.5'
    retentionInterval: 'P1D'
    cleanupPreference: 'Always'
    forceUpdateTag: utcValue
    environmentVariables: [
      {
        name: 'toggle_option'
        secureValue: '0'
      }
      {
        name: 'subscription_id'
        secureValue: subscription().subscriptionId
      }
      {
        name: 'tenant_id'
        secureValue: subscription().tenantId
      }
    ]
    primaryScriptUri: 'https://raw.githubusercontent.com/vikenparikh/OneClickServerlessSecurity/main/SSAOneClickEnableMethod2.ps1'  
  }
}
