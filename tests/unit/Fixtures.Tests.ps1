# Bewaakt wat de demo en de andere tests van de fixtures verwachten, zonder ze te starten.

BeforeDiscovery {
  $fixtures = Get-ChildItem (Join-Path $PSScriptRoot '../fixtures') -Filter '*.ps1' |
    ForEach-Object { @{ Name = $_.BaseName; Path = $_.FullName } }
}

Describe 'fixture <Name>' -ForEach $fixtures {
  BeforeAll {
    $tokens = $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
  }

  It 'parset zonder fouten' {
    $errors | Should -BeNullOrEmpty
  }

  It 'gebruikt de sandbox ($env:TRACE_SANDBOX)' {
    $ast.Extent.Text | Should -Match ([regex]::Escape('$env:TRACE_SANDBOX'))
  }

  It 'heeft -Iterations, behalve Invoke-Crash' -Skip:($Name -eq 'Invoke-Crash') {
    $ast.ParamBlock.Parameters.Name.VariablePath.UserPath | Should -Contain 'Iterations'
  }
}

Describe 'Invoke-Crash (demo: crash op regel 12 met $teller = 5)' {
  BeforeAll {
    $lines = Get-Content (Join-Path $PSScriptRoot '../fixtures/Invoke-Crash.ps1')
  }

  It 'leest op regel 12 het statusbestand' {
    $lines[11] | Should -Match '^\s*\$status = Get-Content \$statusFile'
  }

  It 'verwijdert het statusbestand op regel 11 als $teller 5 is' {
    $lines[10] | Should -Match '\$teller -eq 5.*Remove-Item \$statusFile'
  }
}

Describe 'Invoke-Mule (vaste regels voor breakpoints)' {
  BeforeAll {
    $lines = Get-Content (Join-Path $PSScriptRoot '../fixtures/Invoke-Mule.ps1')
  }

  It 'heeft $teller++ op regel 28' {
    $lines[27] | Should -Match '^\s*\$teller\+\+\s*$'
  }

  It 'heeft $even in Get-Status op regel 20' {
    $lines[19] | Should -Match '^\s*\$even = '
  }
}
