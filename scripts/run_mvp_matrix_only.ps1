$Root = "C:\dev\hadoop-vs-spark-experiment"
Set-Location $Root
$ErrorActionPreference = "Continue"
$log = Join-Path $Root "results\mvp_matrix.log"
function W($m){ Add-Content -Path $log -Value $m -Encoding utf8; Write-Host $m }

W ("=== matrix resume " + (Get-Date -Format o) + " ===")

foreach ($cond in @("high_ram","low_ram")) {
  W (">>> compose_up " + $cond)
  & "$Root\scripts\compose_up.ps1" -Profile $cond
  if ($LASTEXITCODE -ne 0) { W ("compose_up failed " + $LASTEXITCODE); exit 1 }
  foreach ($wl in @("W1","W3")) {
    $out = Join-Path $Root ("results\results_" + $cond + "_" + $wl + ".csv")
    W (">>> " + $cond + " " + $wl + " -> " + $out)
    & python "$Root\scripts\run_experiment.py" --condition $cond --workloads $wl --sizes M,L --engines mapreduce,spark --trials 3 --results $out
    if ($LASTEXITCODE -ne 0) { W ("run_experiment failed " + $cond + " " + $wl + " code=" + $LASTEXITCODE); exit 1 }
  }
}

foreach ($cond in @("high_ram","low_ram")) {
  W (">>> compose_up " + $cond + " for W2")
  & "$Root\scripts\compose_up.ps1" -Profile $cond
  if ($LASTEXITCODE -ne 0) { W ("compose_up failed " + $LASTEXITCODE); exit 1 }
  $wl = "W2"
  $out = Join-Path $Root ("results\results_" + $cond + "_" + $wl + ".csv")
  W (">>> " + $cond + " " + $wl + " -> " + $out)
  & python "$Root\scripts\run_experiment.py" --condition $cond --workloads $wl --sizes M,L --engines mapreduce,spark --trials 3 --results $out
  if ($LASTEXITCODE -ne 0) { W ("run_experiment failed " + $cond + " " + $wl + " code=" + $LASTEXITCODE); exit 1 }
}

& python "$Root\scripts\merge_results.py"
& python "$Root\scripts\plot_results.py" --csv "$Root\results\results_all.csv"
W "MVP matrix complete."
