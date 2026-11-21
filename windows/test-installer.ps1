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
$profile = Join-Path $env:LOCALAPPDATA "PocketLeft\WebView2"
$marker = Join-Path $profile "installer-smoke-marker.txt"
$startupCommand = '"{0}" --background' -f $app

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
