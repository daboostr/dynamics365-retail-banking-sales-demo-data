Import-Module Microsoft.Xrm.Data.Powershell

$conn = Connect-CrmOnline -ServerUrl "https://org9937c5ba.crm.dynamics.com" -ForceOAuth -Username "admin@D365DemoTSCE41978460.onmicrosoft.com"
if (-not ($conn -and $conn.IsReady)) {
  throw "Dataverse connection failed."
}

$fetch = @"
<fetch count="200">
  <entity name="msdyn_sequence">
    <attribute name="msdyn_sequenceid" />
    <attribute name="msdyn_name" />
    <attribute name="msdyn_type" />
    <attribute name="msdyn_regardingentityname" />
    <attribute name="msdyn_maxstepcount" />
    <attribute name="msdyn_cjodefinition" />
    <attribute name="statecode" />
    <attribute name="statuscode" />
    <attribute name="modifiedon" />
    <filter>
      <condition attribute="statecode" operator="eq" value="0" />
      <condition attribute="msdyn_name" operator="not-like" value="%SASEQ-%" />
    </filter>
    <order attribute="modifiedon" descending="true" />
  </entity>
</fetch>
"@

$rows = @((Get-CrmRecordsByFetch -conn $conn -Fetch $fetch).CrmRecords)
$profile = $rows | ForEach-Object {
  [PSCustomObject]@{
    id = $_.msdyn_sequenceid
    name = $_.msdyn_name
    type = [string]$_.msdyn_type
    regarding = $_.msdyn_regardingentityname
    maxstepcount = if ($_.msdyn_maxstepcount) { [int]$_.msdyn_maxstepcount } else { 0 }
    cjoLength = if ($_.msdyn_cjodefinition) { ([string]$_.msdyn_cjodefinition).Length } else { 0 }
    modifiedon = $_.modifiedon
  }
}

$profile |
  Sort-Object regarding, @{Expression='cjoLength';Descending=$true} |
  ConvertTo-Json -Depth 6
