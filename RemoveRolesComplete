
#Connect Azure Account
Connect-AzAccount

# Connect to Microsoft Graph with least required permission scope
Connect-MgGraph -Scopes Application.Read.All, AppRoleAssignment.ReadWrite.All, RoleManagement.ReadWrite.Directory

### Store Managed Identity Name
$ManagedIdentityName = (Get-AZAutomationAccount | Select-Object -ExpandProperty AutomationAccountName)
#Retrieve Managed Identity ObjectId
$ManagedIdentity = (Get-MgServicePrincipal -Filter "DisplayName eq '$ManagedIdentityName'").Id
#Identify Id's of App Roles Assigned
$AppRoleId =(Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $ManagedIdentity).Id
#Identify Unified Resource Assignment ID 
$URAId=(Get-MgRoleManagementDirectoryRoleAssignment -Filter "PrincipalId   eq '$ManagedIdentity'").Id
#Remove Application Roles
foreach ($ari in $AppRoleId){
    Remove-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $ManagedIdentity -AppRoleAssignmentId $ari
}
#Remove Management Role
foreach ($urid in $URAId){
    Remove-MgRoleManagementDirectoryRoleAssignment -UnifiedRoleAssignmentId $urid
}

#Remove Storage Account Contributor to the Azure Subscription Subscription
$SubscriptionId = (Get-AZAutomationAccount | Select-Object -ExpandProperty SubscriptionId)
$ResourceGroup = (Get-AZAutomationAccount | Select-Object -ExpandProperty ResourceGroupName)
$Scope = (Get-AzStorageAccount -ResourceGroupName $ResourceGroup -Name $ManagedIdentityName).id
$ManagedIdentity = (Get-MgServicePrincipal -Filter "DisplayName eq '$ManagedIdentityName'")

$AZRoles = "Storage Account Contributor", "Storage Blob Data Contributor"

foreach ($AZRole in $AZRoles){
    Remove-AzRoleAssignment -ObjectId $ManagedIdentity.Id -RoleDefinitionName $AZRole -Scope $Scope
}
