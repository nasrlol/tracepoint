# for the parser
using namespace System.Management.Automation.Language;

# author: nasr
# description: cross platform powershell debugger that allows for reomte attaching

function Trace-Gui {

  #TODO: ... 

}

function Trace-List-All-Targets {
  # Just gets a list of all runnning processes.
  # We want to filter on poewrshell processes
  # Get-Process
  # Enter-PSHostProcessInfo

  ## NICE: gives all running powrshell processes
  Get-PSHostProcessInfo

}

function Trace-Parse-Function-Crash-Output {

}



# Does not depend on WSMAN (winrm thing)
# Basically creates an IPC connectoin to the target id 
# https://learn.microsoft.com/en-us/dotnet/api/system.management.automation.runspaces.namedpipeconnectioninfo?view=powershellsdk-7.6.0

function Trace-Attach-To-Target {
  [CmdletBinding()]
  param([Parameter(Mandatory)][int]$Id)

  Get-PSCallStack($Id)
  $file_ast = [Parser]::ParseFile()

  $file_ast;
}

function Trace-Handle-Debug-Action {
  # https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_debuggers?view=powershell-7.6
  # Set-PSBreakpoint: Sets breakpoints on lines, variables, and commands.
  # Get-PSBreakpoint: Gets breakpoints in the current session.
  # Disable-PSBreakpoint: Turns off breakpoints in the current session.
  # Enable-PSBreakpoint: Re-enables breakpoints in the current session.
  # Remove-PSBreakpoint: Deletes breakpoints from the current session.
  # Get-PSCallStack: Displays the current call stack.
}


function Trace-Get-Back-Trace {
  param([Parameter(Mandatory)][int]$Id)
  # TODO: this doesnt work when in a script.
  # we need to call an api that handles this
  # because we're in a differnet runspace
  Enter-PSHostProcess -Id  $Id
  Debug-Runspace -Id 1
  Get-PSCallStack
}


# TODO: add autocompletion for typing out the id
# TODO: we should be able to handle and match the ids with the window names



function Trace-Start-Repl {

  while($true)
  {

    # Read-Host reads stdin and prints the input 'trace'
    $line = Read-Host 'trace'
    # split the commands that are passed into cmds and arguments
    $cmd, $arg = $line -split ' ', 2

    switch($cmd)
    {

      "list"   { Trace-List-All-Targets | Out-Host }
      "attach" { Trace-Attach-To-Target $arg       }
      "bt"     { Trace-Get-Back-Trace $arg         }
    }
  }
}


Trace-Start-Repl;
