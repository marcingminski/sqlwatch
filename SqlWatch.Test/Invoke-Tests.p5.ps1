param(
        [string]$SqlInstance,
        [string]$SqlWatchDatabase
)

$PSScriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
cd $PSScriptRoot

$TestFiles = Get-ChildItem -Path $PSScriptRoot -Filter "Pester*.p5.ps1"

$container = New-PesterContainer -Path $TestFiles.FullName -Data @{ SqlInstance = $SqlInstance; SqlWatchDatabase = $SqlWatchDatabase }
Invoke-Pester -Container $container -Output Detailed -CI 