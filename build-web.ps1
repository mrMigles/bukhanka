param([string]$Godot = "C:\Users\Sergey\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe")
$ErrorActionPreference = 'Stop'
$stagePath = Join-Path $PSScriptRoot 'builds\staging'
$webPath = Join-Path $PSScriptRoot 'builds\Web'
New-Item -ItemType Directory -Force $stagePath,$webPath | Out-Null
function Invoke-Godot([string[]]$GodotArgs, [string]$Stage) {
    if (-not ($IsWindows -or $PSVersionTable.PSEdition -eq 'Desktop')) {
        & $Godot @GodotArgs | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "$Stage failed (exit code $LASTEXITCODE)" }
        return
    }
    $stdout = Join-Path $stagePath 'godot-stdout.log'
    $stderr = Join-Path $stagePath 'godot-stderr.log'
    $process = Start-Process -FilePath $Godot -ArgumentList $GodotArgs -Wait -PassThru -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    Get-Content -LiteralPath $stdout | Out-Host
    Get-Content -LiteralPath $stderr | Out-Host
    if ($process.ExitCode -ne 0) { throw "$Stage failed (exit code $($process.ExitCode))" }
}
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
Invoke-Godot @('--headless', '--path', $stagePath, '--editor', '--import', '--quit') 'Import'
Invoke-Godot @('--headless', '--path', $stagePath, '--export-release', 'Web', (Join-Path $webPath 'index.html')) 'Web export'
& node (Join-Path $PSScriptRoot 'prepare-web.cjs') $webPath | Out-Host
if ($LASTEXITCODE -ne 0) { throw 'Web packaging failed' }
& node (Join-Path $PSScriptRoot 'compress-web.cjs') $webPath | Out-Host
if ($LASTEXITCODE -ne 0) { throw 'Web compression failed' }
Write-Host "Web game ready: $webPath"

