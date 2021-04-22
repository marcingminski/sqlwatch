# Create temp folder to store release files
# Copy dashboard files
# Copy dacpacs
# Copy executables

# Get root path of this script:
$PSScriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition

# Find MsBuild regardless of the Visual Studio version so we can run this on Appveyor:
$MsBuild = Get-ChildItem -path "C:\Program Files (x86)\Microsoft Visual Studio" -Filter MSBuild.exe -Recurse | Where-Object {$_.FullName -notlike "*amd64*"}

# Run Build and force Rebuild so we bump the build number for a clean state:
cd "$($MsBuild.PSParentPath)"
.\MSBuild.exe /t:Rebuild "$PSScriptRoot\SqlWatch.Monitor\Project.SqlWatch.Database\SQLWATCH.sqlproj"

# Run Build again without rebuild so we dont bump the build number but include in the dacpac.
# This is because the build number is pushed to the sql file whilst the project is being build, but that that time
# That file is already included in the build so its a chicken and egg situation. If we now build it again, becuase
# Nothing has changed since the last build, the build number will reman the same but it will now be included in the build itself.
cd "$($MsBuild.PSParentPath)"
.\MSBuild.exe "$PSScriptRoot\SqlWatch.Monitor\Project.SqlWatch.Database\SQLWATCH.sqlproj"


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
Copy-Item -Path "$PSScriptRoot\SqlWatch.Monitor\Project.SqlWatch.IntegrationServices\bin\Development\SQLWATCHSSIS.ispac" -Destination "$ReleaseFolder"

# Copy SQLWATCH Importer
New-Item -Path "$ReleaseFolder\SqlWatchImport" -ItemType Directory
Copy-Item -Path "$PSScriptRoot\SqlWatch.Monitor\Project.SqlWatchImport\bin\Debug\*" -Destination "$ReleaseFolder\SqlWatchImport" -Exclude *.log,*.pdb

# Create ZIP:
Compress-Archive -Path $ReleaseFolder -DestinationPath "$TmpFolder\$ReleaseFolderName.zip"