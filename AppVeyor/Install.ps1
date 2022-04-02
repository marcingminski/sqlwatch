#AppVeyor Install script gets called right after the repo cloning

#Set all installed instances of SQL server to dynamic ports
Get-ChildItem -Path 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\' |
    Where-Object {
        $_.Name -imatch 'MSSQL[_\d]+\.SQL.*'
    } |
    ForEach-Object {

        Write-Host "Setting $((Get-ItemProperty $_.PSPath).'(default)') to dynamic ports"
        Set-ItemProperty (Join-Path $_.PSPath 'mssqlserver\supersocketnetlib\tcp\ipall') -Name TcpDynamicPorts -Value '0'
        Set-ItemProperty (Join-Path $_.PSPath 'mssqlserver\supersocketnetlib\tcp\ipall') -Name TcpPort -Value ([string]::Empty)
    }

#Install Modules
Start-Job -Name GetPester -ScriptBlock { powershell -command Install-Module Pester -RequiredVersion 5.2.0 -Force -SkipPublisherCheck -Scope CurrentUser }
Start-Job -Name GetDbaTools -ScriptBlock { powershell -command Install-Module dbatools -Force -SkipPublisherCheck }
Start-Job -Name GetDbaChecks -ScriptBlock { powershell -command Install-Module dbachecks -Force -SkipPublisherCheck -Scope CurrentUser }

#Start SQL Server
Get-Service | Where-Object {$_.DisplayName -like 'SQL Server (*'} | Start-Service

#Wait for the jobs to finish
Get-Job | Wait-Job | Receive-Job | Format-Table
