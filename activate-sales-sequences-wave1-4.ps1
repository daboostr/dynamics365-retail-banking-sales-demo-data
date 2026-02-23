Import-Module Microsoft.Xrm.Data.Powershell

$conn = Connect-CrmOnline -ServerUrl "https://org9937c5ba.crm.dynamics.com" -ForceOAuth -Username "admin@D365DemoTSCE41978460.onmicrosoft.com"
if (-not ($conn -and $conn.IsReady)) {
  throw "Dataverse connection failed."
}

$ids = @(
  "62689e5b-8f0c-f111-8406-0022480b6bd9",
  "f9fe9661-8f0c-f111-8406-0022480b6bd9",
  "08ff9661-8f0c-f111-8406-0022480b6bd9",
  "0fff9661-8f0c-f111-8406-0022480b6bd9",
  "17ff9661-8f0c-f111-8406-0022480b6bd9",
  "1cff9661-8f0c-f111-8406-0022480b6bd9"
)

$results = @()
foreach ($id in $ids) {
  try {
    Set-CrmRecordState -conn $conn -EntityLogicalName msdyn_sequence -Id ([Guid]$id) -StateCode Active -StatusCode Active
    $results += [PSCustomObject]@{ id = $id; outcome = "Activated" }
  }
  catch {
    $results += [PSCustomObject]@{ id = $id; outcome = "ActivationFailed"; error = $_.Exception.Message }
  }
}

$results | ConvertTo-Json -Depth 6
