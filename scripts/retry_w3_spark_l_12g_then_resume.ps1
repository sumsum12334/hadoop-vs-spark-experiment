$Root = "C:\git\ust\hadoop-vs-spark-experiment"
Set-Location $Root
$ErrorActionPreference = "Continue"
$log = Join-Path $Root "results\w3_spark_retry.out.log"
function W($m){ $line = "$(Get-Date -Format o) $m"; Add-Content -Path $log -Value $line -Encoding utf8; Write-Host $line }

function Get-W3 {
  $p = Join-Path $Root "results\results_low_ram_W3.csv"
  if (-not (Test-Path $p)) { return @() }
  try { return @(Import-Csv $p) } catch { return @() }
}

W "wait until low_ram W3 L MapReduce x3 done (15 rows) then pause before Spark L"

while ($true) {
  $rows = Get-W3
  $lMr = @($rows | Where-Object { $_.size -eq "L" -and $_.engine -eq "mapreduce" })
  $n = $rows.Count
  $exp = Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine -match "run_experiment\.py.*low_ram" }
  W "W3 rows=$n L_MR=$($lMr.Count) exp=$([bool]$exp)"
  if ($lMr.Count -ge 3) { W "L MR x3 present - pause low_ram"; break }
  Start-Sleep -Seconds 20
}

# Kill low_ram runner so it does not start Spark L yet
Get-CimInstance Win32_Process | Where-Object {
  $_.CommandLine -and ($_.CommandLine -match "run_low_ram_matrix\.ps1|run_experiment\.py")
} | ForEach-Object {
  W "kill $($_.ProcessId)"
  Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
}
Start-Sleep -Seconds 3
try { docker exec hs-resourcemanager yarn application -list 2>&1 | Select-String "application_" | ForEach-Object {
  $id = [regex]::Match($_.Line, "application_\d+_\d+").Value
  if ($id) { docker exec hs-resourcemanager yarn application -kill $id 2>&1 | Out-Null }
}} catch {}

W "compose_up high_ram for W3 Spark L retry (driver 12g, upload ON)"
& "$Root\scripts\compose_up.ps1" -Profile high_ram
if ($LASTEXITCODE -ne 0) { W "compose_up high_ram failed $LASTEXITCODE"; exit 1 }
& "$Root\scripts\ensure_python_in_hadoop.ps1"

$retryCsv = Join-Path $Root "results\results_high_ram_W3_spark_L_retry12g.csv"
if (Test-Path $retryCsv) { Copy-Item $retryCsv ($retryCsv + ".bak") -Force }

W ">>> high_ram W3 Spark L x1 driver=12g -> $retryCsv (does not overwrite main W3 csv)"
# Temporarily point .env driver to 12g for this run only, then restore
$envPath = Join-Path $Root ".env.high_ram"
$orig = Get-Content $envPath -Raw
$tmp = $orig -replace "SPARK_DRIVER_MEMORY=4g", "SPARK_DRIVER_MEMORY=12g" -replace "SPARK_EXECUTOR_MEMORY=8g", "SPARK_EXECUTOR_MEMORY=12g"
[System.IO.File]::WriteAllText($envPath, $tmp)
try {
  & python "$Root\scripts\run_experiment.py" --condition high_ram --workloads W3 --sizes L --engines spark --trials 1 --results $retryCsv
  W "retry exit=$LASTEXITCODE"
} finally {
  [System.IO.File]::WriteAllText($envPath, $orig)
  W "restored .env.high_ram"
}

if (Test-Path $retryCsv) {
  $rr = Import-Csv $retryCsv
  foreach ($row in $rr) { W ("RETRY " + $row.engine + " " + $row.size + " t" + $row.trial + " ok=" + $row.ok + " wall=" + $row.wall_sec) }
}

W "resume low_ram: remaining W3 Spark L x3 then W2"
& "$Root\scripts\compose_up.ps1" -Profile low_ram
if ($LASTEXITCODE -ne 0) { W "compose_up low_ram failed"; exit 1 }
& "$Root\scripts\ensure_python_in_hadoop.ps1"

$w3 = Join-Path $Root "results\results_low_ram_W3.csv"
W ">>> low_ram W3 Spark L x3 (append to existing csv)"
& python "$Root\scripts\run_experiment.py" --condition low_ram --workloads W3 --sizes L --engines spark --trials 3 --results $w3 --skip-upload
# skip-upload may fail if compose wiped HDFS - so if files missing, re-upload
if ($LASTEXITCODE -ne 0) {
  W "spark L without upload failed, retry with upload"
  & python "$Root\scripts\run_experiment.py" --condition low_ram --workloads W3 --sizes L --engines spark --trials 3 --results $w3
}

$w2 = Join-Path $Root "results\results_low_ram_W2.csv"
W ">>> low_ram W2 S,M,L"
& python "$Root\scripts\run_experiment.py" --condition low_ram --workloads W2 --sizes S,M,L --engines mapreduce,spark --trials 3 --results $w2
W "done retry+resume"
