$Root = "C:\git\ust\hadoop-vs-spark-experiment"
$log = Join-Path $Root "results\stop_after_w3.log"
function W($m){ $line = "$(Get-Date -Format o) $m"; Add-Content -Path $log -Value $line -Encoding utf8; Write-Host $line }
W "stop-after-W3 watchdog started"

while ($true) {
  $csv = Join-Path $Root "results\results_high_ram_W3.csv"
  $sparkL = 0
  if (Test-Path $csv) {
    try { $sparkL = @(Import-Csv $csv | Where-Object { $_.engine -eq 'spark' -and $_.size -eq 'L' }).Count } catch { $sparkL = 0 }
  }
  $py = Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'run_experiment\.py' }
  $w2 = @($py | Where-Object { $_.CommandLine -match '--workloads W2' })
  if ($w2.Count -gt 0) {
    W "W2 started — killing as requested stop-after-W3"
    $w2 | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'run_mvp_from_S' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    W "stopped"
    exit 0
  }
  if ($sparkL -ge 3) {
    Start-Sleep -Seconds 8
    $py2 = Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'run_experiment\.py' }
    $stillW3 = @($py2 | Where-Object { $_.CommandLine -match '--workloads W3' })
    if ($stillW3.Count -eq 0) {
      W "Spark W3/L x3 present and W3 runner gone — stopping resume (no W2/low_ram)"
      Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'run_mvp_from_S' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
      W "STOPPED after W3"
      exit 0
    }
  }
  Start-Sleep -Seconds 20
}
