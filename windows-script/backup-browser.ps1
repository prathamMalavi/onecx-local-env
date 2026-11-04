# ============================================================
#  backup-browsers.ps1 - Back up & restore Chrome + Edge
# ============================================================
#  Backs up the whole profile data (bookmarks, open tabs/sessions,
#  history, extensions, passwords, cookies, autofill, settings).
#  Edge: every profile EXCEPT the one matching -EdgeExclude (default
#  'work') is backed up.

#  EXPORT (on the current machine, before restoring the system):
#    powershell -ExecutionPolicy Bypass -File .\backup-browsers.ps1 -Mode export
#
#  IMPORT (on the new / restored system, after installing the browsers):
#    powershell -ExecutionPolicy Bypass -File .\backup-browsers.ps1 -Mode import
#
#  Parameters:
#    -Mode         export | import          (default: export)
#    -ShareDir     Where the .tar.gz archives go / come from.
#                  Default: D:\wsl\BrowserBackup
#    -EdgeExclude  Case-insensitive substring; any Edge profile whose
#                  name contains this is skipped.   Default: 'work'
#    -Force        On import, skip the confirmation prompt.
#
#  NOTES (important - read before relying on this):
#   * BOOKMARKS / TABS / EXTENSIONS / HISTORY / SETTINGS / COOKIES /
#     AUTOFILL restore cleanly on any machine.
#   * SAVED PASSWORDS are encrypted with a per-machine Windows (DPAPI)
#     key. They decrypt on restore ONLY if the Windows user account +
#     profile are the same (a system restore / same-account reimage).
#     On a brand-new account, everything else restores but the password
#     fields will be empty. Fallback: before wiping, export passwords
#     via the browser UI (Chrome/Edge -> Settings -> Password Manager ->
#     Export passwords) to a CSV, then re-import on the new system.
#   * Open tabs come from the 'Current Session' / 'Last Session' files.
#     For a clean capture, keep the browser closed a moment before export
#     (the script also closes the browsers automatically).
# ============================================================

param(
    [ValidateSet('export','import')]
    [string]$Mode        = 'export',
    [string]$ShareDir    = 'D:\wsl\BrowserBackup',
    [string]$EdgeExclude = 'work',
    [string]$EdgeExcludeFolder = '',   # exclude by folder name (e.g. 'Default') when profiles are unnamed
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$chromeApp = Join-Path $env:LOCALAPPDATA 'Google\Chrome'
$edgeApp   = Join-Path $env:LOCALAPPDATA 'Microsoft\Edge'
$chromeUD  = Join-Path $chromeApp 'User Data'
$edgeUD    = Join-Path $edgeApp   'User Data'

# Regenerable cache / shader dirs to leave out of the archive (saves space).
$excludeDirs = @(
    'Cache','Code Cache','GPUCache','DawnGraphiteCache','DawnWebGPUCache',
    'GrShaderCache','OptimizedShaderCache','ShaderCache','CacheStorage','ScriptCache'
)
$excludeFiles = @('component_crx_cache')

# ---- helpers -------------------------------------------------------------

function Close-Browsers {
    foreach ($p in @('chrome','msedge')) {
        Get-Process -Name $p -ErrorAction SilentlyContinue |
            Stop-Process -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Seconds 2
}

function Get-EdgeProfiles {
    param($edgeUD)
    $out = @()
    Get-ChildItem -Path $edgeUD -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $pref = Join-Path $_.FullName 'Preferences'
        if (Test-Path $pref) {
            $name = $null
            try { $name = (Get-Content $pref -Raw | ConvertFrom-Json).profile.name } catch {}
            $out += [PSCustomObject]@{ Folder = $_.Name; Path = $_.FullName; Name = $name }
        }
    }
    $out
}

function Backup-Browser {
    param(
        [string]$AppName,
        [string]$SourceUD,
        [string]$ArchivePath,
        [string[]]$ExcludeProfiles = @()
    )
    Write-Host "`n=== $AppName ===" -ForegroundColor Cyan
    $stamp    = Get-Date -Format 'yyyyMMddHHmmss'
    $staging  = Join-Path $env:TEMP "bb-$AppName-$stamp"
    $stagedUD = Join-Path $staging 'User Data'

    Write-Host "  Copying (caches excluded) ..." -ForegroundColor Yellow
    $rArgs = @($SourceUD, $stagedUD, '/E', '/R:1', '/W:1', '/NFL', '/NDL', '/NJH', '/NJS', '/NP', '/XD')
    $rArgs += $excludeDirs
    $rArgs += $ExcludeProfiles
    $rArgs += '/XF'
    $rArgs += $excludeFiles
    & robocopy @rArgs | Out-Null
    if ($LASTEXITCODE -ge 16) {
        Write-Host "  ERROR: robocopy failed (exit $LASTEXITCODE)" -ForegroundColor Red
        Remove-Item $staging -Recurse -Force -ErrorAction SilentlyContinue
        exit 1
    }

    Write-Host "  Compressing to $ArchivePath ..." -ForegroundColor Yellow
    & $tarExe -czf $ArchivePath -C $staging 'User Data'
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ERROR: tar failed (exit $LASTEXITCODE)" -ForegroundColor Red
        Remove-Item $staging -Recurse -Force -ErrorAction SilentlyContinue
        exit 1
    }

    Remove-Item $staging -Recurse -Force
    $size = [math]::Round((Get-Item $ArchivePath).Length / 1MB, 0)
    Write-Host "  OK  ($size MB)" -ForegroundColor Green
}

function Restore-Browser {
    param(
        [string]$AppName,
        [string]$AppDir,
        [string]$ArchivePath
    )
    Write-Host "`n=== $AppName ===" -ForegroundColor Cyan
    if (-not (Test-Path $ArchivePath)) {
        Write-Host "  ERROR: archive not found: $ArchivePath" -ForegroundColor Red
        exit 1
    }
    if (-not (Test-Path $AppDir)) {
        Write-Host "  Creating $AppDir ..." -ForegroundColor Yellow
        New-Item -ItemType Directory -Force -Path $AppDir | Out-Null
    }
    $ud = Join-Path $AppDir 'User Data'
    if (Test-Path $ud) {
        Write-Host "  Removing existing $ud ..." -ForegroundColor Yellow
        Remove-Item $ud -Recurse -Force
    }
    Write-Host "  Extracting $AppName profile data ..." -ForegroundColor Yellow
    & $tarExe -xzf $ArchivePath -C $AppDir
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ERROR: tar extract failed (exit $LASTEXITCODE)" -ForegroundColor Red
        exit 1
    }
    Write-Host "  Restored. Launch $AppName to verify." -ForegroundColor Green
}

# ---- preflight -----------------------------------------------------------
# Pin the NATIVE Windows tar (bsdtar). A MinGW/GNU tar on PATH can't handle
# Windows backslash output paths (it reads them as remote host specs).
$tarExe = (Resolve-Path (Join-Path $env:SystemRoot 'System32\tar.exe')).Path
if (-not (Test-Path $tarExe)) {
    Write-Host "ERROR: $tarExe not found. It ships with Windows 10 1803+ / 11." -ForegroundColor Red
    exit 1
}
Write-Host "=== Browser backup | mode: $Mode | $(Get-Date) ===" -ForegroundColor Cyan
Write-Host "  Share dir : $ShareDir"
if ($Mode -eq 'import' -and -not $Force) {
    $ans = Read-Host "This REPLACES current Chrome + Edge data with the backup. Type 'YES' to continue"
    if ($ans -ne 'YES') { Write-Host "Aborted."; exit 0 }
}

# ---- EXPORT --------------------------------------------------------------
if ($Mode -eq 'export') {
    Write-Host "Closing browsers for a clean capture ..." -ForegroundColor Yellow
    Close-Browsers
    if (-not (Test-Path $ShareDir)) {
        New-Item -ItemType Directory -Force -Path $ShareDir | Out-Null
    }

    if (Test-Path $chromeUD) {
        Backup-Browser -AppName 'Chrome' -SourceUD $chromeUD `
            -ArchivePath (Join-Path $ShareDir 'chrome-userdata.tar.gz')
    } else {
        Write-Host "`nChrome User Data not found at $chromeUD - skipped." -ForegroundColor Yellow
    }

    if (Test-Path $edgeUD) {
        $profiles = Get-EdgeProfiles -edgeUD $edgeUD
        $excl = @()
        Write-Host "`n=== Edge (profiles) ===" -ForegroundColor Cyan
        foreach ($p in $profiles) {
            $byName    = ($p.Name -and ($p.Name -like "*$EdgeExclude*"))
            $byFolder  = ($EdgeExcludeFolder -ne '' -and ($p.Folder -like $EdgeExcludeFolder))
            if ($byName -or $byFolder) {
                $excl += $p.Path
                $why = if ($byFolder) { 'folder match' } else { 'name match' }
                Write-Host ("  [skip]   {0,-15} '{1}'  ({2})" -f $p.Folder, $p.Name, $why) -ForegroundColor DarkGray
            } else {
                $label = if ($p.Name) { $p.Name } else { '(default)' }
                Write-Host ("  [backup] {0,-15} '{1}'" -f $p.Folder, $label) -ForegroundColor White
            }
        }
        Backup-Browser -AppName 'Edge' -SourceUD $edgeUD `
            -ArchivePath (Join-Path $ShareDir 'edge-userdata.tar.gz') -ExcludeProfiles $excl
    } else {
        Write-Host "`nEdge User Data not found at $edgeUD - skipped." -ForegroundColor Yellow
    }

    Write-Host "`n=== EXPORT COMPLETE ===" -ForegroundColor Green
    Get-ChildItem $ShareDir -Filter '*.tar.gz' |
        ForEach-Object { Write-Host ("  {0,-28} {1,8} MB" -f $_.Name, [math]::Round($_.Length/1MB,0)) }
    Write-Host "Copy these to the new system, then run with -Mode import." -ForegroundColor Cyan
    exit 0
}

# ---- IMPORT --------------------------------------------------------------
if ($Mode -eq 'import') {
    Write-Host "Closing browsers ..." -ForegroundColor Yellow
    Close-Browsers

    Restore-Browser -AppName 'Chrome' -AppDir $chromeApp `
        -ArchivePath (Join-Path $ShareDir 'chrome-userdata.tar.gz')
    Restore-Browser -AppName 'Edge' -AppDir $edgeApp `
        -ArchivePath (Join-Path $ShareDir 'edge-userdata.tar.gz')

    Write-Host "`n=== IMPORT COMPLETE ===" -ForegroundColor Green
    Write-Host "Launch Chrome and Edge - bookmarks, tabs and extensions should be back." -ForegroundColor Cyan
    Write-Host "If saved passwords are empty (new Windows account), use the CSV export fallback." -ForegroundColor Yellow
}
