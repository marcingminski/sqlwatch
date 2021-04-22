# Create temp folder to store release files
# Copy dashboard files
# Copy dacpacs
# Copy executables

# Get root path of this script:
$PSScriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition

# Find MsBuild regardless of the Visual Studio version:
#$VS = Get-ChildItem -path "C:\Program Files (x86)" | Where-Object {$_ -like "Microsoft Visual Studio"} | Sort-Object Name -Descending | Select -First 1
#$MsBuild = Get-ChildItem -Path  "$($VS.FullName)" -Recurse  -Filter "MSBuild.exe" | Where-Object {$_.FullName -notlike "*amd64*"}

#if (!$MsBuild -or $MsBuild.FullName -eq "") {
#    #have we not got msbuild?
#}

#Appveyor has MsBuild in the path

# Run Build and force Rebuild so we bump the build number for a clean state:
#cd "$($MsBuild.PSParentPath)"
MSBuild.exe /t:Rebuild "$PSScriptRoot\SqlWatch.Monitor\Project.SqlWatch.Database\SQLWATCH.sqlproj"

# Run Build again without rebuild so we dont bump the build number but include in the dacpac.
# This is because the build number is pushed to the sql file whilst the project is being build, but that that time
# That file is already included in the build so its a chicken and egg situation. If we now build it again, becuase
# Nothing has changed since the last build, the build number will reman the same but it will now be included in the build itself.
#cd "$($MsBuild.PSParentPath)"

# This time we can build the entire solution including all applications:
# Restore external packages:
nuget restore "$PSScriptRoot\SqlWatch.Monitor\SqlWatch.Monitor.sln"

MSBuild.exe "$PSScriptRoot\SqlWatch.Monitor\SqlWatch.Monitor.sln"



#Build Importer
MSBuild.exe "$PSScriptRoot\SqlWatch.Monitor\Project.SqlWatchImport\SqlWatchImport.csproj"

# Read SQLWATCH build version:

[string]$Version = Select-String -Path "$PSScriptRoot\SqlWatch.Monitor\Project.SqlWatch.Database\Scripts\Pre-Deployment\SetDacVersion.sql" -Pattern [0-9] | select-object -ExpandProperty Line
[string]$Version = $Version.Trim()

# Create TMP folder to store release files:
$TmpFolder = "C:\TEMP\"
$ReleaseFolderName = "SQLWATCH $Version $(get-date -f yyyyMMddHHmmss)"
$ReleaseFolder = "$TmpFolder\$ReleaseFolderName"
New-Item -Path $ReleaseFolder -ItemType Directory

# Copy Dashboard files:
Copy-Item -Recurse -Path "$PSScriptRoot\SqlWatch.Dashboard\" -Destination "$ReleaseFolder" -Container -Exclude *.bak

# Copy Dacpacs:
Copy-Item -Path "$PSScriptRoot\SqlWatch.Monitor\Project.SqlWatch.Database\bin\Debug\*.dacpac" -Destination "$ReleaseFolder"

# Copy SSIS:
if (Test-Path -Path "$PSScriptRoot\SqlWatch.Monitor\Project.SqlWatch.IntegrationServices\bin\Development\SQLWATCHSSIS.ispac") {
    Copy-Item -Path "$PSScriptRoot\SqlWatch.Monitor\Project.SqlWatch.IntegrationServices\bin\Development\SQLWATCHSSIS.ispac" -Destination "$ReleaseFolder"
}

# Copy SQLWATCH Importer
New-Item -Path "$ReleaseFolder\SqlWatchImport" -ItemType Directory
Copy-Item -Path "$PSScriptRoot\SqlWatch.Monitor\Project.SqlWatchImport\bin\Debug\*" -Destination "$ReleaseFolder\SqlWatchImport" -Exclude *.log,*.pdb

# Create ZIP:
Compress-Archive -Path $ReleaseFolder -DestinationPath "$TmpFolder\$ReleaseFolderName.zip"