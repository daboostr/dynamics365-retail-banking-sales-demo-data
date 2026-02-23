Import-Module Microsoft.Xrm.Data.Powershell

$conn = Connect-CrmOnline -ServerUrl "https://org9937c5ba.crm.dynamics.com" -ForceOAuth -Username "admin@D365DemoTSCE41978460.onmicrosoft.com"
if (-not ($conn -and $conn.IsReady)) {
  throw "Dataverse connection failed."
}

$sequenceBatchTag = "SASEQ-20260217-220218"

$targetFetch = @"
<fetch>
  <entity name="msdyn_sequence">
    <attribute name="msdyn_sequenceid" />
    <attribute name="msdyn_name" />
    <attribute name="msdyn_type" />
    <attribute name="msdyn_regardingentityname" />
    <attribute name="msdyn_definition" />
    <attribute name="msdyn_cjodefinition" />
    <attribute name="msdyn_maxstepcount" />
    <attribute name="msdyn_template" />
    <attribute name="statecode" />
    <attribute name="statuscode" />
    <filter>
      <condition attribute="msdyn_name" operator="like" value="%$sequenceBatchTag%" />
    </filter>
  </entity>
</fetch>
"@
$targets = @((Get-CrmRecordsByFetch -conn $conn -Fetch $targetFetch).CrmRecords)
if ($targets.Count -eq 0) {
  throw "No target sequences found for $sequenceBatchTag"
}

$entities = @("opportunity", "lead", "contact")
$updates = @()

foreach ($entity in $entities) {
  $targetDefinition = $targets | Where-Object {
    $_.msdyn_regardingentityname -eq $entity -and [string]$_.msdyn_type -eq "Definition"
  } | Select-Object -First 1

  $targetActivation = $targets | Where-Object {
    $_.msdyn_regardingentityname -eq $entity -and [string]$_.msdyn_type -eq "Activation"
  } | Select-Object -First 1

  if (-not $targetDefinition -or -not $targetActivation) {
    $updates += [PSCustomObject]@{ entity = $entity; outcome = "Skipped"; reason = "Missing target definition or activation" }
    continue
  }

  $sourceDefinitionFetch = @"
<fetch count="30">
  <entity name="msdyn_sequence">
    <attribute name="msdyn_sequenceid" />
    <attribute name="msdyn_name" />
    <attribute name="msdyn_type" />
    <attribute name="msdyn_regardingentityname" />
    <attribute name="msdyn_definition" />
    <attribute name="msdyn_cjodefinition" />
    <attribute name="msdyn_maxstepcount" />
    <attribute name="msdyn_template" />
    <attribute name="modifiedon" />
    <filter>
      <condition attribute="msdyn_regardingentityname" operator="eq" value="$entity" />
      <condition attribute="msdyn_type" operator="eq" value="0" />
      <condition attribute="statecode" operator="eq" value="0" />
      <condition attribute="msdyn_name" operator="not-like" value="%SASEQ-%" />
    </filter>
    <order attribute="modifiedon" descending="true" />
  </entity>
</fetch>
"@
  $definitionCandidates = @((Get-CrmRecordsByFetch -conn $conn -Fetch $sourceDefinitionFetch).CrmRecords)

  $sourceDefinition = $definitionCandidates | Where-Object {
    $_.msdyn_cjodefinition -and ([string]$_.msdyn_cjodefinition).Length -gt 1000
  } | Select-Object -First 1

  if (-not $sourceDefinition) {
    $sourceDefinition = $definitionCandidates | Where-Object {
      $_.msdyn_cjodefinition -and [string]$_.msdyn_cjodefinition -ne ""
    } | Select-Object -First 1
  }

  $sourceActivationFetch = @"
<fetch count="30">
  <entity name="msdyn_sequence">
    <attribute name="msdyn_sequenceid" />
    <attribute name="msdyn_name" />
    <attribute name="msdyn_type" />
    <attribute name="msdyn_regardingentityname" />
    <attribute name="msdyn_cjodefinition" />
    <attribute name="msdyn_maxstepcount" />
    <attribute name="modifiedon" />
    <filter>
      <condition attribute="msdyn_regardingentityname" operator="eq" value="$entity" />
      <condition attribute="msdyn_type" operator="eq" value="1" />
      <condition attribute="statecode" operator="eq" value="0" />
      <condition attribute="msdyn_name" operator="not-like" value="%SASEQ-%" />
    </filter>
    <order attribute="modifiedon" descending="true" />
  </entity>
</fetch>
"@
  $activationCandidates = @((Get-CrmRecordsByFetch -conn $conn -Fetch $sourceActivationFetch).CrmRecords)
  $sourceActivation = $activationCandidates | Where-Object {
    $_.msdyn_cjodefinition -and [string]$_.msdyn_cjodefinition -ne ""
  } | Select-Object -First 1

  if (-not $sourceDefinition) {
    $updates += [PSCustomObject]@{ entity = $entity; outcome = "Skipped"; reason = "No suitable source definition template found" }
    continue
  }

  $appliedStepCount = if ($sourceDefinition.msdyn_maxstepcount -and [int]$sourceDefinition.msdyn_maxstepcount -gt 0) {
    [int]$sourceDefinition.msdyn_maxstepcount
  } else {
    6
  }

  $definitionFields = @{
    msdyn_cjodefinition = [string]$sourceDefinition.msdyn_cjodefinition
    msdyn_maxstepcount = $appliedStepCount
    msdyn_description = "Retail Banking sequence seeded from template '$($sourceDefinition.msdyn_name)' and aligned to Waves 1-4."
  }
  if ($sourceDefinition.msdyn_template) {
    $definitionFields["msdyn_template"] = [string]$sourceDefinition.msdyn_template
  }
  Set-CrmRecord -conn $conn -EntityLogicalName msdyn_sequence -Id ([Guid]$targetDefinition.msdyn_sequenceid) -Fields $definitionFields | Out-Null

  $activationFields = @{}
  if ($sourceActivation -and $sourceActivation.msdyn_cjodefinition) {
    $activationFields["msdyn_cjodefinition"] = [string]$sourceActivation.msdyn_cjodefinition
  } else {
    $activationFields["msdyn_cjodefinition"] = [string]$sourceDefinition.msdyn_cjodefinition
  }
  $activationFields["msdyn_maxstepcount"] = $appliedStepCount
  if ($activationFields.Count -gt 0) {
    Set-CrmRecord -conn $conn -EntityLogicalName msdyn_sequence -Id ([Guid]$targetActivation.msdyn_sequenceid) -Fields $activationFields | Out-Null
  }

  $updates += [PSCustomObject]@{
    entity = $entity
    outcome = "Updated"
    sourceDefinition = $sourceDefinition.msdyn_name
    sourceActivation = if ($sourceActivation) { $sourceActivation.msdyn_name } else { "(none)" }
    targetDefinitionId = $targetDefinition.msdyn_sequenceid
    targetActivationId = $targetActivation.msdyn_sequenceid
    stepCountApplied = $appliedStepCount
  }
}

$postFetch = @"
<fetch>
  <entity name="msdyn_sequence">
    <attribute name="msdyn_sequenceid" />
    <attribute name="msdyn_name" />
    <attribute name="msdyn_type" />
    <attribute name="msdyn_regardingentityname" />
    <attribute name="msdyn_maxstepcount" />
    <attribute name="msdyn_definition" />
    <attribute name="msdyn_cjodefinition" />
    <filter>
      <condition attribute="msdyn_name" operator="like" value="%$sequenceBatchTag%" />
    </filter>
  </entity>
</fetch>
"@
$post = @((Get-CrmRecordsByFetch -conn $conn -Fetch $postFetch).CrmRecords)

$verification = $post | ForEach-Object {
  [PSCustomObject]@{
    id = $_.msdyn_sequenceid
    name = $_.msdyn_name
    type = $_.msdyn_type
    regarding = $_.msdyn_regardingentityname
    maxstepcount = if ($_.msdyn_maxstepcount) { [int]$_.msdyn_maxstepcount } else { 0 }
    definitionLength = if ($_.msdyn_definition) { ([string]$_.msdyn_definition).Length } else { 0 }
    cjoLength = if ($_.msdyn_cjodefinition) { ([string]$_.msdyn_cjodefinition).Length } else { 0 }
  }
}

[PSCustomObject]@{
  batchTag = $sequenceBatchTag
  updateSummary = $updates
  verification = $verification
} | ConvertTo-Json -Depth 8
