# Retail Banking Demo Seed — Reusable V1

This V1 framework gives you a single entrypoint to re-run your Banking demo seed in a controlled, repeatable way.

## What this adds
- One orchestrator command for Waves 2–5 + sequence phases + validation
- Config-driven phase selection (no script edits needed)
- Run artifacts per execution (manifest + per-phase logs)
- Support for partial reruns and validation-only mode

## What gets generated

The orchestrator runs existing scripts and generates/updates these Dataverse records across phases:

- `account` (household and churn-risk context)
- `contact` (household relationships and sequence targeting)
- `lead` (new lead cohorts)
- `opportunity` (branch/cross-sell/RM pipeline opportunities)
- `task` (retention, NBA, and SLA simulation actions)
- `msdyn_sequence` (definitions/activations when sequence phases are enabled)
- `msdyn_sequencetarget` (Wave 5 sequence application/backfill)

Wave 1 is intentionally excluded from V1 automation (original preview/approval-first flow).

## Wave behavior (high level)

- **Wave 2**: household accounts, contact linking, branch opportunities, won/lost/open mix, branch KPI summary
- **Wave 3**: lead creation, partial conversion to opportunities, next-best-action tasks, manager dashboard extract
- **Wave 4**: cross-sell opportunities, churn-risk tagging, retention + NBA tasks, executive scorecards
- **Wave 5**: RM cohort leads/opportunities/tasks, SLA simulation, sequence target application + summary exports

## Sequence phases

When enabled, these scripts run in V1:

- `create-sales-accelerator-sequences-wave1-4.ps1`
- `build-sales-accelerator-sequences-wave1-4.ps1`
- `activate-sales-sequences-wave1-4.ps1`

These can be skipped per run (`-SkipSequences`) or disabled in config.

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

Additional wave-specific exports are written by underlying scripts (for example Wave 3/4/5 JSON/CSV scorecards in the repo root).

## Related docs

- Root overview: `../README.md`
- Contribution guide: `../CONTRIBUTING.md`
- License: `../LICENSE`

## Notes
- Existing seed scripts are executed as-is from `d365-model`.
- Orchestrator does not modify your current seed logic.
- Wave 1 remains your original preview/approval flow and is intentionally not auto-executed in V1.
