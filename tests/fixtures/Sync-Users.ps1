# "Provisioneert" gebruikers uit een CSV: een map en een profiel per gebruiker in de sandbox,
# geen echte accounts (naar het labo "populate AD" uit het vak, maar met mappen).
# Elke gebruiker krijgt een PSCredential in het geheugen: doelwit voor het maskeren (M3).
# Het wachtwoord mag nooit in een bestand, een log of een crashrapport terechtkomen.
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '',
  Justification = 'Testdata: willekeurig wachtwoord dat alleen in het geheugen bestaat.')]
param(
  [int]$Iterations = 0,          # 0 = blijven lopen
  [double]$IntervalSeconds = 2,
  [string]$CsvPath = (Join-Path $PSScriptRoot 'data/users.csv')
)
$ErrorActionPreference = 'Stop'
$Sandbox = if ($env:TRACE_SANDBOX) { $env:TRACE_SANDBOX } else { Join-Path $PSScriptRoot '../sandbox' }
$homeRoot = Join-Path $Sandbox 'home'
$null = New-Item -ItemType Directory -Force $homeRoot

$users = Import-Csv $CsvPath
for ($teller = 1; $Iterations -eq 0 -or $teller -le $Iterations; $teller++) {
  # Per ronde een gebruiker, in een lus over de CSV.
  $user = $users[($teller - 1) % $users.Count]
  $password = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 16 | ForEach-Object { [char]$_ })
  $credential = [pscredential]::new($user.Name, (ConvertTo-SecureString $password -AsPlainText -Force))

  $userHome = Join-Path $homeRoot $user.Name
  $null = New-Item -ItemType Directory -Force $userHome
  [pscustomobject]@{
    Name       = $credential.UserName
    Department = $user.Department
    Title      = $user.Title
    Created    = (Get-Date).ToString('o')
  } | ConvertTo-Json | Set-Content (Join-Path $userHome 'profile.json')

  "gebruiker $($credential.UserName) ($($user.Department)) geprovisioneerd"
  Start-Sleep -Seconds $IntervalSeconds
}
