$Root = "C:\git\ust\hadoop-vs-spark-experiment"
Set-Location $Root
$ErrorActionPreference = "Continue"
$log = Join-Path $Root "results\mvp_resume_w2.out.log"
function W($m){ $line = "$(Get-Date -Format o) $m"; Add-Content -Path $log -Value $line -Encoding utf8; Write-Host $line }

W ("=== resume from high_ram W2 " + (Get-Date -Format o) + " ===")

$cond = "high_ram"
$wl = "W2"
$out = Join-Path $Root ("results\results_" + $cond + "_" + $wl + ".csv")
W (">>> $cond $wl S,M,L -> $out")
& python "$Root\scripts\run_experiment.py" --condition $cond --workloads $wl --sizes S,M,L --engines mapreduce,spark --trials 3 --results $out
if ($LASTEXITCODE -ne 0) { W "FAILED $cond $wl code=$LASTEXITCODE"; exit 1 }

foreach ($cond in @("low_ram")) {
  W (">>> compose_up $cond")
  & "$Root\scripts\compose_up.ps1" -Profile $cond
  if ($LASTEXITCODE -ne 0) { W "compose_up failed $LASTEXITCODE"; exit 1 }
  foreach ($wl in @("W1","W3","W2")) {
    $out = Join-Path $Root ("results\results_" + $cond + "_" + $wl + ".csv")
    W (">>> $cond $wl S,M,L -> $out")
    & python "$Root\scripts\run_experiment.py" --condition $cond --workloads $wl --sizes S,M,L --engines mapreduce,spark --trials 3 --results $out
    if ($LASTEXITCODE -ne 0) { W "FAILED $cond $wl code=$LASTEXITCODE"; exit 1 }
  }
}

& python "$Root\scripts\merge_results.py"
try { & python "$Root\scripts\plot_results.py" --csv "$Root\results\results_all.csv" } catch { W "plot warn: $_" }
W "MVP matrix complete (resumed from W2)."
