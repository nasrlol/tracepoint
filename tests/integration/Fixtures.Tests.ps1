# Draait elke fixture echt, kort, in een eigen sandbox ($TestDrive), en kijkt na of ze doet wat
# Trace later moet kunnen vinden. Hier komen ook de integratietests van Trace zelf.

BeforeAll {
  $fixtures = Join-Path $PSScriptRoot '../fixtures'
  $pwsh = (Get-Process -Id $PID).Path

  function Invoke-Fixture([string]$Name, [string[]]$Arguments = @()) {
    $env:TRACE_SANDBOX = $TestDrive
    try {
      $output = & $pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $fixtures "$Name.ps1") @Arguments 2>&1
      [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output | Out-String }
    } finally {
      Remove-Item Env:TRACE_SANDBOX
    }
  }
}

Describe 'Invoke-Crash' {
  BeforeAll { $run = Invoke-Fixture Invoke-Crash '-IntervalSeconds', '0' }

  It 'crasht met een exitcode verschillend van 0' {
    $run.ExitCode | Should -Not -Be 0
  }

  It 'crasht op regel 12, na 4 gezonde rondes' {
    $run.Output | Should -Match 'Invoke-Crash\.ps1:12'
    ($run.Output | Select-String 'gezond' -AllMatches).Matches.Count | Should -Be 4
  }
}

Describe 'Watch-DiskSpace' {
  It 'logt via Start-Transcript naar logs/diskspace.log' {
    $run = Invoke-Fixture Watch-DiskSpace '-Iterations', '1', '-IntervalSeconds', '0'
    $run.ExitCode | Should -Be 0
    Join-Path $TestDrive 'logs/diskspace.log' | Should -FileContentMatch 'vrij'
  }
}

Describe 'Invoke-LogRotation' {
  It 'roteert app.log en houdt hoogstens -Keep archieven' {
    $run = Invoke-Fixture Invoke-LogRotation '-Iterations', '10', '-IntervalSeconds', '0', '-MaxKB', '1', '-Keep', '2'
    $run.ExitCode | Should -Be 0
    Join-Path $TestDrive 'app/app.log.1' | Should -Exist
    Join-Path $TestDrive 'app/app.log.3' | Should -Not -Exist
    Join-Path $TestDrive 'app/rotation.log' | Should -FileContentMatch 'geroteerd'
  }
}

Describe 'Backup-Folder' {
  It 'maakt zips en houdt er hoogstens -Keep' {
    $run = Invoke-Fixture Backup-Folder '-Iterations', '4', '-IntervalSeconds', '0', '-Keep', '2'
    $run.ExitCode | Should -Be 0
    @(Get-ChildItem (Join-Path $TestDrive 'backup') -Filter '*.zip').Count | Should -Be 2
  }
}

Describe 'Watch-Process' {
  It 'logt het eigen pwsh-proces naar logs/process.log' {
    # Op NixOS heet het proces '.pwsh-wrapped', niet 'pwsh': de echte naam nemen.
    $name = (Get-Process -Id $PID).ProcessName
    $run = Invoke-Fixture Watch-Process '-Iterations', '1', '-IntervalSeconds', '0', '-Name', $name
    $run.ExitCode | Should -Be 0
    Join-Path $TestDrive 'logs/process.log' | Should -FileContentMatch "$([regex]::Escape($name)) x\d+ geheugen="
  }
}

Describe 'Sync-Users' {
  BeforeAll { $run = Invoke-Fixture Sync-Users '-Iterations', '5', '-IntervalSeconds', '0' }

  It 'maakt een map en profiel per gebruiker uit de CSV' {
    $run.ExitCode | Should -Be 0
    @(Get-ChildItem (Join-Path $TestDrive 'home') -Directory).Count | Should -Be 5
  }

  It 'schrijft geen wachtwoord weg' {
    Get-ChildItem $TestDrive -Recurse -File | Get-Content -Raw | Should -Not -Match 'Password|SecureString'
  }
}
