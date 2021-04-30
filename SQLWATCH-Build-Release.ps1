# Create temp folder to store release files #
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
Write-Output "Run Database Build and force Rebuild so we bump the build number for a clean state..."
MSBuild.exe -v:m -nologo /t:Rebuild "$PSScriptRoot\SqlWatch.Monitor\Project.SqlWatch.Database\SQLWATCH.sqlproj"
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

# Read SQLWATCH build version:

[string]$Version = Select-String -Path "$PSScriptRoot\SqlWatch.Monitor\Project.SqlWatch.Database\Scripts\Pre-Deployment\SetDacVersion.sql" -Pattern [0-9] | select-object -ExpandProperty Line
[string]$Version = $Version.Trim()

# Create TMP folder to store release files:
Write-Output "Create Release folder and copy all files for the release..."

$TmpFolder = "$PSScriptRoot\RELEASE\"
$ReleaseFolderName = "SQLWATCH $Version $(get-date -f yyyyMMddHHmmss)"
$ReleaseFolder = "$TmpFolder\$ReleaseFolderName"
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

Write-Output @"
Run Build again without rebuild so we dont bump the build number but include in the dacpac.
This is because the build number is pushed to the sql file whilst the project is being build, but that that time
That file is already included in the build so its a chicken and egg situation. If we now build it again, becuase
Nothing has changed since the last build, the build number will reman the same but it will now be included in the build itself.
"@
MSBuild.exe /m -v:m -nologo "$PSScriptRoot\SqlWatch.Monitor\SqlWatch.Monitor.sln" /p:Configuration=Release /p:Platform="Any CPU" /p:OutDir="$($ReleaseFolder)"
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

# Copy Dashboard files:
Copy-Item -Recurse -Path "$PSScriptRoot\SqlWatch.Dashboard\" -Destination "$ReleaseFolder" -Container -Exclude *.bak
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

# Create ZIP:
Compress-Archive -Path $ReleaseFolder -DestinationPath "$TmpFolder\$ReleaseFolderName.zip"
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}