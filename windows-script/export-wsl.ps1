# ============================================================
#  export-wsl.ps1 - WSL export and optional import
# ============================================================
#  Usage:
#    .\export-wsl.ps1 [-source <distro>] [-copyTarDest <path>] [-dest <path>]
#
#  Parameters (defaults set for current scenario):
#    -source       WSL distro to export.    Default: Ubuntu-22.04
#    -copyTarDest  Folder for the .tar file. Default: D:\wsl
#    -dest         Import folder for clone.  Default: D:\wsl\Ubuntu-D
#                  To export-only (no clone): pass -dest ''
#
#  Run:
#    powershell -ExecutionPolicy Bypass -File .\export-wsl.ps1
# ============================================================

param(
    [string]$source      = 'Ubuntu-D',
    [string]$exportName  = 'Ubuntu-22.04',
    [string]$copyTarDest = 'D:\wsl\Share',
    [string]$dest         = ''
)

$ErrorActionPreference = 'Stop'
$tarFile = Join-Path $copyTarDest "$($exportName)-export.tar"

Write-Host "=== WSL snapshot: $(Get-Date) ===" -ForegroundColor Cyan
Write-Host "  Source distro : $source"
Write-Host "  Tar location  : $tarFile"
if ($dest) {
    Write-Host "  Import to     : $dest"
} else {
    Write-Host "  Import to     : (skipped, export only)"
}
Write-Host ""

# 1. Stop WSL
# ----------------------------------------------------------
Write-Host "[1/4] wsl --shutdown ..." -ForegroundColor Yellow
wsl --shutdown
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ERROR: wsl --shutdown failed (exit $LASTEXITCODE)" -ForegroundColor Red
    exit 1
}
Write-Host "  OK" -ForegroundColor Green

# 2. Remove old tar if present
# ----------------------------------------------------------
if (Test-Path $tarFile) {
    $oldGB = [math]::Round((Get-Item $tarFile).Length / 1GB, 1)
    Write-Host "`n[2/4] Removing old tar ($oldGB GB) ..." -ForegroundColor Yellow
    Remove-Item $tarFile -Force
} else {
    Write-Host "`n[2/4] No old tar to remove." -ForegroundColor Yellow
}

# 3. Export with live progress
# ----------------------------------------------------------
Write-Host "`n[3/4] Exporting (takes ~50-60 min for large distros) ..." -ForegroundColor Yellow

$job = Start-Job -ScriptBlock {
    param($src, $dst)
    wsl --export $src $dst 2>&1
} -ArgumentList $source, $tarFile

while ($job.State -eq 'Running') {
    Start-Sleep -Seconds 10
    if (Test-Path $tarFile) {
        $size = (Get-Item $tarFile).Length
        $gb   = [math]::Round($size / 1GB, 1)
        Write-Progress -Activity "Exporting $source" -Status "$gb GB written" -PercentComplete 0
    }
}

$results = Receive-Job $job
Remove-Job $job -Force
$results | ForEach-Object {
    if ($_ -match 'cannot archive sockets') {
        Write-Host "  (skipped: $_)" -ForegroundColor DarkGray
    } elseif ($_ -match 'error|Error|failed|Failed') {
        Write-Host "  $_" -ForegroundColor Red
    } else {
        Write-Host "  $_"
    }
}

# 4. Verify tar
# ----------------------------------------------------------
Write-Host "`n[4/4] Verifying ..." -ForegroundColor Yellow
if (-not (Test-Path $tarFile)) {
    Write-Host "  FAIL: tar file was not created." -ForegroundColor Red
    exit 1
}
$finalSize = (Get-Item $tarFile).Length
$finalGB   = [math]::Round($finalSize / 1GB, 1)
Write-Host "  File : $tarFile"
Write-Host "  Size : $finalGB GB" -ForegroundColor Green

if ($finalGB -lt 100) {
    Write-Host "  WARNING: size looks low. Export may be incomplete." -ForegroundColor Red
    exit 1
}

# 5. (Optional) Import as new distro
# ----------------------------------------------------------
if ($dest) {
    $newDistroName = Split-Path $dest -Leaf
    Write-Host "`n=== Importing as '$newDistroName' to '$dest' ===" -ForegroundColor Cyan

    $existing = (wsl -l -v 2>&1) | Select-String -Pattern $newDistroName
    if ($existing) {
        Write-Host "  '$newDistroName' already exists - unregistering first ..." -ForegroundColor Yellow
        wsl --unregister $newDistroName
    }

    if (-not (Test-Path $dest)) {
        New-Item -ItemType Directory -Force -Path $dest | Out-Null
    }

    Write-Host "  Importing (can take 20-40 min) ..." -ForegroundColor Yellow
    wsl --import $newDistroName $dest $tarFile --version 2
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ERROR: wsl --import failed (exit $LASTEXITCODE)" -ForegroundColor Red
        exit 1
    }
    Write-Host "  Import OK" -ForegroundColor Green
}

# 6. Done
# ----------------------------------------------------------
Write-Host ""
Write-Host "=== COMPLETE: $(Get-Date) ===" -ForegroundColor Green
Write-Host "  Tar file:  $tarFile  ($finalGB GB)"
if ($dest) {
    Write-Host "  New distro: $dest (name: '$newDistroName')"
    Write-Host ""
    Write-Host "  Next steps:"
    Write-Host "    wsl -d $newDistroName              # open the new clone"
    Write-Host "    wsl --set-default $newDistroName   # make it default (optional)"
    Write-Host "    wsl -l -v                          # list all distros"
} else {
    Write-Host ""
    Write-Host "  Portable snapshot ready. To restore elsewhere:"
    Write-Host "    wsl --import <name> <folder> $tarFile --version 2"
}
Write-Host ""

<#

● 1. Already built-in (the running script window)

  The script prints a progress bar automatically every 10 seconds — you don't need to do anything. It shows:
  Exporting Ubuntu-22.04 |████████░░░░| 57.3 GB written ...

  2. From a second PowerShell window (quick one-shot)

  Open a new PowerShell window and run:
  Get-Item D:\wsl\Ubuntu-22.04-export.tar | Select-Object @{n='GB_written';e={[math]::Round($_.Length/1GB,1)}}
  Run it again in a minute — the number ticking up = healthy.

  3. Live auto-refresh (second window, best for leaving open)

  while($true){
      Clear-Host
      $f = 'D:\wsl\Ubuntu-22.04-export.tar'
      if (Test-Path $f) {
          $gb = [math]::Round((Get-Item $f).Length/1GB, 1)
          $pct = [math]::Round($gb/260*100, 0)
          $mins = [math]::Round((260-$gb)/4, 0)
          Write-Host "Progress: $gb GB / ~260 GB  ($pct%)" -ForegroundColor Cyan
          Write-Host "ETA: ~$mins min remaining"
          Write-Host "D: free: $([math]::Round((Get-PSDrive D).Free/1GB,1)) GB"
      } else {
          Write-Host "Tar file not created yet (export still starting...)"
      }
      Start-Sleep 5
  }
  Stop it with Ctrl+C when done. This gives you:
  - GB written out of ~260
  - Percentage
  - ETA in minutes (based on ~4 GB/min observed rate)
  - D: free space

  4. Check the WSL state (confirm it's still in export)

  wsl -l -v

  ┌─────────┬───────────────────────────────────────┐
  │  State  │                Meaning                │
  ├─────────┼───────────────────────────────────────┤
  │ Stopped │ ✅ Normal — WSL is down during export │
  ├─────────┼───────────────────────────────────────┤
  │ Running │ Export finished (or the script ended) │
  └─────────┴───────────────────────────────────────┘

  5. When it's DONE (all green)

  The script window will print === COMPLETE ===. Then verify:
  # Tar size (should be ~255–265 GB)
  Get-Item D:\wsl\Ubuntu-22.04-export.tar | Select-Object @{n='GB';e={[math]::Round($_.Length/1GB,1)}}

  # New distro should be listed
  wsl -l -v

  You should see:
    NAME            STATE           VERSION
  * Ubuntu-22.04    Stopped         2
    Ubuntu-D        Stopped         2

#>
