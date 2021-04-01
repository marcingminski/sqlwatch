# Create temp folder to store release files
# Copy dashboard files
# Copy dacpacs
# Copy executables

# Get root path of this script:
$PSScriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition

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