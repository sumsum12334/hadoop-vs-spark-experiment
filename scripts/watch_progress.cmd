@echo off
title Hadoop MVP Progress
cd /d "C:\git\ust\hadoop-vs-spark-experiment"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\git\ust\hadoop-vs-spark-experiment\scripts\watch_progress.ps1"
pause
