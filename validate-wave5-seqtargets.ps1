Import-Module Microsoft.Xrm.Data.Powershell
$conn = Connect-CrmOnline -ServerUrl "https://org9937c5ba.crm.dynamics.com" -ForceOAuth -Username "admin@D365DemoTSCE41978460.onmicrosoft.com"
$batchTag = "RBP5-20260217-224507"
$fetch = @"
<fetch>
  <entity name="msdyn_sequencetarget">
    <attribute name="msdyn_sequencetargetid" />
    <attribute name="msdyn_name" />
    <attribute name="msdyn_parentsequence" />
    <attribute name="msdyn_appliedsequenceinstance" />
    <attribute name="msdyn_target" />
    <attribute name="createdon" />
    <filter>
      <condition attribute="msdyn_name" operator="like" value="%$batchTag%" />
    </filter>
    <order attribute="createdon" descending="true" />
  </entity>
</fetch>
"@
$r = Get-CrmRecordsByFetch -conn $conn -Fetch $fetch
$rows = @()
if($r -and $r.CrmRecords){
  $rows = @($r.CrmRecords | ForEach-Object {
    [PSCustomObject]@{
      msdyn_sequencetargetid = $_.msdyn_sequencetargetid
      msdyn_name = $_.msdyn_name
      msdyn_parentsequence = if($_.msdyn_parentsequence_Property){ $_.msdyn_parentsequence_Property.Value.Id } else { $null }
      msdyn_appliedsequenceinstance = if($_.msdyn_appliedsequenceinstance_Property){ $_.msdyn_appliedsequenceinstance_Property.Value.Id } else { $null }
      msdyn_target = if($_.msdyn_target_Property){ $_.msdyn_target_Property.Value.Id } else { $null }
      createdon = $_.createdon
    }
  })
}
$outCsv = "C:\Users\efbarbat\d365-model\wave5-sequencetarget-validation-$batchTag.csv"
$rows | Export-Csv -Path $outCsv -NoTypeInformation -Encoding UTF8
[PSCustomObject]@{
  batchTag = $batchTag
  validatedCount = $rows.Count
  outputCsv = $outCsv
} | ConvertTo-Json -Depth 5
