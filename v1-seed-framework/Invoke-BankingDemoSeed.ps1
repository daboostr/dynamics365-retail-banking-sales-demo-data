param(
  [Parameter(Mandatory = $false)]
  [string]$ConfigPath = "C:\Users\efbarbat\d365-model\v1-seed-framework\seed-config.json",

  [Parameter(Mandatory = $false)]
  [int]$FromWave,

  [Parameter(Mandatory = $false)]
  [int]$ToWave,

  [Parameter(Mandatory = $false)]
  [switch]$SkipSequences,

  [Parameter(Mandatory = $false)]
  [switch]$ValidateOnly,

  [Parameter(Mandatory = $false)]
  [switch]$DryRun,

  [Parameter(Mandatory = $false)]
  [string]$RunId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function New-RunId {
  return "SEEDV1-" + (Get-Date -Format "yyyyMMdd-HHmmss")
}

function Resolve-PhaseSelection {
  param(
    [array]$Phases,
    [int]$FromWaveParam,
    [int]$ToWaveParam,
    [bool]$SkipSequencePhases,
    [bool]$ValidationOnlyMode,
    [int]$DefaultFrom,
    [int]$DefaultTo
  )

  $effectiveFrom = if ($null -ne $FromWaveParam -and $FromWaveParam -gt 0) { $FromWaveParam } else { $DefaultFrom }
  $effectiveTo = if ($null -ne $ToWaveParam -and $ToWaveParam -gt 0) { $ToWaveParam } else { $DefaultTo }

  $selected = @($Phases | Where-Object { $_.enabled -eq $true })

  if ($ValidationOnlyMode) {
    $selected = @($selected | Where-Object { $_.kind -eq 'validation' })
    return [PSCustomObject]@{
      phases = $selected
      fromWave = $effectiveFrom
      toWave = $effectiveTo
    }
  }

  $selected = @($selected | Where-Object {
    ($_.wave -ge $effectiveFrom -and $_.wave -le $effectiveTo)
  })

  if ($SkipSequencePhases) {
    $selected = @($selected | Where-Object { $_.kind -ne 'sequence' })
  }

  return [PSCustomObject]@{
    phases = $selected
    fromWave = $effectiveFrom
    toWave = $effectiveTo
  }
}

function Invoke-PhaseScript {
  param(
    [string]$ScriptPath,
    [string]$LogPath
  )

  $start = Get-Date
  $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $ScriptPath 2>&1
  $end = Get-Date
  $durationSec = [Math]::Round(($end - $start).TotalSeconds, 2)

  $output | Out-File -FilePath $LogPath -Encoding UTF8

  return [PSCustomObject]@{
    output = $output
    durationSec = $durationSec
  }
}

if (-not (Test-Path -Path $ConfigPath)) {
  throw "Config file not found: $ConfigPath"
}

$config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
$repoRoot = "C:\Users\efbarbat\d365-model"

$effectiveRunId = if ([string]::IsNullOrWhiteSpace($RunId)) { New-RunId } else { $RunId }
$runRoot = Join-Path "C:\Users\efbarbat\d365-model\v1-seed-framework\runs" $effectiveRunId
New-Item -Path $runRoot -ItemType Directory -Force | Out-Null

$selection = Resolve-PhaseSelection -Phases $config.phases -FromWaveParam $FromWave -ToWaveParam $ToWave -SkipSequencePhases $SkipSequences.IsPresent -ValidationOnlyMode $ValidateOnly.IsPresent -DefaultFrom $config.execution.defaultFromWave -DefaultTo $config.execution.defaultToWave

$selectedPhases = @($selection.phases)
if ($selectedPhases.Count -eq 0) {
  throw "No phases selected. Check config and filters."
}

$manifest = [ordered]@{
  runId = $effectiveRunId
  startedOn = (Get-Date).ToString("s")
  configPath = $ConfigPath
  orgUrl = $config.environment.orgUrl
  username = $config.environment.username
  fromWave = $selection.fromWave
  toWave = $selection.toWave
  flags = [ordered]@{
    skipSequences = $SkipSequences.IsPresent
    validateOnly = $ValidateOnly.IsPresent
    dryRun = $DryRun.IsPresent
  }
  selectedPhases = @($selectedPhases | ForEach-Object { $_.name })
  phases = @()
  status = "InProgress"
}

if ($DryRun.IsPresent) {
  $manifest.status = "DryRun"
  $manifest.finishedOn = (Get-Date).ToString("s")
  $manifestPath = Join-Path $runRoot "run-manifest.json"
  ($manifest | ConvertTo-Json -Depth 10) | Out-File -FilePath $manifestPath -Encoding UTF8

  [PSCustomObject]@{
    runId = $effectiveRunId
    status = "DryRun"
    selectedPhases = $manifest.selectedPhases
    runFolder = $runRoot
    manifest = $manifestPath
  } | ConvertTo-Json -Depth 10

  exit 0
}

$hasFailure = $false
for ($i = 0; $i -lt $selectedPhases.Count; $i++) {
  $phase = $selectedPhases[$i]
  $phaseName = [string]$phase.name
  $phaseScript = Join-Path $repoRoot ([string]$phase.script)
  $phaseLog = Join-Path $runRoot ("phase-" + ($i + 1).ToString("00") + "-" + $phaseName + ".log")

  $phaseRecord = [ordered]@{
    index = $i + 1
    name = $phaseName
    wave = $phase.wave
    kind = $phase.kind
    script = $phaseScript
    log = $phaseLog
    startedOn = (Get-Date).ToString("s")
    success = $false
    durationSec = 0
  }

  if (-not (Test-Path -Path $phaseScript)) {
    $phaseRecord.error = "Script not found"
    $manifest.phases += $phaseRecord
    $hasFailure = $true
    if ($config.execution.stopOnError) { break }
    continue
  }

  try {
    $result = Invoke-PhaseScript -ScriptPath $phaseScript -LogPath $phaseLog
    $phaseRecord.durationSec = $result.durationSec
    $phaseRecord.success = $true
  }
  catch {
    $phaseRecord.success = $false
    $phaseRecord.error = $_.Exception.Message
    $hasFailure = $true
    if ($config.execution.stopOnError) {
      $manifest.phases += $phaseRecord
      break
    }
  }

  $phaseRecord.finishedOn = (Get-Date).ToString("s")
  $manifest.phases += $phaseRecord
}

$manifest.finishedOn = (Get-Date).ToString("s")
$manifest.status = if ($hasFailure) { "Failed" } else { "Succeeded" }
$manifestPath = Join-Path $runRoot "run-manifest.json"
($manifest | ConvertTo-Json -Depth 12) | Out-File -FilePath $manifestPath -Encoding UTF8

[PSCustomObject]@{
  runId = $effectiveRunId
  status = $manifest.status
  phaseCount = $manifest.phases.Count
  succeeded = @($manifest.phases | Where-Object { $_.success -eq $true }).Count
  failed = @($manifest.phases | Where-Object { $_.success -eq $false }).Count
  runFolder = $runRoot
  manifest = $manifestPath
} | ConvertTo-Json -Depth 10
