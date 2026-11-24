$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$godotExe = if ($env:GODOT_EXE) { $env:GODOT_EXE } else { "C:\Godot.exe\Godot_v4.7.2-stable_win64.exe" }
$outputHtml = Join-Path $projectRoot "index.html"

if (-not (Test-Path -LiteralPath $godotExe -PathType Leaf)) {
    throw "Godot executable not found at '$godotExe'. Set GODOT_EXE to your Godot 4.7 executable."
}

Push-Location $projectRoot
try {
    $godot = Start-Process -FilePath $godotExe -ArgumentList @(
        "--headless", "--path", $projectRoot, "--export-release", "Web", $outputHtml
    ) -Wait -PassThru -WindowStyle Hidden
    if ($godot.ExitCode -ne 0) { throw "Godot web export failed with exit code $($godot.ExitCode)." }
} finally {
    Pop-Location
}

$html = [IO.File]::ReadAllText($outputHtml)
$html = $html.Replace('<html lang="en">', '<html lang="zh-Hant-TW">')
$html = [regex]::Replace($html, '<meta name="viewport"[^>]*>', '<meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">')
$html = $html.Replace('<meta name="description" content="">', '<meta name="description" content="踏進月光球場，用排球闖關學會預算、儲蓄與分散風險。">')
$html = $html.Replace('<meta name="viewport"', '<meta name="theme-color" content="#101a2c">' + [Environment]::NewLine + '  <meta name="viewport"')
[IO.File]::WriteAllText($outputHtml, $html, [Text.UTF8Encoding]::new($false))
Write-Host "Web game exported to $outputHtml"
