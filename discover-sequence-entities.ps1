Import-Module Microsoft.Xrm.Data.Powershell

$conn = Connect-CrmOnline -ServerUrl "https://org9937c5ba.crm.dynamics.com" -ForceOAuth -Username "admin@D365DemoTSCE41978460.onmicrosoft.com"
if (-not ($conn -and $conn.IsReady)) { throw "Connection failed" }

$entities = Get-CrmEntityAllMetadata -conn $conn -OnlyPublished $true -EntityFilters Entity
$entities |
  Where-Object {
    $_.LogicalName -match "sequence|salesacceler|accelerator|cadence|worklist|msdyn_sequ" -or
    ($_.DisplayName.UserLocalizedLabel.Label -and $_.DisplayName.UserLocalizedLabel.Label -match "Sequence|Sales Accelerator|Cadence")
  } |
  Sort-Object LogicalName |
  Select-Object LogicalName,
    @{N='DisplayName';E={ if ($_.DisplayName.UserLocalizedLabel) { $_.DisplayName.UserLocalizedLabel.Label } else { '' } }} |
  Format-Table -AutoSize
