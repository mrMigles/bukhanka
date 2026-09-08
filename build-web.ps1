param([string]$Godot = "C:\Users\Sergey\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe")
$ErrorActionPreference = 'Stop'
$stagePath = Join-Path $PSScriptRoot 'builds\staging'
$webPath = Join-Path $PSScriptRoot 'builds\Web'
New-Item -ItemType Directory -Force $stagePath,$webPath | Out-Null
foreach ($file in @('project.godot','main.tscn','icon.svg')) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination $stagePath -Force
}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'builds/tooling/web-export.cfg') -Destination (Join-Path $stagePath 'export_presets.cfg') -Force
$presetPath = Join-Path $stagePath 'export_presets.cfg'
$toolingPath = (Join-Path $PSScriptRoot 'builds/tooling').Replace('\', '/')
$preset = [IO.File]::ReadAllText($presetPath).Replace('../tooling/', "$toolingPath/")
[IO.File]::WriteAllText($presetPath, $preset)
foreach ($dir in @('scripts','shaders','assets')) {
    $sourcePath = Join-Path $PSScriptRoot $dir
    if (Test-Path -LiteralPath $sourcePath) {
        Copy-Item -LiteralPath $sourcePath -Destination $stagePath -Recurse -Force
    }
}
& $Godot --headless --path $stagePath --editor --import --quit | Out-Host
if ($LASTEXITCODE -ne 0) { throw 'Import failed' }
& $Godot --headless --path $stagePath --export-release Web (Join-Path $webPath 'index.html') | Out-Host
if ($LASTEXITCODE -ne 0) { throw 'Web export failed' }
Write-Host "Web game ready: $webPath"

