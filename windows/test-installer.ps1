param(
    [Parameter(Mandatory)] [string]$Setup,
    [Parameter(Mandatory)] [ValidateSet("x64", "arm64")] [string]$Architecture
)

$ErrorActionPreference = "Stop"
$root = Join-Path $env:LOCALAPPDATA "Programs\PocketLeft"
$app = Join-Path $root "app\Pocket.exe"
$uninstaller = Join-Path $root "Uninstall.exe"
$shortcut = Join-Path ([Environment]::GetFolderPath("Programs")) "Pocket.lnk"
$desktopShortcut = Join-Path ([Environment]::GetFolderPath("DesktopDirectory")) "Pocket.lnk"
$uninstallKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\PocketLeft"
$runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$preferencesKey = "HKCU:\Software\PocketLeft"
$profile = Join-Path $env:LOCALAPPDATA "PocketLeft\WebView2"
$marker = Join-Path $profile "installer-smoke-marker.txt"
$startupCommand = '"{0}" --background' -f $app

Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class PocketTestWindows {
    [DllImport("user32.dll", CharSet = CharSet.Unicode, ExactSpelling = true)]
    public static extern IntPtr FindWindowW(IntPtr className, string title);
    [DllImport("user32.dll", ExactSpelling = true)]
    public static extern bool IsWindowVisible(IntPtr window);
}
'@

if ((Test-Path $root) -or (Test-Path $profile) -or (Test-Path $uninstallKey) -or
    (Test-Path $shortcut) -or (Test-Path $desktopShortcut)) {
    throw "Run this test in a fresh Windows account."
}

function Run-Setup([string]$Path, [int]$ExpectedExitCode = 0, [string]$Arguments = "/S") {
    $process = Start-Process -FilePath $Path -ArgumentList $Arguments -Wait -PassThru
    if ($process.ExitCode -ne $ExpectedExitCode) {
        throw "$Path exited with $($process.ExitCode), expected $ExpectedExitCode."
    }
}

function Get-PeMachine([string]$Path) {
    $reader = [IO.BinaryReader]::new([IO.File]::OpenRead($Path))
    try {
        $reader.BaseStream.Position = 0x3c
        $reader.BaseStream.Position = $reader.ReadInt32() + 4
        return $reader.ReadUInt16()
    } finally {
        $reader.Dispose()
    }
}

function Wait-ForClockBalance([Diagnostics.Process]$Process, [string]$Amount) {
    $deadline = [DateTime]::UtcNow.AddSeconds(45)
    while ([DateTime]::UtcNow -lt $deadline) {
        if ($Process.HasExited) { throw "Pocket exited while opening its ledger in the background." }
        $window = [PocketTestWindows]::FindWindowW([IntPtr]::Zero, "Pocket balance $Amount")
        if ($window -ne [IntPtr]::Zero -and [PocketTestWindows]::IsWindowVisible($window)) { return }
        Start-Sleep -Milliseconds 300
    }
    throw "Pocket did not show the amount above the clock while its main window was closed."
}

Run-Setup $Setup
$machine = if ($Architecture -eq "x64") { 0x8664 } else { 0xaa64 }
if ((Get-PeMachine $app) -ne $machine -or (Get-PeMachine "$root\app\WebView2Loader.dll") -ne $machine) {
    throw "Setup did not install the native Windows build."
}
if (!(Test-Path "$root\app\Client\vendor\pglite\pglite.wasm") -or (Get-ItemPropertyValue $uninstallKey DisplayName) -ne "Pocket") {
    throw "Pocket did not register an installed app with a complete offline client."
}
$link = (New-Object -ComObject WScript.Shell).CreateShortcut($shortcut)
if ($link.TargetPath -ne $app) { throw "Missing or incorrect Start menu shortcut." }

$clientScript = "$root\app\Client\windows.js"
$originalClient = Get-Content $clientScript -Raw
Add-Content $clientScript -Value @'

document.addEventListener("DOMContentLoaded", async () => {
  if (localStorage.getItem("pocket.windows.ledgerMode")) return;
  const ledger = await import("./local-ledger.js");
  await ledger.initializeLedger(1024.50, todayISO());
  const original = await ledger.exportLedger();
  if (original.entries.length !== 1 || original.entries[0].cents !== 102450) throw new Error("Ledger export mismatch");
  await ledger.rpc("pocket_add", { p_amount: -25.75, p_label: "Backup test", p_on: todayISO(), p_category: "food" });
  const [day] = await ledger.backupDays();
  if (!day || (await ledger.readBackup(day)).entries[0].cents !== 102450) throw new Error("Daily backup mismatch");
  await ledger.replaceLedger(original);
  const restored = await ledger.exportLedger();
  if (restored.entries.length !== 1 || restored.entries[0].id !== original.entries[0].id) throw new Error("Ledger restore mismatch");
  localStorage.setItem("pocket.windows.localReady", "yes");
  localStorage.setItem("pocket.windows.ledgerMode", "local");
  location.reload();
});
'@
$instance = Start-Process -FilePath $app -ArgumentList "--background" -PassThru
try {
    Wait-ForClockBalance $instance '$1,024.50'
    Run-Setup $Setup 1
    # The NSIS uninstaller relaunches from a temporary copy, so check the installed files.
    Run-Setup $uninstaller
    if (!(Test-Path $app) -or !(Test-Path $uninstallKey)) {
        throw "Uninstall changed the installation while Pocket was running."
    }
} finally {
    Stop-Process -Id $instance.Id -ErrorAction SilentlyContinue
    $instance.WaitForExit()
    Set-Content $clientScript $originalClient -NoNewline
}

New-Item $preferencesKey -Force | Out-Null
Set-ItemProperty $preferencesKey BalanceDisplay "IconOnly"
$hover = Start-Process -FilePath $app -ArgumentList "--background" -PassThru
try {
    Start-Sleep -Seconds 5
    if ($hover.HasExited -or [PocketTestWindows]::IsWindowVisible([PocketTestWindows]::FindWindowW([IntPtr]::Zero, 'Pocket balance $1,024.50'))) {
        throw "Pocket did not migrate Icon only to a tray-only display."
    }
} finally {
    Stop-Process -Id $hover.Id -ErrorAction SilentlyContinue
    $hover.WaitForExit()
    Remove-ItemProperty $preferencesKey BalanceDisplay
}

New-Item $profile -ItemType Directory -Force | Out-Null
Set-Content $marker "keep this ledger profile"
if (!(Test-Path $runKey)) { New-Item $runKey | Out-Null }
Set-ItemProperty $runKey PocketLeft '"C:\portable\Pocket.exe" --background'
Move-Item "$root\app" "$root\app.previous"
Run-Setup $Setup
if (!(Test-Path $app) -or !(Test-Path $marker) -or (Get-ItemPropertyValue $runKey PocketLeft) -ne $startupCommand) {
    throw "Reinstall did not recover the app and preserve the profile and sign-in setting."
}

$scratch = Join-Path $env:TEMP ("pocket-setup-" + [Guid]::NewGuid())
New-Item $scratch -ItemType Directory | Out-Null
$drive = "P:"
if (Test-Path "$drive\") { throw "Drive $drive needs to be unused to test a second destination." }
& subst.exe $drive $scratch
if ($LASTEXITCODE) { throw "Could not map an alternate test drive." }
try {
    $busyFolder = "$drive\Existing folder"
    New-Item "$busyFolder\app" -ItemType Directory -Force | Out-Null
    Set-Content "$busyFolder\app\keep.txt" "unrelated files"
    Run-Setup $Setup 1 "/S /D=$busyFolder"
    $setupLog = Get-Content (Join-Path $env:TEMP "Pocket-Setup.log") -Raw
    if ($setupLog -notlike "*already contains files*" -or !(Test-Path "$busyFolder\app\keep.txt") -or !(Test-Path $app)) {
        throw "Setup did not explain the directory conflict or protect the existing files."
    }
    $customRoot = "$drive\Apps With Spaces\PocketLeft"
    $customApp = "$customRoot\app\Pocket.exe"
    $customUninstaller = "$customRoot\Uninstall.exe"
    Run-Setup $Setup 0 "/S /DESKTOP /STARTUP /D=$customRoot"
    if ((Get-PeMachine $customApp) -ne $machine -or (Test-Path $app) -or !(Test-Path $marker) -or
        (Get-ItemPropertyValue $uninstallKey InstallLocation) -ne $customRoot -or
        (Get-ItemPropertyValue $runKey PocketLeft) -ne ('"{0}" --background' -f $customApp)) {
        throw "Moving to the selected drive did not preserve the ledger or register the new app."
    }
    $shell = New-Object -ComObject WScript.Shell
    if ($shell.CreateShortcut($shortcut).TargetPath -ne $customApp -or
        $shell.CreateShortcut($desktopShortcut).TargetPath -ne $customApp) {
        throw "Setup did not create the selected shortcuts for the new drive."
    }
    Run-Setup $customUninstaller
    if ((Test-Path $customApp) -or (Test-Path $customUninstaller) -or (Test-Path $shortcut) -or
        (Test-Path $desktopShortcut) -or (Test-Path $uninstallKey) -or !(Test-Path $marker)) {
        throw "Uninstall left app files or removed the ledger profile."
    }
    if ((Get-Item $runKey).GetValueNames() -contains "PocketLeft") {
        throw "Uninstall left a sign-in command for the removed app."
    }
} finally {
    & subst.exe $drive /D
    Remove-Item $scratch -Recurse -Force
}
Write-Host "Verified $Architecture setup, diagnostics, alternate drive, shortcuts, recovery and uninstall."
