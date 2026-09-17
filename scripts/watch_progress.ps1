$Root = "C:\git\ust\hadoop-vs-spark-experiment"
$Host.UI.RawUI.WindowTitle = "Hadoop MVP Progress"
Clear-Host
Write-Host "Hadoop MVP live progress (Ctrl+C closes this window only)" -ForegroundColor Cyan
Write-Host "Project: $Root`n"
while ($true) {
  $ts = Get-Date -Format "HH:mm:ss"
  Write-Host "======== $ts ========" -ForegroundColor Yellow
  $py = Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'run_experiment\.py' } | Select-Object -First 1
  if ($py) {
    $cmd = $py.CommandLine
    if ($cmd -match '--workloads (\S+).*--sizes (\S+).*--engines (\S+)') {
      Write-Host ("Runner: alive  workloads={0} sizes={1} engines={2}" -f $Matches[1],$Matches[2],$Matches[3])
    } elseif ($cmd -match '--workloads (\S+)') {
      Write-Host ("Runner: alive  workloads={0}" -f $Matches[1])
    } else { Write-Host "Runner: alive" }
  } else { Write-Host "Runner: NOT running" -ForegroundColor Red }

  $sparkSub = @(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'spark-submit' })
  if ($sparkSub.Count -gt 0) { Write-Host ("Spark-submit: RUNNING ({0})" -f $sparkSub.Count) -ForegroundColor Green }
  else { Write-Host "Spark-submit: idle" }

  $stats = docker stats --no-stream --format "{{.Name}}|{{.CPUPerc}}|{{.MemUsage}}" 2>$null
  foreach ($s in $stats) {
    if ($s -match '^hs-(spark|namenode|datanode|nodemanager)\|(.*)\|(.*)$') {
      Write-Host ("  {0,-14} CPU={1,-8} MEM={2}" -f $Matches[1],$Matches[2],$Matches[3])
    }
  }

  $yarn = docker exec hs-resourcemanager yarn application -list 2>$null
  $ylines = @($yarn | Where-Object { $_ -match 'application_' })
  if ($ylines.Count -eq 0) {
    Write-Host "YARN: no RUNNING app (normal during Spark local / between trials / upload)"
  } else {
    foreach ($l in $ylines) {
      if ($l -match '(application_\S+)\s+\S+\s+(\S+)\s+\S+\s+\S+\s+(\S+)\s+\S+\s+(\S+)%') {
        Write-Host ("YARN: {0} type={1} state={2} progress={3}%" -f $Matches[1],$Matches[2],$Matches[3],$Matches[4]) -ForegroundColor Green
      } else { Write-Host ("YARN: " + $l.Trim()) }
    }
  }

  $files = Get-ChildItem (Join-Path $Root "results\results_*_W*.csv") -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch 'smoke' }
  foreach ($f in $files) {
    try {
      $rows = @(Import-Csv $f.FullName)
      Write-Host ("CSV {0}: {1} rows (mtime {2:HH:mm:ss})" -f $f.Name,$rows.Count,$f.LastWriteTime)
      $rows | Select-Object -Last 3 | ForEach-Object {
        Write-Host ("  {0,-10} {1} {2} trial{3}  {4}s ok={5}" -f $_.engine,$_.workload,$_.size,$_.trial,$_.wall_sec,$_.ok)
      }
    } catch {}
  }
  Write-Host ""
  Start-Sleep -Seconds 10
}
