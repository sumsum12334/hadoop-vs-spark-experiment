$Root = "C:\git\ust\hadoop-vs-spark-experiment"
Set-Location $Root
$ErrorActionPreference = "Continue"
$log = Join-Path $Root "results\mvp_from_S.out.log"
function W($m){ $line = "$(Get-Date -Format o) $m"; Add-Content -Path $log -Value $line -Encoding utf8; Write-Host $line }

W ("=== MVP from S high_ram=16g (stop after W3) " + (Get-Date -Format o) + " ===")

$cond = "high_ram"
foreach ($wl in @("W1","W3")) {
  $out = Join-Path $Root ("results\results_" + $cond + "_" + $wl + ".csv")
  W (">>> $cond $wl S,M,L -> $out")
  & python "$Root\scripts\run_experiment.py" --condition $cond --workloads $wl --sizes S,M,L --engines mapreduce,spark --trials 3 --results $out
  if ($LASTEXITCODE -ne 0) { W "FAILED $cond $wl code=$LASTEXITCODE"; exit 1 }
}

W "STOP after high_ram W3 as requested (no W2 / no low_ram)."
