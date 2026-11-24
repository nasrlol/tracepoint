# Controleert of een proces draait en logt geheugen en CPU-tijd. Leest alleen, grijpt nergens in.
# Logt via omleiding (>>), een derde logvorm voor de parser (M2).
param(
  [int]$Iterations = 0,          # 0 = blijven lopen
  [double]$IntervalSeconds = 5,
  [string]$Name = 'pwsh'
)
$ErrorActionPreference = 'Stop'
$Sandbox = if ($env:TRACE_SANDBOX) { $env:TRACE_SANDBOX } else { Join-Path $PSScriptRoot '../sandbox' }
$logFile = Join-Path $Sandbox 'logs/process.log'
$null = New-Item -ItemType Directory -Force (Split-Path $logFile)

for ($teller = 1; $Iterations -eq 0 -or $teller -le $Iterations; $teller++) {
  $procs = @(Get-Process -Name $Name -ErrorAction Ignore)
  if ($procs.Count -eq 0) {
    "$(Get-Date -Format o) $Name draait niet" >> $logFile
  } else {
    $memMB = [math]::Round(($procs | Measure-Object WorkingSet64 -Sum).Sum / 1MB, 1)
    $cpu = [math]::Round(($procs | Measure-Object CPU -Sum).Sum, 1)
    "$(Get-Date -Format o) $Name x$($procs.Count) geheugen=${memMB}MB cpu=${cpu}s" >> $logFile
  }
  Start-Sleep -Seconds $IntervalSeconds
}
