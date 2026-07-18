[CmdletBinding()]
param(
    [string]$GodotPath = "",
    [switch]$Quick
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$global:LASTEXITCODE = 0

function Find-GodotExecutable {
    param([string]$ExplicitPath)

    if ($ExplicitPath) {
        if (-not (Test-Path -LiteralPath $ExplicitPath -PathType Leaf)) {
            throw "Godot executable not found: $ExplicitPath"
        }
        return (Resolve-Path -LiteralPath $ExplicitPath).Path
    }

    if ($env:GODOT_BIN -and (Test-Path -LiteralPath $env:GODOT_BIN -PathType Leaf)) {
        return (Resolve-Path -LiteralPath $env:GODOT_BIN).Path
    }

    foreach ($commandName in @("godot", "godot4")) {
        $command = Get-Command $commandName -ErrorAction SilentlyContinue
        if ($command -and $command.Source -notmatch '\\Microsoft\\WinGet\\Links\\') {
            return $command.Source
        }
    }

    $localAppData = [Environment]::GetFolderPath("LocalApplicationData")
    $wingetPackages = Join-Path $localAppData "Microsoft\WinGet\Packages"
    if (Test-Path -LiteralPath $wingetPackages -PathType Container) {
        $match = Get-ChildItem -LiteralPath $wingetPackages -Filter "Godot*_console.exe" -File -Recurse -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($match) {
            return $match.FullName
        }
    }

    foreach ($commandName in @("godot", "godot4")) {
        $command = Get-Command $commandName -ErrorAction SilentlyContinue
        if ($command) {
            return $command.Source
        }
    }

    throw "Godot was not found. Install Godot 4.7.x, add it to PATH, set GODOT_BIN, or pass -GodotPath."
}

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$projectFile = Join-Path $repoRoot "project.godot"
if (-not (Test-Path -LiteralPath $projectFile -PathType Leaf)) {
    throw "project.godot was not found at repository root: $repoRoot"
}

$godot = Find-GodotExecutable -ExplicitPath $GodotPath
$global:LASTEXITCODE = 0
$versionOutput = & $godot --version 2>&1
if ($LASTEXITCODE -ne 0 -or -not $versionOutput) {
    throw "Godot failed to report its version."
}
$version = ($versionOutput | Select-Object -First 1).ToString().Trim()
Write-Host "Repository: $repoRoot"
Write-Host "Godot:     $godot"
Write-Host "Version:   $version"

if ($version -notmatch '^4\.7(\.|$)') {
    Write-Warning "This project is pinned to Godot 4.7.x; detected $version."
}

if ($Quick) {
    $testFiles = @(
        "test_combat.gd",
        "test_skill_and_potion_rules.gd",
        "test_first_rift_run.gd",
        "test_talent_tree.gd"
    )
} else {
    $testFiles = Get-ChildItem -LiteralPath (Join-Path $repoRoot "tests") -Filter "test_*.gd" -File |
        Where-Object { $_.Name -ne "test_battle_presentation.gd" } |
        Sort-Object Name |
        ForEach-Object { $_.Name }
}

Push-Location $repoRoot
try {
    foreach ($testFile in $testFiles) {
        $fullTestPath = Join-Path $repoRoot (Join-Path "tests" $testFile)
        if (-not (Test-Path -LiteralPath $fullTestPath -PathType Leaf)) {
            throw "Test file not found: $fullTestPath"
        }

        Write-Host ""
        Write-Host "Running $testFile..." -ForegroundColor Cyan
        $global:LASTEXITCODE = 0
        & $godot --headless --path $repoRoot --script "res://tests/$testFile"
        if ($LASTEXITCODE -ne 0) {
            throw "Test failed with exit code ${LASTEXITCODE}: $testFile"
        }
    }
} finally {
    Pop-Location
}

Write-Host ""
Write-Host "Idle Rift headless verification passed ($($testFiles.Count) test scripts)." -ForegroundColor Green
Write-Host "Visual presentation is verified separately by running the main scene at 1280x720."
