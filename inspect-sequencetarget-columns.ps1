Import-Module Microsoft.Xrm.Data.Powershell -ErrorAction Stop
$conn = Get-CrmConnection -InteractiveMode
$r = Get-CrmRecords -conn $conn -EntityLogicalName msdyn_sequencetarget -Fields * -TopCount 1
if($r.Count -lt 1){ Write-Output "NO_ROWS"; exit 0 }
$attrs = $r.CrmRecords[0].Attributes.Keys | Sort-Object
$attrs | ForEach-Object { $_ }
