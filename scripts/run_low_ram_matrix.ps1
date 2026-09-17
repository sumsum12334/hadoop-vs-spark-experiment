$Root = "C:\git\ust\hadoop-vs-spark-experiment"
Set-Location $Root
$ErrorActionPreference = "Continue"
$log = Join-Path $Root "results\low_ram_matrix.out.log"
function W($m){ $line = "$(Get-Date -Format o) $m"; Add-Content -Path $log -Value $line -Encoding utf8; Write-Host $line }
W ("=== low_ram matrix restart (AM=256) " + (Get-Date -Format o) + " ===")
foreach ($wl in @("W1","W3","W2")) {
  $out = Join-Path $Root ("results\results_low_ram_" + $wl + ".csv")
  if (Test-Path $out) {
    Copy-Item $out ($out + ".bak_stuck_" + (Get-Date -Format "yyyyMMdd_HHmmss")) -Force -ErrorAction SilentlyContinue
    Remove-Item $out -Force -ErrorAction SilentlyContinue
  }
  W (">>> low_ram $wl S,M,L -> $out")
  & python "$Root\scripts\run_experiment.py" --condition low_ram --workloads $wl --sizes S,M,L --engines mapreduce,spark --trials 3 --results $out
  if ($LASTEXITCODE -ne 0) { W "FAILED low_ram $wl code=$LASTEXITCODE"; exit 1 }
}
& python "$Root\scripts\merge_results.py"
try { & python "$Root\scripts\plot_results.py" --csv "$Root\results\results_all.csv" } catch { W "plot warn: $_" }
W "low_ram matrix complete"
