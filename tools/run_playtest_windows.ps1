[CmdletBinding()]
param(
    [string]$GodotPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

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
        $match = Get-ChildItem -LiteralPath $wingetPackages -Filter "Godot*.exe" -File -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notmatch '_console\.exe$' } |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if (-not $match) {
            $match = Get-ChildItem -LiteralPath $wingetPackages -Filter "Godot*_console.exe" -File -Recurse -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First 1
        }
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

    throw "Godot 4.7.x was not found. Install it, add it to PATH, or set GODOT_BIN."
}

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$projectFile = Join-Path $repoRoot "project.godot"
if (-not (Test-Path -LiteralPath $projectFile -PathType Leaf)) {
    throw "project.godot was not found: $projectFile"
}

$godot = Find-GodotExecutable -ExplicitPath $GodotPath
Write-Host "Starting Idle Rift Playtest..." -ForegroundColor Cyan
Write-Host "Project: $repoRoot"
Write-Host "Godot:   $godot"

$process = Start-Process -FilePath $godot -ArgumentList @("--path", $repoRoot) -WorkingDirectory $repoRoot -PassThru -Wait
if ($process.ExitCode -ne 0) {
    throw "Godot exited with code $($process.ExitCode)."
}
