# Ensure C:\git\dev exists (run on Polly's Windows machine)
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force -Path 'C:\git' | Out-Null
New-Item -ItemType Directory -Force -Path 'C:\git\dev' | Out-Null
Write-Host "Ready: C:\git\dev"
