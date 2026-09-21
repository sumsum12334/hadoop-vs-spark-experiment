
Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and ($_.CommandLine -match 'run_experiment|run_mvp_resume|mvp_resume') } | ForEach-Object { Write-Output ("PID=" + $_.ProcessId + "|" + $_.Name + "|" + $_.CommandLine) }
