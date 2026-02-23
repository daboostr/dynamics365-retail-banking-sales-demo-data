Import-Module Microsoft.Xrm.Data.Powershell

$conn = Connect-CrmOnline -ServerUrl "https://org9937c5ba.crm.dynamics.com" -ForceOAuth -Username "admin@D365DemoTSCE41978460.onmicrosoft.com"
if (-not ($conn -and $conn.IsReady)) {
  throw "Dataverse connection failed."
}

$batchTag = "RBP4-" + (Get-Date -Format "yyyyMMdd-HHmmss")
$branches = @("Downtown", "Uptown", "Westside", "Lakeshore")

$accountFetch = @"
<fetch count="20">
  <entity name="account">
    <attribute name="accountid" />
    <attribute name="name" />
    <attribute name="description" />
    <attribute name="modifiedon" />
    <filter>
      <condition attribute="name" operator="like" value="Retail Household - %" />
    </filter>
    <order attribute="modifiedon" descending="true" />
  </entity>
</fetch>
"@
$accountResult = Get-CrmRecordsByFetch -conn $conn -Fetch $accountFetch
$accounts = @($accountResult.CrmRecords | Select-Object -First 8)
if ($accounts.Count -lt 4) {
  throw "Need at least 4 retail household accounts for Wave 4."
}

$products = @(
  @{ Name = "Premium Travel Card Upgrade"; Value = 12000 },
  @{ Name = "Wealth Starter Advisory"; Value = 50000 },
  @{ Name = "Insurance Bundle Enrollment"; Value = 18000 },
  @{ Name = "Family Savings Automation"; Value = 9000 },
  @{ Name = "Retirement Boost Plan"; Value = 70000 },
  @{ Name = "Business Banking Add-on"; Value = 28000 },
  @{ Name = "Youth Banking Multi-Account"; Value = 14000 },
  @{ Name = "Card + Checking Loyalty Pack"; Value = 16000 }
)

$extractBranch = {
  param([string]$description)
  if ($description -match "Branch=(Downtown|Uptown|Westside|Lakeshore)") {
    return $matches[1]
  }
  return "Downtown"
}

$createdOpps = @()
$createdTasks = @()
$churnTagged = @()

for ($i = 0; $i -lt $accounts.Count; $i++) {
  $account = $accounts[$i]
  $product = $products[$i % $products.Count]
  $branch = & $extractBranch ([string]$account.description)

  $accountRef = New-CrmEntityReference -EntityLogicalName account -Id ([Guid]$account.accountid)
  $oppName = "Retail Banking - Cross-Sell - $($product.Name) [$branch] [$batchTag]"

  $opFields = @{
    name = $oppName
    description = "Wave 4 cross-sell recommendation for household account. Branch=$branch; Batch=$batchTag"
    estimatedvalue = New-CrmMoney -Value ([decimal]$product.Value)
    estimatedclosedate = (Get-Date).Date.AddDays(21 + ($i * 2))
    opportunityratingcode = New-CrmOptionSetValue -Value 1
    customerid = $accountRef
    parentaccountid = $accountRef
  }

  $opId = New-CrmRecord -conn $conn -EntityLogicalName opportunity -Fields $opFields
  $createdOpps += [PSCustomObject]@{
    opportunityid = $opId
    accountid = $account.accountid
    accountName = $account.name
    branch = $branch
    estimatedvalue = $product.Value
  }

  # Churn-risk tagging for first 4 accounts (2 high, 2 medium)
  if ($i -lt 4) {
    $riskTier = if ($i -lt 2) { "High" } else { "Medium" }
    $riskScore = if ($i -lt 2) { 82 + $i } else { 64 + $i }
    $newDescription = "$(if($account.description){$account.description + ' | '}else{''})ChurnRisk=$riskTier; RiskScore=$riskScore; Wave4=$batchTag"

    Set-CrmRecord -conn $conn -EntityLogicalName account -Id ([Guid]$account.accountid) -Fields @{ description = $newDescription } | Out-Null

    $taskFields = @{
      subject = "Retention Action - $riskTier Risk Household [$batchTag]"
      description = "Execute retention playbook for churn-risk account. RiskScore=$riskScore; Branch=$branch"
      regardingobjectid = $accountRef
      scheduledend = (Get-Date).Date.AddDays(5 + $i)
      prioritycode = New-CrmOptionSetValue -Value 1
    }
    $taskId = New-CrmRecord -conn $conn -EntityLogicalName task -Fields $taskFields

    $churnTagged += [PSCustomObject]@{
      accountid = $account.accountid
      accountName = $account.name
      branch = $branch
      riskTier = $riskTier
      riskScore = $riskScore
      retentionTaskId = $taskId
    }
    $createdTasks += [PSCustomObject]@{
      activityid = $taskId
      branch = $branch
      type = "Retention"
    }
  }

  # Next-best-action task for each cross-sell opportunity
  $oppRef = New-CrmEntityReference -EntityLogicalName opportunity -Id ([Guid]$opId)
  $nbaTaskFields = @{
    subject = "Next Best Action - Present $($product.Name) [$batchTag]"
    description = "Prepare personalized offer and outreach for cross-sell opportunity. Branch=$branch"
    regardingobjectid = $oppRef
    scheduledend = (Get-Date).Date.AddDays(3 + $i)
    prioritycode = New-CrmOptionSetValue -Value 1
  }
  $nbaTaskId = New-CrmRecord -conn $conn -EntityLogicalName task -Fields $nbaTaskFields
  $createdTasks += [PSCustomObject]@{
    activityid = $nbaTaskId
    branch = $branch
    type = "NBA"
  }
}

$branchScore = foreach ($branch in $branches) {
  $branchOpps = @($createdOpps | Where-Object { $_.branch -eq $branch })
  $branchRisk = @($churnTagged | Where-Object { $_.branch -eq $branch })
  $branchTasks = @($createdTasks | Where-Object { $_.branch -eq $branch })

  [PSCustomObject]@{
    branch = $branch
    crossSellOpportunities = $branchOpps.Count
    crossSellPipelineValue = [decimal](($branchOpps | Measure-Object -Property estimatedvalue -Sum).Sum)
    churnRiskAccounts = $branchRisk.Count
    highRiskAccounts = (@($branchRisk | Where-Object { $_.riskTier -eq "High" })).Count
    mediumRiskAccounts = (@($branchRisk | Where-Object { $_.riskTier -eq "Medium" })).Count
    tasksCreated = $branchTasks.Count
  }
}

$totalValue = [decimal](($createdOpps | Measure-Object -Property estimatedvalue -Sum).Sum)
if (-not $totalValue) { $totalValue = 0 }

$scorecard = [PSCustomObject]@{
  batchTag = $batchTag
  generatedOn = (Get-Date).ToString("s")
  totals = [PSCustomObject]@{
    householdsTargeted = $accounts.Count
    crossSellOpportunitiesCreated = $createdOpps.Count
    churnRiskAccountsTagged = $churnTagged.Count
    retentionTasksCreated = (@($createdTasks | Where-Object { $_.type -eq "Retention" })).Count
    nextBestActionTasksCreated = (@($createdTasks | Where-Object { $_.type -eq "NBA" })).Count
    projectedCrossSellPipelineValue = $totalValue
  }
  branchScorecard = $branchScore
  sampleIds = [PSCustomObject]@{
    opportunityIds = @($createdOpps | Select-Object -First 5 -ExpandProperty opportunityid)
    retentionTaskIds = @($churnTagged | Select-Object -First 4 -ExpandProperty retentionTaskId)
  }
}

$jsonPath = "C:\Users\efbarbat\d365-model\wave4-scorecard-$batchTag.json"
$csvPath = "C:\Users\efbarbat\d365-model\wave4-scorecard-$batchTag.csv"

$scorecard | ConvertTo-Json -Depth 8 | Set-Content -Path $jsonPath -Encoding UTF8
$branchScore | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8

[PSCustomObject]@{
  batchTag = $batchTag
  opportunitiesCreated = $createdOpps.Count
  churnRiskAccountsTagged = $churnTagged.Count
  tasksCreated = $createdTasks.Count
  scorecardJson = $jsonPath
  scorecardCsv = $csvPath
} | ConvertTo-Json -Depth 6
