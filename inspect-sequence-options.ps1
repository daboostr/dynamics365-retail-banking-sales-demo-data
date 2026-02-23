Import-Module Microsoft.Xrm.Data.Powershell

$conn = Connect-CrmOnline -ServerUrl "https://org9937c5ba.crm.dynamics.com" -ForceOAuth -Username "admin@D365DemoTSCE41978460.onmicrosoft.com"
if (-not ($conn -and $conn.IsReady)) { throw "Connection failed" }

Get-CrmEntityOptionSet -conn $conn msdyn_sequence msdyn_type | ForEach-Object { $_.Items }
