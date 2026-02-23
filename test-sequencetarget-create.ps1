Import-Module Microsoft.Xrm.Data.Powershell

$conn = Connect-CrmOnline -ServerUrl "https://org9937c5ba.crm.dynamics.com" -ForceOAuth -Username "admin@D365DemoTSCE41978460.onmicrosoft.com"
if (-not ($conn -and $conn.IsReady)) { throw "Dataverse connection failed." }

$sequenceId = [Guid]"0fff9661-8f0c-f111-8406-0022480b6bd9" # lead activation
$targetLeadId = [Guid]"f9a808f1-910c-f111-8406-0022480b6bd9" # wave5 lead

Write-Output "Attempt 1: EntityReference for msdyn_target"
try {
  $id1 = New-CrmRecord -conn $conn -EntityLogicalName msdyn_sequencetarget -Fields @{
    msdyn_name = "Wave5 Test SequenceTarget 1"
    msdyn_parentsequence = New-CrmEntityReference -EntityLogicalName msdyn_sequence -Id $sequenceId
    msdyn_target = New-CrmEntityReference -EntityLogicalName lead -Id $targetLeadId
    msdyn_regarding = "Wave5Test"
  }
  Write-Output "Created with EntityReference: $id1"
} catch {
  Write-Output "Attempt1Failed"
  Write-Output $_.Exception.Message
  if ($_.ErrorDetails) { Write-Output $_.ErrorDetails.Message }
}

Write-Output "Attempt 2: JSON payload style for msdyn_target"
try {
  $targetJson = '{"etn":"lead","id":"' + $targetLeadId + '"}'
  $id2 = New-CrmRecord -conn $conn -EntityLogicalName msdyn_sequencetarget -Fields @{
    msdyn_name = "Wave5 Test SequenceTarget 2"
    msdyn_parentsequence = New-CrmEntityReference -EntityLogicalName msdyn_sequence -Id $sequenceId
    msdyn_target = $targetJson
    msdyn_targetidtype = "lead"
    msdyn_regarding = "Wave5Test"
  }
  Write-Output "Created with JSON target: $id2"
} catch {
  Write-Output "Attempt2Failed"
  Write-Output $_.Exception.Message
  if ($_.ErrorDetails) { Write-Output $_.ErrorDetails.Message }
}
