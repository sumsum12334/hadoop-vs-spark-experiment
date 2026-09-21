$Root = "C:\git\ust\hadoop-vs-spark-experiment"
$ErrorActionPreference = "Continue"
$log = Join-Path $Root "results\spark_rerun_orch.out.log"
function W($m){ $line = "$(Get-Date -Format o) $m"; Add-Content -Path $log -Value $line -Encoding utf8; Write-Host $line }

W "orch: wait for high_ram W2 to finish (18 rows or process exit)"

function Get-W2Count {
  $p = Join-Path $Root "results\results_high_ram_W2.csv"
  if (-not (Test-Path $p)) { return 0 }
  try { return @(Import-Csv $p).Count } catch { return 0 }
}

# Wait until W2 CSV has 18 rows OR run_experiment for W2 is gone and count>=12 and yarn idle after spark phase
while ($true) {
  $n = Get-W2Count
  $exp = Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine -match 'run_experiment\.py.*high_ram.*W2' }
  $resume = Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine -match 'run_mvp_resume_w2\.ps1' }
  W "W2 rows=$n exp=$([bool]$exp) resume=$([bool]$resume)"
  if ($n -ge 18) { W "W2 CSV complete (18)"; break }
  # If experiment process gone but resume still alive heading to low_ram with incomplete W2 — still wait a bit
  if (-not $exp -and $n -ge 1) {
    # give a few minutes for final appends
    Start-Sleep -Seconds 20
    $n2 = Get-W2Count
    if ($n2 -ge 18) { break }
    if (-not $exp -and $n2 -eq $n) {
      # process ended; accept whatever we have if >= 15 (MR L x3 + partial spark) — still proceed to strip spark & rerun
      if ($n2 -ge 15 -or (-not $resume -and -not $exp)) { W "W2 process ended with rows=$n2 — proceed"; break }
    }
  }
  Start-Sleep -Seconds 30
}

W "orch: stop resume/experiment so we can rerun spark with new env mem"
Get-CimInstance Win32_Process | Where-Object {
  $_.CommandLine -and ($_.CommandLine -match 'run_mvp_resume_w2\.ps1|run_experiment\.py|compose_up\.ps1')
} | ForEach-Object {
  W "kill $($_.ProcessId)"
  Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
}
Start-Sleep -Seconds 5

# Ensure high_ram profile still up
& "$Root\scripts\compose_up.ps1" -Profile high_ram
& "$Root\scripts\ensure_python_in_hadoop.ps1"

foreach ($wl in @("W1","W2","W3")) {
  $csv = Join-Path $Root ("results\results_high_ram_" + $wl + ".csv")
  # backup
  if (Test-Path $csv) {
    Copy-Item $csv ($csv + ".bak_before_spark4g_" + (Get-Date -Format "yyyyMMdd_HHmmss")) -Force
  }
  python "$Root\scripts\_keep_mr_only.py" $csv
  W ">>> rerun high_ram Spark $wl S,M,L x3 (driver from .env=4g)"
  & python "$Root\scripts\run_experiment.py" --condition high_ram --workloads $wl --sizes S,M,L --engines spark --trials 3 --results $csv --skip-upload
  if ($LASTEXITCODE -ne 0) { W "FAILED spark $wl code=$LASTEXITCODE"; exit 1 }
}

W ">>> start low_ram matrix W1,W3,W2"
& "$Root\scripts\compose_up.ps1" -Profile low_ram
if ($LASTEXITCODE -ne 0) { W "compose_up low_ram failed"; exit 1 }
foreach ($wl in @("W1","W3","W2")) {
  $out = Join-Path $Root ("results\results_low_ram_" + $wl + ".csv")
  W ">>> low_ram $wl S,M,L -> $out"
  & python "$Root\scripts\run_experiment.py" --condition low_ram --workloads $wl --sizes S,M,L --engines mapreduce,spark --trials 3 --results $out
  if ($LASTEXITCODE -ne 0) { W "FAILED low_ram $wl code=$LASTEXITCODE"; exit 1 }
}
& python "$Root\scripts\merge_results.py"
try { & python "$Root\scripts\plot_results.py" --csv "$Root\results\results_all.csv" } catch { W "plot warn: $_" }
W "orch complete: spark rerun @4g + low_ram done"
