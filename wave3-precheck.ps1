Import-Module Microsoft.Xrm.Data.Powershell

$conn = Connect-CrmOnline -ServerUrl "https://org9937c5ba.crm.dynamics.com" -ForceOAuth -Username "admin@D365DemoTSCE41978460.onmicrosoft.com"
if (-not ($conn -and $conn.IsReady)) { throw "Dataverse connection failed." }

$state = Get-CrmEntityOptionSet -conn $conn lead statecode | ForEach-Object { $_.Items }
$status = Get-CrmEntityOptionSet -conn $conn lead statuscode | ForEach-Object { $_.Items }

[PSCustomObject]@{
  leadStateOptions = $state
  leadStatusOptions = $status
} | ConvertTo-Json -Depth 6
