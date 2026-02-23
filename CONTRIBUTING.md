# Contributing

Thanks for helping improve the Dynamics 365 Retail Banking Sales Demo Data project.

## Quick start
1. Fork the repository.
2. Create a branch from `main` with a clear name (for example: `fix/wave5-validation-batchtag`).
3. Make focused changes.
4. Run a dry-run before opening a PR:
   - `powershell -NoProfile -ExecutionPolicy Bypass -File .\v1-seed-framework\Invoke-BankingDemoSeed.ps1 -ConfigPath .\v1-seed-framework\seed-config.json -DryRun`
5. Open a pull request with:
   - What changed
   - Why it changed
   - How you tested it

## Contribution scope
- Keep changes minimal and task-focused.
- Prefer config-driven behavior over hardcoded values.
- Avoid breaking existing script names and expected outputs.

## Script conventions
- Use PowerShell with clear parameter names.
- Preserve existing file structure under `d365-model` and `v1-seed-framework`.
- Add comments only when logic is non-obvious.

## Testing guidance
- Validate orchestrator changes with `-DryRun` first.
- For runtime changes, include output examples from:
  - `v1-seed-framework/runs/<runId>/run-manifest.json`
  - Relevant phase logs

## Security and data safety
- Do not commit credentials, tokens, or environment secrets.
- Keep generated run artifacts out of source control unless explicitly needed.

## Pull request checklist
- [ ] Change is scoped and documented
- [ ] Dry-run completed successfully
- [ ] README/runbook updated if behavior changed
- [ ] No secrets added to repo
