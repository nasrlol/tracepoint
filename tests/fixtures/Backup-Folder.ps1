# Maakt telkens een zip van een datamap en houdt de laatste N back-ups.
# Doelwit voor tracepoints (M4): volg $teller en $size zonder het script te stoppen.
param(
  [int]$Iterations = 0,          # 0 = blijven lopen
  [double]$IntervalSeconds = 3,
  [int]$Keep = 5
)
$ErrorActionPreference = 'Stop'
$Sandbox = if ($env:TRACE_SANDBOX) { $env:TRACE_SANDBOX } else { Join-Path $PSScriptRoot '../sandbox' }
$dataDir = Join-Path $Sandbox 'data'
$backupDir = Join-Path $Sandbox 'backup'
$null = New-Item -ItemType Directory -Force $dataDir, $backupDir

# Startdata als de map leeg is.
if (-not (Get-ChildItem $dataDir)) {
  1..5 | ForEach-Object { "document $_" | Set-Content (Join-Path $dataDir "doc$_.txt") }
}

for ($teller = 1; $Iterations -eq 0 -or $teller -le $Iterations; $teller++) {
  # De data verandert tussen twee back-ups.
  "wijziging $teller op $(Get-Date -Format o)" | Add-Content (Join-Path $dataDir 'changes.txt')

  $zip = Join-Path $backupDir "backup-$(Get-Date -Format 'yyyyMMdd-HHmmss-fff').zip"
  Compress-Archive -Path (Join-Path $dataDir '*') -DestinationPath $zip
  $size = (Get-Item $zip).Length
  "back-up $teller -> $(Split-Path $zip -Leaf) ($size bytes)"

  Get-ChildItem $backupDir -Filter 'backup-*.zip' |
    Sort-Object Name -Descending |
    Select-Object -Skip $Keep |
    Remove-Item
  Start-Sleep -Seconds $IntervalSeconds
}
