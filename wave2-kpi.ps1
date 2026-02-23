Import-Module Microsoft.Xrm.Data.Powershell

$conn = Connect-CrmOnline -ServerUrl "https://org9937c5ba.crm.dynamics.com" -ForceOAuth -Username "admin@D365DemoTSCE41978460.onmicrosoft.com"
if (-not ($conn -and $conn.IsReady)) {
  throw "Dataverse connection failed."
}

$batchTag = "RBP2-20260217-211711"
$fetch = @"
<fetch>
  <entity name="opportunity">
    <attribute name="opportunityid" />
    <attribute name="name" />
    <attribute name="statecode" />
    <attribute name="estimatedvalue" />
    <filter>
      <condition attribute="name" operator="like" value="%$batchTag%" />
    </filter>
  </entity>
</fetch>
"@

$result = Get-CrmRecordsByFetch -conn $conn -Fetch $fetch
$records = @($result.CrmRecords)

$items = foreach ($record in $records) {
  $branch = "Unknown"
  if ($record.name -match "\[(Downtown|Uptown|Westside|Lakeshore)\]") {
    $branch = $matches[1]
  }

  [PSCustomObject]@{
    branch = $branch
    state = [string]$record.statecode
    value = if ($record.estimatedvalue) { [decimal]$record.estimatedvalue.Value } else { 0 }
  }
}

$kpi = $items | Group-Object branch | ForEach-Object {
  $group = $_.Group
  [PSCustomObject]@{
    branch = $_.Name
    opportunities = $group.Count
    won = (@($group | Where-Object { $_.state -eq "Won" })).Count
    lost = (@($group | Where-Object { $_.state -eq "Lost" })).Count
    open = (@($group | Where-Object { $_.state -eq "Open" })).Count
    pipelineValue = ($group | Measure-Object -Property value -Sum).Sum
  }
}

[PSCustomObject]@{
  batchTag = $batchTag
  opportunities = $records.Count
  branchKpi = $kpi
} | ConvertTo-Json -Depth 6
