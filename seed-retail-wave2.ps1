Import-Module Microsoft.Xrm.Data.Powershell

$conn = Connect-CrmOnline -ServerUrl "https://org9937c5ba.crm.dynamics.com" -ForceOAuth
if (-not ($conn -and $conn.IsReady)) {
  throw "Dataverse connection failed."
}

$batchTag = "RBP2-" + (Get-Date -Format "yyyyMMdd-HHmmss")
$branches = @("Downtown", "Uptown", "Westside", "Lakeshore")

$contactFetch = @"
<fetch count="16">
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
$contacts = @($contactResult.CrmRecords | Select-Object -First 16)
if ($contacts.Count -lt 8) {
  throw "Need at least 8 active contacts for Wave 2."
}

$households = @(
  @{ Name = "Bennett Household"; City = "Seattle"; Phone = "206-555-1101"; Branch = "Downtown" },
  @{ Name = "Kataras Household"; City = "Chicago"; Phone = "312-555-1102"; Branch = "Uptown" },
  @{ Name = "Gardiner Household"; City = "Boston"; Phone = "617-555-1103"; Branch = "Westside" },
  @{ Name = "Gary Household"; City = "San Diego"; Phone = "619-555-1104"; Branch = "Lakeshore" },
  @{ Name = "Nunez Household"; City = "Phoenix"; Phone = "602-555-1105"; Branch = "Downtown" },
  @{ Name = "Baker Household"; City = "Austin"; Phone = "512-555-1106"; Branch = "Uptown" },
  @{ Name = "Barbatsis Household"; City = "Denver"; Phone = "303-555-1107"; Branch = "Westside" },
  @{ Name = "Sizlaedd Household"; City = "Miami"; Phone = "305-555-1108"; Branch = "Lakeshore" }
)

$createdAccounts = @()
for ($i = 0; $i -lt $households.Count; $i++) {
  $h = $households[$i]
  $accountFields = @{
    name = "Retail Household - $($h.Name) [$batchTag]"
    address1_city = $h.City
    telephone1 = $h.Phone
    description = "Wave 2 household seed; Branch=$($h.Branch); Batch=$batchTag"
  }
  $accountId = New-CrmRecord -conn $conn -EntityLogicalName account -Fields $accountFields
  $createdAccounts += [PSCustomObject]@{
    accountid = $accountId
    name = $accountFields.name
    branch = $h.Branch
  }
}

$linkedContacts = @()
for ($i = 0; $i -lt $createdAccounts.Count; $i++) {
  $acct = $createdAccounts[$i]
  $contact = $contacts[$i]
  $acctRef = New-CrmEntityReference -EntityLogicalName account -Id ([Guid]$acct.accountid)
  Set-CrmRecord -conn $conn -EntityLogicalName contact -Id ([Guid]$contact.contactid) -Fields @{ parentcustomerid = $acctRef } | Out-Null
  $linkedContacts += [PSCustomObject]@{
    contactid = $contact.contactid
    fullname = $contact.fullname
    accountid = $acct.accountid
    branch = $acct.branch
  }
}

$opptyTemplates = @(
  @{ Product = "Mortgage Renewal"; Value = 360000; Days = 40; Branch = "Downtown" },
  @{ Product = "HELOC Expansion"; Value = 85000; Days = 35; Branch = "Downtown" },
  @{ Product = "Auto Refinance"; Value = 32000; Days = 25; Branch = "Uptown" },
  @{ Product = "Premium Checking Bundle"; Value = 9000; Days = 20; Branch = "Uptown" },
  @{ Product = "CD Ladder 12M"; Value = 70000; Days = 30; Branch = "Westside" },
  @{ Product = "Personal Loan Consolidation"; Value = 28000; Days = 22; Branch = "Westside" },
  @{ Product = "Retirement Income Plan"; Value = 210000; Days = 55; Branch = "Lakeshore" },
  @{ Product = "Student Banking Family Pack"; Value = 14000; Days = 28; Branch = "Lakeshore" }
)

$createdOpps = @()
for ($i = 0; $i -lt $opptyTemplates.Count; $i++) {
  $template = $opptyTemplates[$i]
  $contact = $linkedContacts[$i % $linkedContacts.Count]
  $contactRef = New-CrmEntityReference -EntityLogicalName contact -Id ([Guid]$contact.contactid)
  $name = "Retail Banking - $($template.Product) [$($template.Branch)] [$batchTag]"
  $opFields = @{
    name = $name
    description = "Wave 2 seeded branch opportunity. Branch=$($template.Branch); Batch=$batchTag"
    estimatedvalue = New-CrmMoney -Value ([decimal]$template.Value)
    estimatedclosedate = (Get-Date).Date.AddDays([int]$template.Days)
    opportunityratingcode = New-CrmOptionSetValue -Value 1
    customerid = $contactRef
    contactid = $contactRef
    parentcontactid = $contactRef
  }
  $opId = New-CrmRecord -conn $conn -EntityLogicalName opportunity -Fields $opFields
  $createdOpps += [PSCustomObject]@{
    opportunityid = $opId
    name = $name
    branch = $template.Branch
    estimatedvalue = $template.Value
  }
}

# Set outcomes: first 4 won, next 2 lost, last 2 open
for ($i = 0; $i -lt $createdOpps.Count; $i++) {
  $op = $createdOpps[$i]
  if ($i -lt 4) {
    Set-CrmRecordState -conn $conn -EntityLogicalName opportunity -Id ([Guid]$op.opportunityid) -StateCode Won -StatusCode Won
  }
  elseif ($i -lt 6) {
    Set-CrmRecordState -conn $conn -EntityLogicalName opportunity -Id ([Guid]$op.opportunityid) -StateCode Lost -StatusCode Canceled
  }
}

# Branch KPI summary
$kpi = @()
foreach ($branch in $branches) {
  $branchOpps = @($createdOpps | Where-Object { $_.branch -eq $branch })
  $wonCount = 0
  $lostCount = 0
  $openCount = 0

  foreach ($op in $branchOpps) {
    $record = Get-CrmRecord -conn $conn -EntityLogicalName opportunity -Id ([Guid]$op.opportunityid) -Fields statecode,estimatedvalue
    switch ($record.statecode.Value) {
      1 { $wonCount++ }
      2 { $lostCount++ }
      default { $openCount++ }
    }
  }

  $totalValue = ($branchOpps | Measure-Object -Property estimatedvalue -Sum).Sum
  if (-not $totalValue) { $totalValue = 0 }

  $kpi += [PSCustomObject]@{
    branch = $branch
    opportunities = $branchOpps.Count
    won = $wonCount
    lost = $lostCount
    open = $openCount
    pipelineValue = [decimal]$totalValue
  }
}

$result = [PSCustomObject]@{
  batchTag = $batchTag
  accountsCreated = $createdAccounts.Count
  contactsLinked = $linkedContacts.Count
  opportunitiesCreated = $createdOpps.Count
  outcomes = [PSCustomObject]@{
    won = 4
    lost = 2
    open = 2
  }
  sampleOpportunityIds = @($createdOpps | Select-Object -First 5 -ExpandProperty opportunityid)
  branchKpi = $kpi
}

$result | ConvertTo-Json -Depth 6
