Import-Module Microsoft.Xrm.Data.Powershell
$conn = Connect-CrmOnline -ServerUrl "https://org9937c5ba.crm.dynamics.com" -ForceOAuth -Username "admin@D365DemoTSCE41978460.onmicrosoft.com"
$id=[Guid]"c06ffaeb-4f8f-f011-b4cc-000d3a5952f0"
$r=Get-CrmRecord -conn $conn -EntityLogicalName msdyn_sequencetarget -Id $id -Fields msdyn_name,msdyn_parentsequence,msdyn_appliedsequenceinstance,msdyn_target,msdyn_targetidtype,msdyn_regarding,msdyn_sequencetargetuniquekey
"name=$($r.msdyn_name)"
"parent=$($r.msdyn_parentsequence_Property.Value.Id)"
"applied=$($r.msdyn_appliedsequenceinstance_Property.Value.Id)"
"target=$($r.msdyn_target_Property.Value.Id)"
"targetidtype=$($r.msdyn_targetidtype)"
"regarding=$($r.msdyn_regarding)"
"ukey=$($r.msdyn_sequencetargetuniquekey)"
