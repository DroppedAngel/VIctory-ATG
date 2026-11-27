# Puts a "VIctory" shortcut on the desktop and in the Start menu that starts
# Play-VIctory.cmd from this checkout (README.md, "Getting started").
#   scripts\install-desktop.ps1 [-Build release] [-Arguments '-Windowed']
# -Build      the build the shortcut starts: diag (the default) or release
# -Arguments  more options for scripts\play.ps1, e.g. '-Windowed' or '-Console series-x'
# -Remove     takes the shortcuts away again
# Nothing is copied: the shortcut points at this checkout, so a new build or
# git pull is what the next start uses.
param(
    [ValidateSet('diag', 'release')][string]$Build = 'diag',
    [string]$Arguments = '',
    [switch]$Remove
)
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$places = @(
    [Environment]::GetFolderPath('Desktop'),
    (Join-Path ([Environment]::GetFolderPath('Programs')) 'VIctory')
)
foreach ($place in $places) {
    $link = Join-Path $place 'VIctory.lnk'
    if ($Remove) {
        if (Test-Path $link) { Remove-Item $link; Write-Host "Removed $link." }
        continue
    }
    New-Item -ItemType Directory -Force $place | Out-Null
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($link)
    $shortcut.TargetPath = Join-Path $root 'Play-VIctory.cmd'
    $shortcut.Arguments = ("-Build $Build $Arguments").Trim()
    $shortcut.WorkingDirectory = $root
    $shortcut.Description = 'Start the title with VIctory'
    $shortcut.Save()
    Write-Host "Made $link."
}
if (-not $Remove) {
    $built = @($env:CARGO_TARGET_DIR, (Join-Path $root 'target')) | Where-Object { $_ } |
        ForEach-Object { Join-Path (Join-Path $_ $Build) 'victory.exe' } | Where-Object { Test-Path $_ }
    if (-not $built) {
        Write-Host "No $Build build yet. Build it first (README.md), then start the shortcut."
    }
}
