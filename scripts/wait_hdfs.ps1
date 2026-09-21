$ErrorActionPreference = 'Continue'
Write-Host 'Waiting for HDFS namenode...'
for ($i = 1; $i -le 60; $i++) {
  docker exec hs-namenode hdfs dfs -ls / 2>$null | Out-Null
  if ($LASTEXITCODE -eq 0) {
    Write-Host 'HDFS is up.'
    exit 0
  }
  Start-Sleep -Seconds 5
}
Write-Error 'HDFS did not become ready in time'
exit 1
