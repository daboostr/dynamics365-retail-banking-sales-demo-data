# Dynamics 365 Retail Banking Sales Demo Data

Reusable Dynamics 365 demo data seed framework for Retail Banking scenarios.

## Highlights
- Multi-wave seed flow (Waves 2–5)
- Sales Accelerator sequence create/build/activate support
- Optional sequence exclusion mode (`-SkipSequences`)
- Validation and run artifacts per execution

## Quick run
```powershell
cd C:\Users\efbarbat\d365-model
powershell -NoProfile -ExecutionPolicy Bypass -File .\v1-seed-framework\Invoke-BankingDemoSeed.ps1 -ConfigPath .\v1-seed-framework\seed-config.json -DryRun
powershell -NoProfile -ExecutionPolicy Bypass -File .\v1-seed-framework\Invoke-BankingDemoSeed.ps1 -ConfigPath .\v1-seed-framework\seed-config.json
```

## Skip sequence phases
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\v1-seed-framework\Invoke-BankingDemoSeed.ps1 -ConfigPath .\v1-seed-framework\seed-config.json -SkipSequences
```

## Full runbook
See `v1-seed-framework/README.md`.
