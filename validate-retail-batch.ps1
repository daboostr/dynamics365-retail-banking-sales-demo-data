$pac = "C:\Users\efbarbat\AppData\Local\Microsoft\PowerAppsCLI\Microsoft.PowerApps.CLI.2.2.1\tools\pac.exe"
$batchTag = "RBP-20260217-203433"

$oppFetch = "C:\Users\efbarbat\d365-model\fetch-batch-opps.xml"
$leadFetch = "C:\Users\efbarbat\d365-model\fetch-batch-leads.xml"
$taskFetch = "C:\Users\efbarbat\d365-model\fetch-batch-tasks.xml"
$callFetch = "C:\Users\efbarbat\d365-model\fetch-batch-calls.xml"

@"
<fetch>
  <entity name='opportunity'>
    <attribute name='opportunityid'/>
    <attribute name='name'/>
    <attribute name='estimatedvalue'/>
    <attribute name='estimatedclosedate'/>
    <filter>
      <condition attribute='name' operator='like' value='%[$batchTag]%' />
    </filter>
  </entity>
</fetch>
"@ | Set-Content -Path $oppFetch -Encoding UTF8

@"
<fetch>
  <entity name='lead'>
    <attribute name='leadid'/>
    <attribute name='subject'/>
    <filter>
      <condition attribute='subject' operator='like' value='%[$batchTag]%' />
    </filter>
  </entity>
</fetch>
"@ | Set-Content -Path $leadFetch -Encoding UTF8

@"
<fetch>
  <entity name='task'>
    <attribute name='activityid'/>
    <attribute name='subject'/>
    <filter>
      <condition attribute='subject' operator='like' value='%[$batchTag]%' />
    </filter>
  </entity>
</fetch>
"@ | Set-Content -Path $taskFetch -Encoding UTF8

@"
<fetch>
  <entity name='phonecall'>
    <attribute name='activityid'/>
    <attribute name='subject'/>
    <filter>
      <condition attribute='subject' operator='like' value='%[$batchTag]%' />
    </filter>
  </entity>
</fetch>
"@ | Set-Content -Path $callFetch -Encoding UTF8

Write-Output "--- Opportunities ---"
& $pac env fetch --xmlFile $oppFetch
Write-Output "--- Leads ---"
& $pac env fetch --xmlFile $leadFetch
Write-Output "--- Tasks ---"
& $pac env fetch --xmlFile $taskFetch
Write-Output "--- Phone Calls ---"
& $pac env fetch --xmlFile $callFetch
