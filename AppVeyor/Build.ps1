$ErrorActionPreference = "Stop";
$ProjectFolder = "c:\projects\sqlwatch"

#Create Release folder to store release files:
$TmpFolder = "$ProjectFolder\RELEASE\"
$ReleaseFolderName = "SQLWATCH Latest"
$ReleaseFolder = "$TmpFolder\$ReleaseFolderName"

Write-Output "Creating Release folders..."
if (Test-Path -path $TmpFolder) 
{
    Remove-Item -Path $TmpFolder -Force -Confirm:$false -Recurse | Out-Null
}
New-Item -Path $ReleaseFolder -ItemType Directory | Out-Null

Write-Output "Restoring NuGet packages..." 
nuget restore "$ProjectFolder\SqlWatch.Monitor\SqlWatch.Monitor.sln"  -Verbosity quiet
if ($LASTEXITCODE -ne 0) 
{
    exit $LASTEXITCODE
}

Write-Output "Building Database Project..."
MSBuild.exe /m -v:m -nologo "$ProjectFolder\SqlWatch.Monitor\Project.SqlWatch.Database\SQLWATCH.sqlproj" /clp:ErrorsOnly /p:Configuration=Release /p:Platform="Any CPU" /p:OutDir="$($ReleaseFolder)"
if ($LASTEXITCODE -ne 0) 
{
    exit $LASTEXITCODE
}
