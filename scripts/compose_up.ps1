param(
  [ValidateSet("high_ram","low_ram")]
  [string]$Profile = "high_ram"
)
$ErrorActionPreference = "Continue"
$Root = Split-Path -Parent $PSScriptRoot
if (-not $Root) { $Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path }
$EnvFile = Join-Path $Root ".env.$Profile"
if (-not (Test-Path $EnvFile)) { throw "Missing $EnvFile" }
Set-Location $Root
docker compose --env-file $EnvFile up -d
if ($LASTEXITCODE -ne 0) { throw "docker compose up failed (exit $LASTEXITCODE)" }
& (Join-Path $PSScriptRoot "wait_hdfs.ps1")
if ($LASTEXITCODE -ne 0) { throw "HDFS wait failed" }
& (Join-Path $PSScriptRoot "ensure_python_in_hadoop.ps1")
if ($LASTEXITCODE -ne 0) { throw "ensure_python failed" }
Write-Host "Compose up with $Profile"
