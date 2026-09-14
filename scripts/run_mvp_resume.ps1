$Root = "C:\dev\hadoop-vs-spark-experiment"
Set-Location $Root
$ErrorActionPreference = "Continue"
$log = Join-Path $Root "results\mvp_resume.log"
function W($m){ Add-Content -Path $log -Value $m -Encoding ascii; Write-Host $m }
W ("=== resume " + (Get-Date -Format o) + " ===")

# high_ram already up from launcher; still ensure
& "$Root\scripts\compose_up.ps1" -Profile high_ram | Out-Host

# 1) Finish high_ram W1 size L only (M already done)
$out = Join-Path $Root "results\results_high_ram_W1.csv"
W (">>> high_ram W1 L -> " + $out)
& python "$Root\scripts\run_experiment.py" --condition high_ram --workloads W1 --sizes L --engines mapreduce,spark --trials 3 --results $out
if ($LASTEXITCODE -ne 0) { W ("FAILED high_ram W1 L code=" + $LASTEXITCODE); exit 1 }

# 2) high_ram W3 then W2
foreach ($wl in @("W3","W2")) {
  $out = Join-Path $Root ("results\results_high_ram_" + $wl + ".csv")
  W (">>> high_ram " + $wl + " -> " + $out)
  & python "$Root\scripts\run_experiment.py" --condition high_ram --workloads $wl --sizes M,L --engines mapreduce,spark --trials 3 --results $out
  if ($LASTEXITCODE -ne 0) { W ("FAILED high_ram " + $wl + " code=" + $LASTEXITCODE); exit 1 }
}

# 3) low_ram all workloads
& "$Root\scripts\compose_up.ps1" -Profile low_ram | Out-Host
foreach ($wl in @("W1","W3","W2")) {
  $out = Join-Path $Root ("results\results_low_ram_" + $wl + ".csv")
  W (">>> low_ram " + $wl + " -> " + $out)
  & python "$Root\scripts\run_experiment.py" --condition low_ram --workloads $wl --sizes M,L --engines mapreduce,spark --trials 3 --results $out
  if ($LASTEXITCODE -ne 0) { W ("FAILED low_ram " + $wl + " code=" + $LASTEXITCODE); exit 1 }
}

& python "$Root\scripts\merge_results.py"
& python "$Root\scripts\plot_results.py" --csv "$Root\results\results_all.csv"
W "MVP resume complete."
