# MVP: high+low x W1+W3 x M+L x 3 trials, then W2 + plots
# Results filenames encode env + workload: results_{condition}_{workload}.csv
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root
New-Item -ItemType Directory -Force -Path (Join-Path $Root "results") | Out-Null

python (Join-Path $PSScriptRoot "generate_data.py") --sizes M,L

foreach ($cond in @("high_ram","low_ram")) {
  & (Join-Path $PSScriptRoot "compose_up.ps1") -Profile $cond
  foreach ($wl in @("W1","W3")) {
    $out = Join-Path $Root ("results\results_" + $cond + "_" + $wl + ".csv")
    Write-Host (">>> " + $cond + " " + $wl + " -> " + $out)
    python (Join-Path $PSScriptRoot "run_experiment.py") `
      --condition $cond --workloads $wl --sizes M,L `
      --engines mapreduce,spark --trials 3 `
      --results $out
  }
}

foreach ($cond in @("high_ram","low_ram")) {
  & (Join-Path $PSScriptRoot "compose_up.ps1") -Profile $cond
  $wl = "W2"
  $out = Join-Path $Root ("results\results_" + $cond + "_" + $wl + ".csv")
  Write-Host (">>> " + $cond + " " + $wl + " -> " + $out)
  python (Join-Path $PSScriptRoot "run_experiment.py") `
    --condition $cond --workloads $wl --sizes M,L `
    --engines mapreduce,spark --trials 3 `
    --results $out
}

python (Join-Path $PSScriptRoot "merge_results.py")
try {
  python (Join-Path $PSScriptRoot "plot_results.py") --csv (Join-Path $Root "results\results_all.csv")
} catch { Write-Warning $_ }
Write-Host "MVP matrix complete. Per-file results under results\results_<env>_<workload>.csv"
