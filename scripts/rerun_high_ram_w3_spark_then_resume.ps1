$Root = "C:\git\ust\hadoop-vs-spark-experiment"
Set-Location $Root
$ErrorActionPreference = "Continue"
$log = Join-Path $Root "results\w3_spark_rerun.out.log"
function W($m){ $line = "$(Get-Date -Format o) $m"; Add-Content -Path $log -Value $line -Encoding utf8; Write-Host $line }

function Get-W3 {
  $p = Join-Path $Root "results\results_low_ram_W3.csv"
  if (-not (Test-Path $p)) { return @() }
  try { return @(Import-Csv $p) } catch { return @() }
}

W "plan: wait L MR x3 -> high_ram W3 Spark S,M,L x3 -> low_ram W3 Spark S,M,L x3 -> W2"

while ($true) {
  $rows = Get-W3
  $lMr = @($rows | Where-Object { $_.size -eq "L" -and $_.engine -eq "mapreduce" })
  $exp = Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine -match "run_experiment\.py.*low_ram" }
  W "W3 rows=$($rows.Count) L_MR=$($lMr.Count) exp=$([bool]$exp)"
  if ($lMr.Count -ge 3) { break }
  Start-Sleep -Seconds 20
}

W "pause low_ram runners"
Get-CimInstance Win32_Process | Where-Object {
  $_.CommandLine -and ($_.CommandLine -match "run_low_ram_matrix\.ps1|run_experiment\.py")
} | ForEach-Object {
  W "kill $($_.ProcessId)"
  Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
}
Start-Sleep -Seconds 3
try {
  docker exec hs-resourcemanager yarn application -list 2>&1 | Select-String "application_" | ForEach-Object {
    $id = [regex]::Match($_.Line, "application_\d+_\d+").Value
    if ($id) { docker exec hs-resourcemanager yarn application -kill $id 2>&1 | Out-Null }
  }
} catch {}

W "compose_up high_ram"
& "$Root\scripts\compose_up.ps1" -Profile high_ram
if ($LASTEXITCODE -ne 0) { W "compose_up high_ram failed"; exit 1 }
& "$Root\scripts\ensure_python_in_hadoop.ps1"

$envPath = Join-Path $Root ".env.high_ram"
$orig = Get-Content $envPath -Raw
$tmp = $orig -replace "SPARK_DRIVER_MEMORY=\S+", "SPARK_DRIVER_MEMORY=12g" -replace "SPARK_EXECUTOR_MEMORY=\S+", "SPARK_EXECUTOR_MEMORY=12g"
[System.IO.File]::WriteAllText($envPath, $tmp)

$csv = Join-Path $Root "results\results_high_ram_W3.csv"
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
Copy-Item $csv ($csv + ".bak_before_spark_rerun_" + $stamp) -Force
python "$Root\scripts\_keep_mr_only.py" $csv

try {
  W ">>> high_ram W3 Spark S,M,L x3 (new pagerank, driver=12g)"
  & python "$Root\scripts\run_experiment.py" --condition high_ram --workloads W3 --sizes S,M,L --engines spark --trials 3 --results $csv
  W "high_ram W3 Spark rerun exit=$LASTEXITCODE"
  Import-Csv $csv | Where-Object { $_.engine -eq "spark" } | ForEach-Object {
    W ("ROW high spark " + $_.size + " t" + $_.trial + " ok=" + $_.ok + " wall=" + $_.wall_sec)
  }
} finally {
  [System.IO.File]::WriteAllText($envPath, $orig)
  W "restored .env.high_ram"
}

W "compose_up low_ram + rerun W3 Spark S,M,L"
& "$Root\scripts\compose_up.ps1" -Profile low_ram
if ($LASTEXITCODE -ne 0) { W "compose_up low_ram failed"; exit 1 }
& "$Root\scripts\ensure_python_in_hadoop.ps1"

$w3 = Join-Path $Root "results\results_low_ram_W3.csv"
Copy-Item $w3 ($w3 + ".bak_before_spark_rerun_" + $stamp) -Force
python "$Root\scripts\_keep_mr_only.py" $w3
W ">>> low_ram W3 Spark S,M,L x3 (new pagerank)"
& python "$Root\scripts\run_experiment.py" --condition low_ram --workloads W3 --sizes S,M,L --engines spark --trials 3 --results $w3
W "low_ram W3 Spark rerun exit=$LASTEXITCODE"
Import-Csv $w3 | Where-Object { $_.engine -eq "spark" } | ForEach-Object {
  W ("ROW low spark " + $_.size + " t" + $_.trial + " ok=" + $_.ok + " wall=" + $_.wall_sec)
}

$w2 = Join-Path $Root "results\results_low_ram_W2.csv"
W ">>> low_ram W2 S,M,L MR+Spark x3"
& python "$Root\scripts\run_experiment.py" --condition low_ram --workloads W2 --sizes S,M,L --engines mapreduce,spark --trials 3 --results $w2
W "plan complete"
