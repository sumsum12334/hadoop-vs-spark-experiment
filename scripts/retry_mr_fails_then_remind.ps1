$Root = "C:\git\ust\hadoop-vs-spark-experiment"
Set-Location $Root
$ErrorActionPreference = "Continue"
$log = Join-Path $Root "results\mr_fail_retry.out.log"
function W($m){ $line = "$(Get-Date -Format o) $m"; Add-Content -Path $log -Value $line -Encoding utf8; Write-Host $line }

W "wait until matrix idle and low_ram W2 done"

while ($true) {
  $busy = Get-CimInstance Win32_Process | Where-Object {
    $_.CommandLine -and ($_.CommandLine -match "run_experiment\.py|rerun_high_ram_w3_spark|run_low_ram_matrix")
  }
  $w2 = Join-Path $Root "results\results_low_ram_W2.csv"
  $w2win = Join-Path $Root "results\results_low_ram_W2_win.csv"
  $w2n = 0
  if (Test-Path $w2) { try { $w2n = @(Import-Csv $w2).Count } catch {} }
  if (Test-Path $w2win) { try { $w2n = [Math]::Max($w2n, @(Import-Csv $w2win).Count) } catch {} }
  W "busy=$([bool]$busy) W2rows=$w2n"
  if (-not $busy -and $w2n -ge 18) { break }
  Start-Sleep -Seconds 60
}

if ((Test-Path (Join-Path $Root "results\results_low_ram_W2.csv")) -and -not (Test-Path (Join-Path $Root "results\results_low_ram_W2_win.csv"))) {
  Rename-Item (Join-Path $Root "results\results_low_ram_W2.csv") "results_low_ram_W2_win.csv"
  W "renamed W2 -> results_low_ram_W2_win.csv"
}

function Retry-MR($cond,$wl,$size,$csv) {
  W "RETRY $cond $wl $size mapreduce x1 -> $csv"
  & python "$Root\scripts\run_experiment.py" --condition $cond --workloads $wl --sizes $size --engines mapreduce --trials 1 --results $csv
  W "exit=$LASTEXITCODE"
}

W "compose high_ram for W1/W2 MR retries"
& "$Root\scripts\compose_up.ps1" -Profile high_ram
& "$Root\scripts\ensure_python_in_hadoop.ps1"
Retry-MR "high_ram" "W1" "L" (Join-Path $Root "results\results_high_ram_W1_win.csv")
Retry-MR "high_ram" "W2" "L" (Join-Path $Root "results\results_high_ram_W2_win.csv")

W "compose low_ram for W3 MR retries"
& "$Root\scripts\compose_up.ps1" -Profile low_ram
& "$Root\scripts\ensure_python_in_hadoop.ps1"
Retry-MR "low_ram" "W3" "M" (Join-Path $Root "results\results_low_ram_W3_win.csv")
Retry-MR "low_ram" "W3" "L" (Join-Path $Root "results\results_low_ram_W3_win.csv")

W "MR fail retries done"
W "PING_USER_COMMIT_READY"
