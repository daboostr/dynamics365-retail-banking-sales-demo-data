# Retail Banking Demo Seed — Reusable V1

This V1 framework gives you a single entrypoint to re-run your Banking demo seed in a controlled, repeatable way.

## What this adds
- One orchestrator command for Waves 2–5 + sequence phases + validation
- Config-driven phase selection (no script edits needed)
- Run artifacts per execution (manifest + per-phase logs)
- Support for partial reruns and validation-only mode

## Files
- `Invoke-BankingDemoSeed.ps1` — orchestrator
- `seed-config.template.json` — base config contract
- `README.md` — runbook

## Prerequisites
1. Open PowerShell and change to repo root:
  - `cd C:\Users\efbarbat\d365-model`
2. Ensure module is installed (one-time):
  - `Install-Module Microsoft.Xrm.Data.PowerShell -Scope CurrentUser`
3. Ensure config exists:
  - `Copy-Item .\v1-seed-framework\seed-config.template.json .\v1-seed-framework\seed-config.json` (if not already present)

## Quick start (terminal)
1. Dry run first:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File .\v1-seed-framework\Invoke-BankingDemoSeed.ps1 -ConfigPath .\v1-seed-framework\seed-config.json -DryRun`
2. Full run:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File .\v1-seed-framework\Invoke-BankingDemoSeed.ps1 -ConfigPath .\v1-seed-framework\seed-config.json`

## Common modes
- Dry run (no scripts executed):
  - `...Invoke-BankingDemoSeed.ps1 -ConfigPath .\v1-seed-framework\seed-config.json -DryRun`
- Re-run only Wave 5 and validation:
  - `...Invoke-BankingDemoSeed.ps1 -ConfigPath .\v1-seed-framework\seed-config.json -FromWave 5 -ToWave 5`
- Validation only:
  - `...Invoke-BankingDemoSeed.ps1 -ConfigPath .\v1-seed-framework\seed-config.json -ValidateOnly`
- Skip sequence phases:
  - `...Invoke-BankingDemoSeed.ps1 -ConfigPath .\v1-seed-framework\seed-config.json -SkipSequences`

## Exclude sequences (recommended options)

If you want to avoid creating/updating/activating Sales Accelerator sequences on a run, use one of these:

1) One-off skip (best for ad hoc runs)
- Command:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File .\v1-seed-framework\Invoke-BankingDemoSeed.ps1 -ConfigPath .\v1-seed-framework\seed-config.json -SkipSequences`
- Behavior:
  - Skips all phases where `kind = "sequence"`.
  - Still runs seed and validation phases within selected wave range.

2) Persistent skip in config (best for teams)
- In `v1-seed-framework\seed-config.json`, set `enabled` to `false` for:
  - `sequence-create`
  - `sequence-build`
  - `sequence-activate`
- Then run normally without `-SkipSequences`.

3) Wave-only execution (no sequence touch)
- If sequence phases are wave 4, run only Wave 5:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File .\v1-seed-framework\Invoke-BankingDemoSeed.ps1 -ConfigPath .\v1-seed-framework\seed-config.json -FromWave 5 -ToWave 5`

## Full command reference
- Full run:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File .\v1-seed-framework\Invoke-BankingDemoSeed.ps1 -ConfigPath .\v1-seed-framework\seed-config.json`
- Skip sequences:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File .\v1-seed-framework\Invoke-BankingDemoSeed.ps1 -ConfigPath .\v1-seed-framework\seed-config.json -SkipSequences`
- Wave range:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File .\v1-seed-framework\Invoke-BankingDemoSeed.ps1 -ConfigPath .\v1-seed-framework\seed-config.json -FromWave 5 -ToWave 5`
- Validation only:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File .\v1-seed-framework\Invoke-BankingDemoSeed.ps1 -ConfigPath .\v1-seed-framework\seed-config.json -ValidateOnly`
- Dry run:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File .\v1-seed-framework\Invoke-BankingDemoSeed.ps1 -ConfigPath .\v1-seed-framework\seed-config.json -DryRun`

## Output artifacts
Each run creates a folder:
- `d365-model\v1-seed-framework\runs\<runId>\`

Artifacts include:
- `run-manifest.json`
- `phase-<index>-<phaseName>.log`

## Notes
- Existing seed scripts are executed as-is from `d365-model`.
- Orchestrator does not modify your current seed logic.
- Wave 1 remains your original preview/approval flow and is intentionally not auto-executed in V1.
