# Smoke: high_ram + W1/S both engines
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root
& (Join-Path $PSScriptRoot 'compose_up.ps1') -Profile high_ram
python (Join-Path $PSScriptRoot 'generate_data.py') --sizes S
python (Join-Path $PSScriptRoot 'run_experiment.py') `
  --condition high_ram --workloads W1 --sizes S --engines mapreduce,spark --trials 1
Write-Host 'Smoke complete. See results/results.csv'
