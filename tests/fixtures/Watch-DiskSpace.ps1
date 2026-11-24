# Bewaakt de vrije schijfruimte en waarschuwt onder een drempel.
# Logt via Start-Transcript (doelwit voor M2: de parser moet dit logpad vinden).
param(
  [int]$Iterations = 0,          # 0 = blijven lopen
  [double]$IntervalSeconds = 5,
  [int]$ThresholdPercent = 10
)
$ErrorActionPreference = 'Stop'
$Sandbox = if ($env:TRACE_SANDBOX) { $env:TRACE_SANDBOX } else { Join-Path $PSScriptRoot '../sandbox' }
$logFile = Join-Path $Sandbox 'logs/diskspace.log'
$null = New-Item -ItemType Directory -Force (Split-Path $logFile)

$null = Start-Transcript -Path $logFile -Append
try {
  for ($teller = 1; $Iterations -eq 0 -or $teller -le $Iterations; $teller++) {
    foreach ($drive in Get-PSDrive -PSProvider FileSystem) {
      $total = $drive.Used + $drive.Free
      if ($total -eq 0) { continue }
      $freePercent = [math]::Round($drive.Free / $total * 100, 1)
      if ($freePercent -lt $ThresholdPercent) {
        Write-Warning "$($drive.Root): nog $freePercent% vrij (drempel $ThresholdPercent%)"
      } else {
        "$(Get-Date -Format s) $($drive.Root): $freePercent% vrij"
      }
    }
    Start-Sleep -Seconds $IntervalSeconds
  }
} finally {
  $null = Stop-Transcript
}
