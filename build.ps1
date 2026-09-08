param([string]$Godot = "C:\Users\Sergey\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe")
$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
$stagePath = Join-Path $projectRoot 'builds\staging'
$outputPath = Join-Path $projectRoot 'builds\Windows'
New-Item -ItemType Directory -Force $stagePath,$outputPath | Out-Null
foreach ($file in @('project.godot','main.tscn','icon.svg')) {
    Copy-Item -LiteralPath (Join-Path $projectRoot $file) -Destination $stagePath -Force
}
foreach ($dir in @('scripts','shaders')) {
    Copy-Item -LiteralPath (Join-Path $projectRoot $dir) -Destination $stagePath -Recurse -Force
}
Copy-Item -LiteralPath (Join-Path $projectRoot 'export_presets.cfg') -Destination $stagePath -Force
& $Godot --headless --path $stagePath --editor --import --quit | Out-Host
if ($LASTEXITCODE -ne 0) { throw 'Import failed' }
& $Godot --headless --path $stagePath --export-pack Windows (Join-Path $outputPath 'Bukhanka.pck') | Out-Host
if ($LASTEXITCODE -ne 0) { throw 'Pack export failed' }
if (-not (Test-Path -LiteralPath (Join-Path $outputPath 'Bukhanka.exe'))) {
    Copy-Item -LiteralPath $Godot -Destination (Join-Path $outputPath 'Bukhanka.exe')
}
Copy-Item -LiteralPath (Join-Path $projectRoot 'README.md') -Destination $outputPath -Force
Write-Host "Game ready: $outputPath\Bukhanka.exe"

