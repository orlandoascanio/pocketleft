param(
    [Parameter(Mandatory)] [string]$Setup,
    [Parameter(Mandatory)] [ValidateSet("x64", "arm64")] [string]$Architecture
)

$ErrorActionPreference = "Stop"
$root = Join-Path $env:LOCALAPPDATA "Programs\PocketLeft"
$app = Join-Path $root "app\Pocket.exe"
$uninstaller = Join-Path $root "Uninstall.exe"
$shortcut = Join-Path ([Environment]::GetFolderPath("Programs")) "Pocket.lnk"
$uninstallKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\PocketLeft"
$runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$profile = Join-Path $env:LOCALAPPDATA "PocketLeft\WebView2"
$marker = Join-Path $profile "installer-smoke-marker.txt"
$startupCommand = '"{0}" --background' -f $app

if ((Test-Path $root) -or (Test-Path $profile) -or (Test-Path $uninstallKey) -or (Test-Path $shortcut)) {
    throw "Run this test in a fresh Windows account."
}

function Run-Setup([string]$Path, [int]$ExpectedExitCode = 0) {
    $process = Start-Process -FilePath $Path -ArgumentList "/S" -Wait -PassThru
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

$instance = Start-Process -FilePath $app -ArgumentList "--background" -PassThru
try {
    if ($instance.WaitForExit(2500)) { throw "The installed app did not stay running." }
    Run-Setup $Setup 1
    # The NSIS uninstaller relaunches from a temporary copy, so check the installed files.
    Run-Setup $uninstaller
    if (!(Test-Path $app) -or !(Test-Path $uninstallKey)) {
        throw "Uninstall changed the installation while Pocket was running."
    }
} finally {
    Stop-Process -Id $instance.Id -ErrorAction SilentlyContinue
    $instance.WaitForExit()
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

Run-Setup $uninstaller
if ((Test-Path $app) -or (Test-Path $uninstaller) -or (Test-Path $shortcut) -or (Test-Path $uninstallKey) -or !(Test-Path $marker)) {
    throw "Uninstall left app files or removed the ledger profile."
}
if ((Get-Item $runKey).GetValueNames() -contains "PocketLeft") {
    throw "Uninstall left a sign-in command for the removed app."
}
Write-Host "Verified $Architecture setup, native payload, running app lock, reinstall and uninstall."
