# Host -> SSH remoting -> named pipe into the running hello.ps1 pwsh process -> breakpoints with actions.
param([int]$Seconds = 7)
$opt = @{ StrictHostKeyChecking = 'no'; UserKnownHostsFile = '/dev/null'; LogLevel = 'ERROR' }
$s = New-PSSession -HostName 127.0.0.1 -Port 2222 -UserName dbg -KeyFilePath "$PSScriptRoot/key" -Options $opt
try {
  Invoke-Command $s -ArgumentList $Seconds {
    param($Seconds)
    $target = Get-Process pwsh | Where-Object { $_.Id -ne $PID -and $_.CommandLine -match 'hello\.ps1' }
    $ci = [System.Management.Automation.Runspaces.NamedPipeConnectionInfo]::new($target.Id)
    $rs = [runspacefactory]::CreateRunspace($ci)   # runs *inside* the target process
    $rs.Open()
    $ps = [powershell]::Create(); $ps.Runspace = $rs
    $null = $ps.AddScript({
      param($Seconds)
      $r = Get-Runspace -Id 1                      # the runspace executing hello.ps1
      $script = '/opt/hello.ps1'
      [AppDomain]::CurrentDomain.SetData('tp', [Collections.Concurrent.ConcurrentQueue[string]]::new())
      # Set-PSBreakpoint -Runspace refuses here ("remote debugging is not supported by the current host"),
      # so use the Debugger API directly. Actions are unbound script blocks so they bind to the target
      # runspace when they fire; no 'break' in the action => the script keeps running.
      $d = $r.Debugger
      $bp = @(
        $d.SetVariableBreakpoint('i', 'Write', [scriptblock]::Create(
          '[AppDomain]::CurrentDomain.GetData("tp").Enqueue("tracepoint: i=$i")'), $script)
        $d.SetLineBreakpoint($script, 1, 0, [scriptblock]::Create(
          '[AppDomain]::CurrentDomain.GetData("tp").Enqueue("snapshot: n=$n i=$i stack=" + ((Get-PSCallStack | Select-Object -Skip 1 | ForEach-Object Location) -join " <- "))'))
      )
      Start-Sleep $Seconds
      $bp | ForEach-Object { $null = $d.RemoveBreakpoint($_) }
      [AppDomain]::CurrentDomain.GetData('tp').ToArray()
    }).AddArgument($Seconds)
    "attached to pid $($target.Id) ($($target.CommandLine))"
    $ps.Invoke()
    $ps.Streams.Error | ForEach-Object { "ERROR: $_" }
    $rs.Dispose()
  }
} finally { Remove-PSSession $s }
