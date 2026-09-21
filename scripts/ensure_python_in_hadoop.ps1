$ErrorActionPreference = "Stop"
foreach ($c in @("hs-namenode","hs-nodemanager")) {
  docker exec $c bash -lc "command -v python3" 2>$null | Out-Null
  if ($LASTEXITCODE -eq 0) {
    Write-Host "${c}: python3 OK"
  } else {
    Write-Host "${c}: installing python3..."
    docker exec -u root $c bash -lc "if command -v apt-get >/dev/null 2>&1; then apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq python3; elif command -v microdnf >/dev/null 2>&1; then microdnf install -y python3; elif command -v yum >/dev/null 2>&1; then yum install -y python3; else echo no pkgmgr; exit 1; fi"
  }
  docker exec $c python3 --version
}
