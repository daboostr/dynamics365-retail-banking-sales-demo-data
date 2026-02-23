Import-Module Microsoft.Xrm.Data.Powershell

$conn = Connect-CrmOnline -ServerUrl "https://org9937c5ba.crm.dynamics.com" -ForceOAuth -Username "admin@D365DemoTSCE41978460.onmicrosoft.com"
if (-not ($conn -and $conn.IsReady)) {
  throw "Dataverse connection failed."
}

$batchTag = "SASEQ-" + (Get-Date -Format "yyyyMMdd-HHmmss")

$sequencePlans = @(
  @{
    baseName = "Retail Wave1-2 Opportunity Nurture"
    regardingEntity = "opportunity"
    regardingDisplay = "Opportunity"
    description = "Supports Wave 1-2 retail banking opportunities, including household and branch opportunity follow-through."
  },
  @{
    baseName = "Retail Wave3 Lead Qualification Sprint"
    regardingEntity = "lead"
    regardingDisplay = "Lead"
    description = "Supports Wave 3 lead qualification and conversion motion with tighter follow-up SLAs."
  },
  @{
    baseName = "Retail Wave4 Retention and Cross-Sell"
    regardingEntity = "contact"
    regardingDisplay = "Contact"
    description = "Supports Wave 4 churn-risk retention and cross-sell outreach on prioritized customer contacts."
  }
)

$created = @()

foreach ($plan in $sequencePlans) {
  $definitionName = "$($plan.baseName) [Definition] [$batchTag]"
  $activationName = "$($plan.baseName) [Activation] [$batchTag]"

  $defFields = @{
    msdyn_name = $definitionName
    msdyn_type = New-CrmOptionSetValue -Value 0
    msdyn_regardingentityname = $plan.regardingEntity
    msdyn_regardingentitydisplayname = $plan.regardingDisplay
    msdyn_description = "$($plan.description) Batch=$batchTag"
  }
  $definitionId = New-CrmRecord -conn $conn -EntityLogicalName msdyn_sequence -Fields $defFields

  $activationFields = @{
    msdyn_name = $activationName
    msdyn_type = New-CrmOptionSetValue -Value 1
    msdyn_regardingentityname = $plan.regardingEntity
    msdyn_regardingentitydisplayname = $plan.regardingDisplay
    msdyn_description = "Activation sequence for $($plan.baseName). Batch=$batchTag"
    msdyn_parentsequence = New-CrmEntityReference -EntityLogicalName msdyn_sequence -Id ([Guid]$definitionId)
  }
  $activationId = New-CrmRecord -conn $conn -EntityLogicalName msdyn_sequence -Fields $activationFields

  $created += [PSCustomObject]@{
    baseName = $plan.baseName
    regardingEntity = $plan.regardingEntity
    definitionId = $definitionId
    activationId = $activationId
  }
}

$result = [PSCustomObject]@{
  batchTag = $batchTag
  sequencesCreated = $created.Count * 2
  definitionCount = $created.Count
  activationCount = $created.Count
  records = $created
}

$result | ConvertTo-Json -Depth 6
