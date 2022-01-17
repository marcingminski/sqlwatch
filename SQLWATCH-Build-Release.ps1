# Create temp folder to store release files #
# Copy dashboard files
# Copy dacpacs
# Copy executables

# Get root path of this script:
$PSScriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition;
$ErrorActionPreference = "Stop";

# Create TMP folder to store release files:
Write-Output "Create Release folder and copy all files for the release..."

$TmpFolder = "$PSScriptRoot\RELEASE\"
$ReleaseFolderName = "SQLWATCH Latest"
$ReleaseFolder = "$TmpFolder\$ReleaseFolderName"

if (Test-Path -path $TmpFolder) {
    Remove-Item -Path $TmpFolder -Force -Confirm:$false -Recurse
 }
New-Item -Path $ReleaseFolder -ItemType Directory

# Run Build again without rebuild so we dont bump the build number but include in the dacpac.
# This is because the build number is pushed to the sql file whilst the project is being build, but that that time
# That file is already included in the build so its a chicken and egg situation. If we now build it again, becuase
# Nothing has changed since the last build, the build number will reman the same but it will now be included in the build itself.
# This time we can build the entire solution including all applications:
# Restore external packages:

Write-Output "We are about to build the entire solution including C# apps. Before we do that, we have to restore NuGet packages..."
nuget restore "$PSScriptRoot\SqlWatch.Monitor\SqlWatch.Monitor.sln"
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

# We can only build .NET in VS2019 due to C# version. Previous VS versions will fail. 
# but we can only have SQL 2019 in VS 2019. Previous versions of SQl are available in previous VS builds
# (we are talking appveyor image builds here)
if ($env:APPVEYOR_BUILD_WORKER_IMAGE -eq "Visual Studio 2019") {
    MSBuild.exe /m -v:m -nologo "$PSScriptRoot\SqlWatch.Monitor\SqlWatch.Monitor.sln" /p:Configuration=Release /p:Platform="Any CPU" /p:OutDir="$($ReleaseFolder)"
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}
# for SQL Server versions 2012, 2014, 2016 and 2017 we have to run VS 2015
# and we should only build DB project now:
else {
    MSBuild.exe /m -v:m -nologo "$PSScriptRoot\SqlWatch.Monitor\Project.SqlWatch.Database\SQLWATCH.sqlproj" /p:Configuration=Release /p:Platform=AnyCPU /p:OutDir="$($ReleaseFolder)\SqlWatch.Database"
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }     
}

# Copy Dashboard files:
Copy-Item -Recurse -Path "$PSScriptRoot\SqlWatch.Dashboard\" -Destination "$ReleaseFolder" -Container -Exclude *.bak
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}


#Get SQLWATCH Version number from the dacpac:
Copy-Item -Path $ReleaseFolder\SQLWATCH.dacpac -Destination $ReleaseFolder\SQLWATCH.dacpac.zip
Expand-Archive -LiteralPath $ReleaseFolder\SQLWATCH.dacpac.zip -DestinationPath $ReleaseFolder\SQLWATCH-DACPAC

[xml]$xml = Get-Content -path $ReleaseFolder\SQLWATCH-DACPAC\DacMetadata.xml

$Version = ($xml.DacType.Version).trim()

#Rename folder to now include version number from dacpac:
$ReleaseFolderName = "SQLWATCH $Version $(get-date -f yyyyMMddHHmmss)"

Remove-item $ReleaseFolder\SQLWATCH-DACPAC -Recurse -Force
Remove-Item $ReleaseFolder\SQLWATCH.dacpac.zip -Force

Rename-Item -Path "$TmpFolder\SQLWATCH Latest" -NewName $TmpFolder\$ReleaseFolderName

# Create ZIP:
Compress-Archive -Path $TmpFolder\$ReleaseFolderName -DestinationPath "$TmpFolder\$ReleaseFolderName.zip"
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}