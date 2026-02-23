Import-Module Microsoft.Xrm.Data.Powershell

$conn = Connect-CrmOnline -ServerUrl "https://org9937c5ba.crm.dynamics.com" -ForceOAuth -Username "admin@D365DemoTSCE41978460.onmicrosoft.com"
if (-not ($conn -and $conn.IsReady)) {
  throw "Dataverse connection failed."
}

$batchTag = "RBP3-" + (Get-Date -Format "yyyyMMdd-HHmmss")
$branches = @("Downtown", "Uptown", "Westside", "Lakeshore")

$contactFetch = @"
<fetch count="24">
  <entity name="contact">
    <attribute name="contactid" />
    <attribute name="fullname" />
    <attribute name="modifiedon" />
    <filter>
      <condition attribute="statecode" operator="eq" value="0" />
      <condition attribute="fullname" operator="not-null" />
    </filter>
    <order attribute="modifiedon" descending="true" />
  </entity>
</fetch>
"@
$contactResult = Get-CrmRecordsByFetch -conn $conn -Fetch $contactFetch
$contacts = @($contactResult.CrmRecords | Select-Object -First 12)
if ($contacts.Count -lt 8) { throw "Need at least 8 contacts for Wave 3." }

$leadTemplates = @(
  @{ Topic = "Mortgage Pre-Approval Follow-Up"; Source = 3; Branch = "Downtown" },
  @{ Topic = "HELOC Product Education"; Source = 6; Branch = "Downtown" },
  @{ Topic = "Auto Refinance Advisor Intro"; Source = 4; Branch = "Uptown" },
  @{ Topic = "Premium Checking Benefits Review"; Source = 2; Branch = "Uptown" },
  @{ Topic = "CD Ladder Suitability Review"; Source = 1; Branch = "Westside" },
  @{ Topic = "Personal Loan Consolidation Discovery"; Source = 7; Branch = "Westside" },
  @{ Topic = "Retirement Income Workshop Invite"; Source = 3; Branch = "Lakeshore" },
  @{ Topic = "Student Banking Family Enrollment"; Source = 8; Branch = "Lakeshore" },
  @{ Topic = "Digital Wallet Adoption Campaign"; Source = 2; Branch = "Downtown" },
  @{ Topic = "Credit Card Balance Transfer Promo"; Source = 4; Branch = "Uptown" },
  @{ Topic = "Savings Rate Match Offer"; Source = 1; Branch = "Westside" },
  @{ Topic = "Financial Wellness Branch Event"; Source = 3; Branch = "Lakeshore" }
)

$createdLeads = @()
for ($i = 0; $i -lt $leadTemplates.Count; $i++) {
  $template = $leadTemplates[$i]
  $contact = $contacts[$i % $contacts.Count]
  $nameParts = ($contact.fullname -split " ")
  $first = if ($nameParts.Count -gt 0) { $nameParts[0] } else { "Retail" }
  $last = if ($nameParts.Count -gt 1) { $nameParts[$nameParts.Count - 1] } else { "Customer" }

  $subject = "Retail Bank Lead - $($template.Topic) [$($template.Branch)] [$batchTag]"
  $leadFields = @{
    subject = $subject
    firstname = $first
    lastname = $last
    companyname = "Contoso Retail Banking"
    leadsourcecode = New-CrmOptionSetValue -Value ([int]$template.Source)
    parentcontactid = New-CrmEntityReference -EntityLogicalName contact -Id ([Guid]$contact.contactid)
    description = "Wave 3 lead seed for branch $($template.Branch). Batch=$batchTag"
  }
  $leadId = New-CrmRecord -conn $conn -EntityLogicalName lead -Fields $leadFields
  $createdLeads += [PSCustomObject]@{
    leadid = $leadId
    subject = $subject
    branch = $template.Branch
    contactid = $contact.contactid
  }
}

# Convert first 6 leads to opportunities + mark lead qualified
$conversionProducts = @(
  @{ Product = "Mortgage Renewal"; Value = 340000; Days = 35 },
  @{ Product = "HELOC Expansion"; Value = 90000; Days = 30 },
  @{ Product = "Auto Refinance"; Value = 27000; Days = 20 },
  @{ Product = "Premium Checking Bundle"; Value = 10000; Days = 15 },
  @{ Product = "CD Ladder 12M"; Value = 60000; Days = 25 },
  @{ Product = "Personal Loan Consolidation"; Value = 22000; Days = 18 }
)

$convertedOpps = @()
for ($i = 0; $i -lt 6; $i++) {
  $lead = $createdLeads[$i]
  $template = $conversionProducts[$i]
  $contactRef = New-CrmEntityReference -EntityLogicalName contact -Id ([Guid]$lead.contactid)
  $leadRef = New-CrmEntityReference -EntityLogicalName lead -Id ([Guid]$lead.leadid)

  $opName = "Retail Banking - $($template.Product) [Conv] [$($lead.branch)] [$batchTag]"
  $opFields = @{
    name = $opName
    description = "Wave 3 converted from lead $($lead.leadid). Batch=$batchTag"
    estimatedvalue = New-CrmMoney -Value ([decimal]$template.Value)
    estimatedclosedate = (Get-Date).Date.AddDays([int]$template.Days)
    opportunityratingcode = New-CrmOptionSetValue -Value 1
    customerid = $contactRef
    contactid = $contactRef
    parentcontactid = $contactRef
    originatingleadid = $leadRef
  }
  $opId = New-CrmRecord -conn $conn -EntityLogicalName opportunity -Fields $opFields
  Set-CrmRecordState -conn $conn -EntityLogicalName lead -Id ([Guid]$lead.leadid) -StateCode Qualified -StatusCode Qualified

  $convertedOpps += [PSCustomObject]@{
    opportunityid = $opId
    name = $opName
    branch = $lead.branch
    leadid = $lead.leadid
    estimatedvalue = $template.Value
  }
}

# Next-best-action tasks for all converted opportunities
$nbaActions = @(
  "Request income verification and consent",
  "Schedule branch advisory meeting",
  "Send product comparison one-pager",
  "Run affordability and risk check",
  "Confirm document checklist completion",
  "Prepare approval-ready recommendation"
)

$createdTasks = @()
for ($i = 0; $i -lt $convertedOpps.Count; $i++) {
  $op = $convertedOpps[$i]
  $opRef = New-CrmEntityReference -EntityLogicalName opportunity -Id ([Guid]$op.opportunityid)
  $action = $nbaActions[$i % $nbaActions.Count]
  $taskFields = @{
    subject = "Next Best Action - $action [$batchTag]"
    description = "Wave 3 NBA task for opportunity $($op.opportunityid). Branch=$($op.branch)"
    regardingobjectid = $opRef
    scheduledend = (Get-Date).Date.AddDays(5 + $i)
    prioritycode = New-CrmOptionSetValue -Value 1
  }
  $taskId = New-CrmRecord -conn $conn -EntityLogicalName task -Fields $taskFields
  $createdTasks += [PSCustomObject]@{ activityid = $taskId; opportunityid = $op.opportunityid; branch = $op.branch }
}

# Manager dashboard extract
$createdLeadCount = $createdLeads.Count
$convertedCount = $convertedOpps.Count
$conversionRate = [math]::Round((100.0 * $convertedCount / $createdLeadCount), 2)

$branchRollup = @()
foreach ($branch in $branches) {
  $branchLeads = @($createdLeads | Where-Object { $_.branch -eq $branch })
  $branchConverted = @($convertedOpps | Where-Object { $_.branch -eq $branch })
  $branchTasks = @($createdTasks | Where-Object { $_.branch -eq $branch })
  $pipelineValue = ($branchConverted | Measure-Object -Property estimatedvalue -Sum).Sum
  if (-not $pipelineValue) { $pipelineValue = 0 }

  $branchRollup += [PSCustomObject]@{
    branch = $branch
    leads = $branchLeads.Count
    convertedOpportunities = $branchConverted.Count
    conversionRatePct = if ($branchLeads.Count -gt 0) { [math]::Round((100.0 * $branchConverted.Count / $branchLeads.Count), 2) } else { 0 }
    nextBestActionTasks = $branchTasks.Count
    convertedPipelineValue = [decimal]$pipelineValue
  }
}

$dashboard = [PSCustomObject]@{
  batchTag = $batchTag
  generatedOn = (Get-Date).ToString("s")
  totals = [PSCustomObject]@{
    leadsCreated = $createdLeadCount
    leadsConverted = $convertedCount
    conversionRatePct = $conversionRate
    opportunitiesCreatedFromLeads = $convertedCount
    nextBestActionTasksCreated = $createdTasks.Count
    convertedPipelineValue = [decimal](($convertedOpps | Measure-Object -Property estimatedvalue -Sum).Sum)
  }
  branchSummary = $branchRollup
  sampleIds = [PSCustomObject]@{
    leadIds = @($createdLeads | Select-Object -First 4 -ExpandProperty leadid)
    opportunityIds = @($convertedOpps | Select-Object -First 4 -ExpandProperty opportunityid)
    taskIds = @($createdTasks | Select-Object -First 4 -ExpandProperty activityid)
  }
}

$dashboardPath = "C:\Users\efbarbat\d365-model\wave3-dashboard-$batchTag.json"
$dashboard | ConvertTo-Json -Depth 8 | Set-Content -Path $dashboardPath -Encoding UTF8

[PSCustomObject]@{
  batchTag = $batchTag
  leadsCreated = $createdLeadCount
  leadsConverted = $convertedCount
  opportunitiesCreated = $convertedCount
  nbaTasksCreated = $createdTasks.Count
  dashboardExtract = $dashboardPath
} | ConvertTo-Json -Depth 6
