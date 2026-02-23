Import-Module Microsoft.Xrm.Data.Powershell

$conn = Connect-CrmOnline -ServerUrl "https://org9937c5ba.crm.dynamics.com" -ForceOAuth -Username "admin@D365DemoTSCE41978460.onmicrosoft.com"
if (-not ($conn -and $conn.IsReady)) { throw "Dataverse connection failed." }

$batchTag = "RBP5-" + (Get-Date -Format "yyyyMMdd-HHmmss")

$sequenceIds = [ordered]@{
  opportunity = [Guid]"f9fe9661-8f0c-f111-8406-0022480b6bd9"
  lead        = [Guid]"0fff9661-8f0c-f111-8406-0022480b6bd9"
  contact     = [Guid]"1cff9661-8f0c-f111-8406-0022480b6bd9"
}

$sequenceDefinitionIds = [ordered]@{
  opportunity = [Guid]"62689e5b-8f0c-f111-8406-0022480b6bd9"
  lead        = [Guid]"08ff9661-8f0c-f111-8406-0022480b6bd9"
  contact     = [Guid]"17ff9661-8f0c-f111-8406-0022480b6bd9"
}

function Get-RecordsByFetch {
  param([string]$Fetch)
  $r = Get-CrmRecordsByFetch -conn $conn -Fetch $Fetch
  if ($r -and $r.CrmRecords) { return @($r.CrmRecords) }
  return @()
}

function Get-TargetOwnerId {
  param(
    [string]$TargetEntity,
    [Guid]$TargetId
  )

  try {
    $record = Get-CrmRecord -conn $conn -EntityLogicalName $TargetEntity -Id $TargetId -Fields ownerid
    if ($record -and $record.ownerid_Property -and $record.ownerid_Property.Value -and $record.ownerid_Property.Value.Id) {
      return [Guid]$record.ownerid_Property.Value.Id
    }
  }
  catch {
  }

  $pk = "$($TargetEntity)id"
  $fetch = @"
<fetch count="1">
  <entity name="$TargetEntity">
    <attribute name="$pk" />
    <attribute name="ownerid" />
    <filter>
      <condition attribute="$pk" operator="eq" value="$TargetId" />
    </filter>
  </entity>
</fetch>
"@

  $rows = Get-RecordsByFetch -Fetch $fetch
  if ($rows.Count -lt 1) { return $null }
  if ($rows[0].ownerid_Property -and $rows[0].ownerid_Property.Value -and $rows[0].ownerid_Property.Value.Id) {
    return [Guid]$rows[0].ownerid_Property.Value.Id
  }
  return $null
}

function Add-SequenceTarget {
  param(
    [string]$TargetEntity,
    [Guid]$TargetId,
    [Guid]$SequenceId,
    [Guid]$DefinitionSequenceId,
    [string]$SourceLabel
  )

  $existsFetch = @"
<fetch count="1">
  <entity name="msdyn_sequencetarget">
    <attribute name="msdyn_sequencetargetid" />
    <filter>
      <condition attribute="msdyn_parentsequence" operator="eq" value="$DefinitionSequenceId" />
      <condition attribute="msdyn_target" operator="eq" value="$TargetId" />
    </filter>
  </entity>
</fetch>
"@

  $existing = Get-RecordsByFetch -Fetch $existsFetch
  if ($existing.Count -gt 0) {
    return [PSCustomObject]@{ outcome = "SkippedExisting"; id = $existing[0].msdyn_sequencetargetid }
  }

  try {
    $ownerId = Get-TargetOwnerId -TargetEntity $TargetEntity -TargetId $TargetId
    if (-not $ownerId) {
      return [PSCustomObject]@{ outcome = "Failed"; error = "Target owner not found" }
    }

    $targetGuidText = $TargetId.ToString().ToLowerInvariant()
    $ownerGuidText = $ownerId.ToString().ToLowerInvariant()
    $definitionGuidText = $DefinitionSequenceId.ToString().ToLowerInvariant()
    $uniqueKey = "$($TargetEntity)$targetGuidText" + "u$ownerGuidText" + "u$definitionGuidText"
    $regardingJson = "{""etn"":""$TargetEntity"",""id"":""$targetGuidText""}"

    $fields = @{
      msdyn_name = "Wave5 SeqTarget $TargetEntity [$SourceLabel] [$batchTag]"
      msdyn_parentsequence = New-CrmEntityReference -EntityLogicalName msdyn_sequence -Id $DefinitionSequenceId
      msdyn_appliedsequenceinstance = New-CrmEntityReference -EntityLogicalName msdyn_sequence -Id $SequenceId
      msdyn_target = New-CrmEntityReference -EntityLogicalName $TargetEntity -Id $TargetId
      msdyn_sequencetargetuniquekey = $uniqueKey
      msdyn_regarding = $regardingJson
    }
    $id = New-CrmRecord -conn $conn -EntityLogicalName msdyn_sequencetarget -Fields $fields
    return [PSCustomObject]@{ outcome = "Created"; id = $id }
  }
  catch {
    return [PSCustomObject]@{ outcome = "Failed"; error = $_.Exception.Message }
  }
}

# ---------------------------------------------
# 1) Collect prior waves records for backfill
# ---------------------------------------------
$wave1OppIds = @(
  [Guid]"7dec6956-810c-f111-8406-0022480b6bd9",
  [Guid]"b69b9d62-810c-f111-8406-0022480b6bd9",
  [Guid]"d99b9d62-810c-f111-8406-0022480b6bd9",
  [Guid]"f89b9d62-810c-f111-8406-0022480b6bd9",
  [Guid]"229c9d62-810c-f111-8406-0022480b6bd9"
)

$prevOppFetch = @"
<fetch>
  <entity name="opportunity">
    <attribute name="opportunityid" />
    <attribute name="contactid" />
    <attribute name="name" />
    <filter type="or">
      <condition attribute="name" operator="like" value="%[RBP2-%" />
      <condition attribute="name" operator="like" value="%[RBP3-%" />
      <condition attribute="name" operator="like" value="%[RBP4-%" />
    </filter>
  </entity>
</fetch>
"@
$prevOppRows = Get-RecordsByFetch -Fetch $prevOppFetch
$prevOppIds = @($prevOppRows | ForEach-Object { [Guid]$_.opportunityid }) + $wave1OppIds
$prevOppIds = @($prevOppIds | Select-Object -Unique)

$prevLeadFetch = @"
<fetch>
  <entity name="lead">
    <attribute name="leadid" />
    <attribute name="parentcontactid" />
    <attribute name="subject" />
    <filter type="or">
      <condition attribute="subject" operator="like" value="%[RBP2-%" />
      <condition attribute="subject" operator="like" value="%[RBP3-%" />
    </filter>
  </entity>
</fetch>
"@
$prevLeadRows = Get-RecordsByFetch -Fetch $prevLeadFetch
$prevLeadIds = @($prevLeadRows | ForEach-Object { [Guid]$_.leadid } | Select-Object -Unique)

$wave1ContactIds = @(
  [Guid]"6fc237ca-388f-f011-b4cc-000d3a5952f0",
  [Guid]"78ee1bfd-bf9f-4c1c-99ed-56663b4f68ac",
  [Guid]"f9bb4db7-45bc-f011-bbd3-000d3a5952f0",
  [Guid]"a7bf9a01-b056-e711-abaa-00155d701c02",
  [Guid]"70a457d6-242d-f011-8c4e-000d3a5952f0"
)

$prevContactIds = @()
$prevContactIds += $wave1ContactIds
$prevContactIds += @($prevLeadRows | Where-Object { $_.parentcontactid } | ForEach-Object { [Guid]$_.parentcontactid.Id })
$prevContactIds += @($prevOppRows | Where-Object { $_.contactid } | ForEach-Object { [Guid]$_.contactid.Id })
$prevContactIds = @($prevContactIds | Select-Object -Unique)

# ---------------------------------------------
# 2) Create Wave 5 data (RM cohorts + SLA)
# ---------------------------------------------
$contactFetch = @"
<fetch count="12">
  <entity name="contact">
    <attribute name="contactid" />
    <attribute name="fullname" />
    <filter>
      <condition attribute="statecode" operator="eq" value="0" />
    </filter>
    <order attribute="modifiedon" descending="true" />
  </entity>
</fetch>
"@
$contacts = Get-RecordsByFetch -Fetch $contactFetch
if ($contacts.Count -lt 6) { throw "Not enough contacts for Wave 5." }

$rmCohorts = @("RM-A", "RM-B", "RM-C")
$branches = @("Downtown", "Uptown", "Westside", "Lakeshore")

$newLeadIds = @()
$newOppIds = @()
$newContactIds = @()
$newTasks = @()

$leadThemes = @(
  "Affluent Checking Deep Dive",
  "Mortgage Reprice Advisory",
  "HELOC Cashflow Assessment",
  "Retirement Income Stress Test",
  "Credit Card Portfolio Optimization",
  "Family Savings & Youth Banking"
)

for ($i = 0; $i -lt 6; $i++) {
  $contact = $contacts[$i]
  $cohort = $rmCohorts[$i % $rmCohorts.Count]
  $branch = $branches[$i % $branches.Count]

  $nameParts = ($contact.fullname -split " ")
  $first = if ($nameParts.Count -gt 0) { $nameParts[0] } else { "Retail" }
  $last = if ($nameParts.Count -gt 1) { $nameParts[$nameParts.Count - 1] } else { "Customer" }

  $leadSubject = "Retail Bank Lead - $($leadThemes[$i]) [$cohort] [$branch] [$batchTag]"
  $leadId = New-CrmRecord -conn $conn -EntityLogicalName lead -Fields @{
    subject = $leadSubject
    firstname = $first
    lastname = $last
    companyname = "Contoso Retail Banking"
    parentcontactid = New-CrmEntityReference -EntityLogicalName contact -Id ([Guid]$contact.contactid)
    leadsourcecode = New-CrmOptionSetValue -Value 3
    description = "Wave5 RM cohort lead; cohort=$cohort; branch=$branch; batch=$batchTag"
  }

  $contactRef = New-CrmEntityReference -EntityLogicalName contact -Id ([Guid]$contact.contactid)
  $oppName = "Retail Banking - RM Cohort Pipeline [$cohort] [$branch] [$batchTag]"
  $oppValue = 25000 + (10000 * $i)
  $oppId = New-CrmRecord -conn $conn -EntityLogicalName opportunity -Fields @{
    name = $oppName
    description = "Wave5 opportunity from RM cohort motion; cohort=$cohort; branch=$branch"
    estimatedvalue = New-CrmMoney -Value ([decimal]$oppValue)
    estimatedclosedate = (Get-Date).Date.AddDays(18 + $i)
    opportunityratingcode = New-CrmOptionSetValue -Value 1
    customerid = $contactRef
    contactid = $contactRef
    parentcontactid = $contactRef
    originatingleadid = New-CrmEntityReference -EntityLogicalName lead -Id ([Guid]$leadId)
  }

  # SLA scenarios: first 3 overdue tasks (open), next 3 on-time future tasks
  $isBreach = $i -lt 3
  $dueDate = if ($isBreach) { (Get-Date).Date.AddDays(-2 - $i) } else { (Get-Date).Date.AddDays(3 + $i) }
  $taskSubject = if ($isBreach) {
    "SLA Breach Follow-up - Immediate Action [$cohort] [$batchTag]"
  } else {
    "SLA On-Track Follow-up [$cohort] [$batchTag]"
  }

  $taskId = New-CrmRecord -conn $conn -EntityLogicalName task -Fields @{
    subject = $taskSubject
    description = "Wave5 SLA simulation task. Breach=$isBreach; cohort=$cohort; branch=$branch"
    regardingobjectid = New-CrmEntityReference -EntityLogicalName opportunity -Id ([Guid]$oppId)
    scheduledend = $dueDate
    prioritycode = New-CrmOptionSetValue -Value 1
  }

  $newLeadIds += [Guid]$leadId
  $newOppIds += [Guid]$oppId
  $newContactIds += [Guid]$contact.contactid
  $newTasks += [PSCustomObject]@{ taskid = $taskId; breach = $isBreach; cohort = $cohort; branch = $branch }
}

$newContactIds = @($newContactIds | Select-Object -Unique)

# ---------------------------------------------
# 3) Apply sequences to previous + Wave 5
# ---------------------------------------------
$applyResults = @()

$allOppIds = @($prevOppIds + $newOppIds | Select-Object -Unique)
foreach ($id in $allOppIds) {
  $attempt = Add-SequenceTarget -TargetEntity "opportunity" -TargetId $id -SequenceId $sequenceIds.opportunity -DefinitionSequenceId $sequenceDefinitionIds.opportunity -SourceLabel "Waves1-5"
  $applyResults += [PSCustomObject]@{
    entity = "opportunity"
    targetId = $id
    result = $attempt.outcome
    detail = $attempt.error
  }
}

$allLeadIds = @($prevLeadIds + $newLeadIds | Select-Object -Unique)
foreach ($id in $allLeadIds) {
  $attempt = Add-SequenceTarget -TargetEntity "lead" -TargetId $id -SequenceId $sequenceIds.lead -DefinitionSequenceId $sequenceDefinitionIds.lead -SourceLabel "Waves2-5"
  $applyResults += [PSCustomObject]@{
    entity = "lead"
    targetId = $id
    result = $attempt.outcome
    detail = $attempt.error
  }
}

$allContactIds = @($prevContactIds + $newContactIds | Select-Object -Unique)
foreach ($id in $allContactIds) {
  $attempt = Add-SequenceTarget -TargetEntity "contact" -TargetId $id -SequenceId $sequenceIds.contact -DefinitionSequenceId $sequenceDefinitionIds.contact -SourceLabel "Waves1-5"
  $applyResults += [PSCustomObject]@{
    entity = "contact"
    targetId = $id
    result = $attempt.outcome
    detail = $attempt.error
  }
}

# ---------------------------------------------
# 4) Export Wave 5 summary and trend pack
# ---------------------------------------------
$sequenceSummary = $applyResults | Group-Object entity, result | ForEach-Object {
  [PSCustomObject]@{
    group = $_.Name
    count = $_.Count
  }
}

$scorecard = [PSCustomObject]@{
  batchTag = $batchTag
  generatedOn = (Get-Date).ToString("s")
  wave5 = [PSCustomObject]@{
    leadsCreated = $newLeadIds.Count
    opportunitiesCreated = $newOppIds.Count
    tasksCreated = $newTasks.Count
    slaBreachesSimulated = (@($newTasks | Where-Object { $_.breach })).Count
    slaOnTrackTasks = (@($newTasks | Where-Object { -not $_.breach })).Count
  }
  sequenceApplication = [PSCustomObject]@{
    opportunitiesTargeted = $allOppIds.Count
    leadsTargeted = $allLeadIds.Count
    contactsTargeted = $allContactIds.Count
    summary = $sequenceSummary
  }
}

$scoreJson = "C:\Users\efbarbat\d365-model\wave5-scorecard-$batchTag.json"
$scoreCsv = "C:\Users\efbarbat\d365-model\wave5-sequence-summary-$batchTag.csv"

$scorecard | ConvertTo-Json -Depth 8 | Set-Content -Path $scoreJson -Encoding UTF8
$applyResults | Export-Csv -Path $scoreCsv -NoTypeInformation -Encoding UTF8

[PSCustomObject]@{
  batchTag = $batchTag
  leadsCreated = $newLeadIds.Count
  opportunitiesCreated = $newOppIds.Count
  tasksCreated = $newTasks.Count
  sequenceTargetsApplied = (@($applyResults | Where-Object { $_.result -eq "Created" })).Count
  sequenceTargetsSkippedExisting = (@($applyResults | Where-Object { $_.result -eq "SkippedExisting" })).Count
  scorecardJson = $scoreJson
  sequenceSummaryCsv = $scoreCsv
} | ConvertTo-Json -Depth 6
