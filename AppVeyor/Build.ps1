$ErrorActionPreference = "Stop";
$ProjectFolder = "c:\projects\sqlwatch"

# Prepare the environment
# Set all installed instances of SQL server to dynamic ports
Write-Output ""
Get-ChildItem -Path 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\' |
    Where-Object {
        $_.Name -imatch 'MSSQL[_\d]+\.SQL.*'
    } |
    ForEach-Object {

        Write-Host "Setting $((Get-ItemProperty $_.PSPath).'(default)') to dynamic ports..."
        Set-ItemProperty (Join-Path $_.PSPath 'mssqlserver\supersocketnetlib\tcp\ipall') -Name TcpDynamicPorts -Value '0'
        Set-ItemProperty (Join-Path $_.PSPath 'mssqlserver\supersocketnetlib\tcp\ipall') -Name TcpPort -Value ([string]::Empty)
    }

# Install Modules
Write-Output "`nStarting Background Jobs in parallel:"
Start-Job -Name GetPester -ScriptBlock { Install-Module Pester -RequiredVersion 5.2.0 -Force -SkipPublisherCheck -Scope CurrentUser }
Start-Job -Name GetDbaTools -ScriptBlock { Install-Module dbatools -Force -SkipPublisherCheck }
Start-Job -Name GetDbaChecks -ScriptBlock { Install-Module dbachecks -Force -SkipPublisherCheck -Scope CurrentUser }
Start-Job -Name GetTestSpace -ScriptBlock { 
    cd c:\projects\sqlwatch\SqlWatch.Test
    Start-FileDownload https://testspace-client.s3.amazonaws.com/testspace-windows.zip 
    Write-Output "Extracting archive..."
    7z x -y testspace-windows.zip -bso0 -bsp0 
    }
Start-Job -Name StartSqlServer -ScriptBlock { Get-Service | Where-Object {$_.DisplayName -like 'SQL Server (*'} | Start-Service }

# Create Release folder to store release files:
$TmpFolder = "$ProjectFolder\RELEASE\"
$ReleaseFolderName = "SQLWATCH Latest"
$ReleaseFolder = "$TmpFolder\$ReleaseFolderName"

Write-Output "`nCreating Release folders..."
if (Test-Path -path $TmpFolder) 
{
    Remove-Item -Path $TmpFolder -Force -Confirm:$false -Recurse | Out-Null
}
New-Item -Path $ReleaseFolder -ItemType Directory | Out-Null

Write-Output "Building Database Project..."
MSBuild.exe /m -v:m -nologo "$ProjectFolder\SqlWatch.Monitor\Project.SqlWatch.Database\SQLWATCH.sqlproj" /clp:ErrorsOnly /p:Configuration=Release /p:Platform="Any CPU" /p:OutDir="$($ReleaseFolder)"
if ($LASTEXITCODE -ne 0) 
{
    exit $LASTEXITCODE
}

# Build applications only in VS2019 image:
if ($env:APPVEYOR_BUILD_WORKER_IMAGE -eq "Visual Studio 2019") 
{

    Write-Output "Restoring NuGet packages..." 
    nuget restore "$ProjectFolder\SqlWatch.Monitor\SqlWatch.Monitor.sln"  -Verbosity quiet
    if ($LASTEXITCODE -ne 0) 
    {
        exit $LASTEXITCODE
    }
    Write-Output "Building applications..."
    MSBuild.exe /m -v:m -nologo "$ProjectFolder\SqlWatch.Monitor\Project.SqlWatchImport\SqlWatchImport.csproj" /clp:ErrorsOnly /p:Configuration=Release /p:Platform="AnyCPU" /p:OutDir="$("$ReleaseFolder\SqlWatch.Import")"
    if ($LASTEXITCODE -ne 0) 
    {
        exit $LASTEXITCODE
    }
}

# Get Dacpac
$DacpacFile = Get-ChildItem -Path $ReleaseFolder -Recurse -Filter SQLWATCH.dacpac | Sort-Object LastWriteTime -Descending | Select-Object -First 1

# Wait for SQL Server Startup job to finish before we continue with the deployment:
Write-Output "`nWaiting for StartSqlServer background job to finish..."
Get-Job -Name StartSqlServer | Wait-Job | Format-Table

# Get SQL instances
[string[]]$SqlInstances = (Get-ItemProperty 'HKLM:\Software\Microsoft\Microsoft SQL Server\').InstalledInstances; 
$SqlInstances = $SqlInstances | % {'localhost\'+$_}; 

Foreach ($SqlInstance in $SqlInstances)
{
    $JobName = "Deploying " + $SqlInstance
    Start-Job -Name $JobName -ScriptBlock { 
        #param([string]$arguments)
        param (
            [string]$SqlInstance,
            [string]$Database,
            [string]$Dacpac
        )
        sqlpackage.exe /a:Publish /sf:"$($Dacpac)" /tdn:$($Database) /tsn:$($SqlInstance)
        exit $LASTEXITCODE
    } -ArgumentList $SqlInstance, SQLWATCH, $($DacpacFile.FullName) | Select Id, Name, State
}

# Wait for jobs to finish:
Write-Output "`nWaiting for Database Deployment background jobs to finish..."
Get-Job | Where-Object {$_.Name.Contains("Deploying")} | Wait-Job | Receive-Job
