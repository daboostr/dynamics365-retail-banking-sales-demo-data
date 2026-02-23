Import-Module Microsoft.Xrm.Data.Powershell

$conn = Connect-CrmOnline -ServerUrl "https://org9937c5ba.crm.dynamics.com" -ForceOAuth -Username "admin@D365DemoTSCE41978460.onmicrosoft.com"
if (-not ($conn -and $conn.IsReady)) { throw "Connection failed" }

$entities = @("msdyn_sequencetargetstep", "msdyn_sequencetarget", "msdyn_sequencetemplate")
foreach ($e in $entities) {
  Write-Output "=== $e ==="
  Get-CrmEntityAttributes -conn $conn -EntityLogicalName $e |
    Select-Object LogicalName, AttributeType, RequiredLevel |
    Sort-Object LogicalName |
    Format-Table -AutoSize
}
