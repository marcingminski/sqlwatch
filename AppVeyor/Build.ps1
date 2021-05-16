$job = Start-Job -Name TestSpace -ScriptBlock { 
    cd c:\projects\sqlwatch\SqlWatch.Test
    Start-FileDownload https://testspace-client.s3.amazonaws.com/testspace-windows.zip 
    7z x -y testspace-windows.zip
    }
    
    $ErrorActionPreference = "Stop"
    
    .\SQLWATCH-Build-Release.ps1
    if ($LastExitCode -ne 0) { $host.SetShouldExit($LastExitCode)  }
    
    Get-Job | Wait-Job | Receive-Job | Format-Table
    
    If ((Get-Job | Where-Object {$_.State -eq "Failed"}).Count -gt 0){
        Get-Job | Foreach-Object {$_.JobStateInfo.Reason}
        $host.SetShouldExit(1)
    }
    
    Get-Job | Format-Table -Autosize