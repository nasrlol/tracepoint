#!/usr/bin/env pwsh
# Een ingang voor lokaal, CI en Emacs.
#
#   ./build.ps1               alles: lint, unit, integration
#   ./build.ps1 test          unit + integration
#   ./build.ps1 unit          Pester-unittests (snel, met Mock, start niets)
#   ./build.ps1 integration   Pester-integratietests (draait de fixtures in tests/fixtures/)
#   ./build.ps1 lint          PSScriptAnalyzer op source/, tests/ en build.ps1
#
# Testresultaten (NUnit XML, voor de CI-runner) komen in build/.
[CmdletBinding()]
param(
  [ValidateSet('all', 'test', 'unit', 'integration', 'lint')]
  [string[]]$Task = 'all'
)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$Task = $Task | ForEach-Object {
  switch ($_) {
    'all' { 'lint', 'unit', 'integration' }
    'test' { 'unit', 'integration' }
    default { $_ }
  }
} | Select-Object -Unique

function Invoke-Lint {
  # PSScriptAnalyzer zit in PowerShell Editor Services (shell.nix); anders uit de Gallery.
  if ($env:PSES_BUNDLE_PATH) { Import-Module (Join-Path $env:PSES_BUNDLE_PATH 'PSScriptAnalyzer') }
  else { Import-Module PSScriptAnalyzer }
  $severity = 'Warning', 'Error', 'ParseError'
  $findings = @(
    Invoke-ScriptAnalyzer -Path source -Recurse -Severity $severity
    Invoke-ScriptAnalyzer -Path build.ps1 -Severity $severity
    # Pester: variabelen uit BeforeAll / BeforeDiscovery ziet de analyzer als ongebruikt.
    Invoke-ScriptAnalyzer -Path tests -Recurse -Severity $severity -ExcludeRule PSUseDeclaredVarsMoreThanAssignments
  )
  if ($findings) {
    $findings | Format-Table RuleName, Severity, ScriptName, Line, Message -AutoSize -Wrap | Out-String | Write-Output
  }
  "lint: $(@($findings).Count) bevinding(en)"
  @($findings).Count -eq 0
}

function Invoke-Test([string]$Kind) {
  Import-Module Pester -MinimumVersion 5.5
  $config = New-PesterConfiguration
  $config.Run.Path = "tests/$Kind"
  $config.Run.PassThru = $true
  $config.Output.Verbosity = 'Detailed'
  $config.TestResult.Enabled = $true
  $config.TestResult.OutputFormat = 'NUnitXml'
  $config.TestResult.OutputPath = "build/$Kind-results.xml"
  $result = Invoke-Pester -Configuration $config
  $result.FailedCount -eq 0 -and $result.Result -eq 'Passed'
}

# Elke taak geeft eerst zijn uitvoer en als laatste $true of $false.
$failed = [System.Collections.Generic.List[string]]::new()
foreach ($t in $Task) {
  "== $t"
  $out = switch ($t) {
    'lint' { Invoke-Lint }
    'unit' { Invoke-Test unit }
    'integration' { Invoke-Test integration }
  }
  $out | Select-Object -SkipLast 1
  if (-not ($out | Select-Object -Last 1)) { $failed.Add($t) }
}

if ($failed) {
  Write-Error "mislukt: $($failed -join ', ')" -ErrorAction Continue
  exit 1
}
"alles geslaagd: $($Task -join ', ')"
