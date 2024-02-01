#Install Graph Module
Install-Module Microsoft.Graph -Scope CurrentUser
#Install Azure Module
Install-Module Az -Scope CurrentUser

#Connect Azure Account
Connect-AzAccount

# Connect to Microsoft Graph with least required permission scope
Connect-MgGraph -Scopes Application.Read.All, AppRoleAssignment.ReadWrite.All, RoleManagement.ReadWrite.Directory


### Store Managed Identity Name and Permissions
$ManagedIdentityName = (Get-AZAutomationAccount | Select-Object -ExpandProperty AutomationAccountName)
$Gpermissions = "Directory.Read.All", "GroupMember.Read.All", "Organization.Read.All", "Policy.Read.All", "RoleManagement.Read.Directory", "User.Read.All", "Sites.FullControl.All", "PrivilegedEligibilitySchedule.Read.AzureADGroup"
$EXpermission = "Exchange.ManageAsApp"

# Get service principal and roles
$getGPerms = (Get-MgServicePrincipal -Filter "AppId eq '00000003-0000-0000-c000-000000000000'").approles | Where {$_.Value -in $Gpermissions}
$ManagedIdentity = (Get-MgServicePrincipal -Filter "DisplayName eq '$ManagedIdentityName'")
$GraphID = (Get-MgServicePrincipal -Filter "AppId eq '00000003-0000-0000-c000-000000000000'").id
$getExPerms = (Get-MgServicePrincipal -Filter "AppId eq '00000002-0000-0ff1-ce00-000000000000'").approles | Where {$_.Value -in $Expermission}
$ExId = (Get-MgServicePrincipal -Filter "AppId eq '00000002-0000-0ff1-ce00-000000000000'").id

# Assign roles for Graph
foreach ($perm in $getGPerms){
    New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $ManagedIdentity.Id -PrincipalId $ManagedIdentity.Id -ResourceId $GraphID -AppRoleId $perm.id
}

#Assign Role for Exchange
New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $ManagedIdentity.Id -PrincipalId $ManagedIdentity.Id -ResourceId $ExID -AppRoleId $getExPerms.id

# Assign Global Reader in Tenant
$roleId = (Get-MgRoleManagementDirectoryRoleDefinition -Filter "DisplayName eq 'Global Reader'").id

New-MgRoleManagementDirectoryRoleAssignment -PrincipalId $ManagedIdentity.id -RoleDefinitionid $roleid -DirectoryScopeid "/"

#Assign Storage Account Contributor to the Azure Subscription Subscription
$SubscriptionId = (Get-AZAutomationAccount | Select-Object -ExpandProperty SubscriptionId)
$ResourceGroup = (Get-AZAutomationAccount | Select-Object -ExpandProperty ResourceGroupName)
$Scope = (Get-AzStorageAccount -ResourceGroupName $ResourceGroup -Name $ManagedIdentityName).id
$ManagedIdentity = (Get-MgServicePrincipal -Filter "DisplayName eq '$ManagedIdentityName'")

$AZRoles = "Storage Account Contributor", "Storage Blob Data Contributor"

foreach ($AZRole in $AZRoles){
    New-AzRoleAssignment -ApplicationId $ManagedIdentity.AppId -RoleDefinitionName $AZRole -Scope $Scope
}
