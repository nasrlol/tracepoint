# Schrijft een applicatielog en roteert het boven een maximale grootte; houdt de laatste N archieven.
# Logt via Add-Content en Out-File (doelwit voor M2).
param(
  [int]$Iterations = 0,          # 0 = blijven lopen
  [double]$IntervalSeconds = 1,
  [int]$MaxKB = 4,
  [int]$Keep = 3
)
$ErrorActionPreference = 'Stop'
$Sandbox = if ($env:TRACE_SANDBOX) { $env:TRACE_SANDBOX } else { Join-Path $PSScriptRoot '../sandbox' }
$appDir = Join-Path $Sandbox 'app'
$appLog = Join-Path $appDir 'app.log'
$rotationLog = Join-Path $appDir 'rotation.log'
$null = New-Item -ItemType Directory -Force $appDir

$levels = 'INFO', 'INFO', 'INFO', 'WARN', 'ERROR'
for ($teller = 1; $Iterations -eq 0 -or $teller -le $Iterations; $teller++) {
  # Een paar regels "applicatie-uitvoer" per ronde.
  1..20 | ForEach-Object {
    "$(Get-Date -Format o) $(Get-Random $levels) request=$teller.$_ duur=$(Get-Random -Maximum 500)ms"
  } | Add-Content -Path $appLog

  if ((Get-Item $appLog).Length -gt $MaxKB * 1KB) {
    # app.log.(Keep-1) -> app.log.Keep, ..., app.log -> app.log.1; alles boven Keep weg.
    Remove-Item "$appLog.$Keep" -ErrorAction Ignore
    for ($i = $Keep - 1; $i -ge 1; $i--) {
      if (Test-Path "$appLog.$i") { Move-Item "$appLog.$i" "$appLog.$($i + 1)" -Force }
    }
    Move-Item $appLog "$appLog.1" -Force
    "$(Get-Date -Format o) geroteerd in ronde $teller" | Out-File -FilePath $rotationLog -Append
  }
  Start-Sleep -Seconds $IntervalSeconds
}
