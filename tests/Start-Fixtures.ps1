#!/usr/bin/env pwsh
# Start de fixtures als losse pwsh-processen op de achtergrond, met het scriptpad in de
# opdrachtregel (-File), zodat Find-TraceScript ze vindt zoals op een echte server.
# PID's komen in sandbox/pids.json; Stop-Fixtures.ps1 stopt alleen die processen.
#
#   ./tests/Start-Fixtures.ps1                      alle fixtures
#   ./tests/Start-Fixtures.ps1 -Name Backup-Folder  een deel
[CmdletBinding()]
param(
  [string[]]$Name = '*'
)
$ErrorActionPreference = 'Stop'
$Sandbox = if ($env:TRACE_SANDBOX) { $env:TRACE_SANDBOX } else { Join-Path $PSScriptRoot 'sandbox' }
$outDir = Join-Path $Sandbox 'out'
$pidFile = Join-Path $Sandbox 'pids.json'
$null = New-Item -ItemType Directory -Force $outDir

if (Test-Path $pidFile) {
  throw "$pidFile bestaat al: draaien de fixtures nog? Eerst ./tests/Stop-Fixtures.ps1"
}

$pwsh = (Get-Process -Id $PID).Path
$scripts = Get-ChildItem (Join-Path $PSScriptRoot 'fixtures') -Filter '*.ps1' |
  Where-Object { $n = $_.BaseName; $Name | Where-Object { $n -like $_ } }

$started = foreach ($script in $scripts) {
  $p = Start-Process -FilePath $pwsh -PassThru `
    -ArgumentList '-NoLogo', '-NoProfile', '-NonInteractive', '-File', $script.FullName `
    -RedirectStandardOutput (Join-Path $outDir "$($script.BaseName).out") `
    -RedirectStandardError (Join-Path $outDir "$($script.BaseName).err")
  [pscustomobject]@{ Name = $script.BaseName; Id = $p.Id; Path = $script.FullName }
}

$started | ConvertTo-Json -AsArray | Set-Content $pidFile
$started | Format-Table -AutoSize | Out-String | Write-Output
"uitvoer per fixture in $outDir"
