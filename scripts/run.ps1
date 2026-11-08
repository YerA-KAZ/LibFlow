param(
    [string]$AvdName = 'Pixel_7',
    [int]$MemoryMB = 1536,
    [int]$ApiPort = 8000,
    [switch]$UpdateDependencies,
    [switch]$NoAttach,
    [switch]$Attach,
    [switch]$CheckOnly
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot

function Find-AndroidSdk {
    $properties = Join-Path $projectRoot 'android/local.properties'
    $candidates = @($env:ANDROID_HOME, $env:ANDROID_SDK_ROOT)
    if (Test-Path -LiteralPath $properties) {
        $line = Get-Content -LiteralPath $properties | Where-Object { $_ -match '^sdk\.dir=' } | Select-Object -First 1
        if ($line) { $candidates += ($line.Substring(8).Replace('\\', '\').Replace('\:', ':')) }
    }
    $candidates += (Join-Path $env:LOCALAPPDATA 'Android/Sdk')
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath (Join-Path $candidate 'platform-tools/adb.exe'))) {
            return $candidate
        }
    }
    throw 'Android SDK not found. Set ANDROID_HOME or install Android SDK in Android Studio.'
}

function Get-ApiReady {
    try {
        $health = Invoke-RestMethod -Uri "http://127.0.0.1:$ApiPort/health" -TimeoutSec 2
        return ($health.status -eq 'ok' -and $health.database -eq 'postgresql')
    } catch { return $false }
}

function Find-AvdDevice {
    $devices = & $adb devices
    foreach ($line in $devices) {
        if ($line -match '^(emulator-\d+)\s+device\s*$') {
            $candidateId = $Matches[1]
            $name = @(& $adb -s $candidateId emu avd name 2>$null)[0]
            if ($name -eq $AvdName) { return $candidateId }
        }
    }
    return $null
}

Push-Location $projectRoot
try {
    $flutter = (Get-Command flutter -ErrorAction Stop).Source
    $sdk = Find-AndroidSdk
    $adb = Join-Path $sdk 'platform-tools/adb.exe'
    $emulator = Join-Path $sdk 'emulator/emulator.exe'
    $python = Join-Path $projectRoot 'backend/.venv/Scripts/python.exe'
    foreach ($required in @($emulator, $python)) {
        if (-not (Test-Path -LiteralPath $required)) { throw "Required file missing: $required. See README setup instructions." }
    }
    $avds = @(& $emulator -list-avds)
    if ($LASTEXITCODE -ne 0 -or $avds -notcontains $AvdName) {
        throw "AVD '$AvdName' not found. Create it in Android Studio Device Manager or pass -AvdName NAME."
    }
    if ($CheckOnly) {
        Write-Host "Flutter: $flutter"
        Write-Host "Android SDK: $sdk"
        Write-Host "AVD: $AvdName; memory: $MemoryMB MB"
        Write-Host "Backend Python: $python"
        Write-Host "API ready: $(Get-ApiReady)"
        Write-Host 'Configuration OK. Run .\run.bat to launch.'
        exit 0
    }

    $logDir = Join-Path $projectRoot 'build/launcher'
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    Write-Host '[1/4] Starting PostgreSQL and API...'
    if (-not (Get-ApiReady)) {
        $tcp = New-Object Net.Sockets.TcpClient
        try {
            $connection = $tcp.BeginConnect('127.0.0.1', $ApiPort, $null, $null)
            $portUsed = $connection.AsyncWaitHandle.WaitOne(500) -and $tcp.Connected
        } finally { $tcp.Dispose() }
        if ($portUsed) { throw "Port $ApiPort is occupied but LibFlow /health is not healthy. Check the server before retrying." }
        $serverScript = Join-Path $projectRoot 'backend/start.ps1'
        $server = Start-Process powershell.exe -ArgumentList @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$serverScript`"", '-ApiPort', $ApiPort
        ) -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru `
            -RedirectStandardOutput (Join-Path $logDir 'api.stdout.log') `
            -RedirectStandardError (Join-Path $logDir 'api.stderr.log')
        $deadline = (Get-Date).AddSeconds(90)
        while (-not (Get-ApiReady)) {
            if ($server.HasExited -or (Get-Date) -gt $deadline) {
                throw "API did not start. See $logDir/api.stderr.log and api.stdout.log."
            }
            Start-Sleep -Seconds 1
        }
    }

    Write-Host '[2/4] Opening Android emulator window...'
    $deviceId = Find-AvdDevice
    # Replace only this AVD's headless session; preserve its saved user data.
    $headless = @(Get-CimInstance Win32_Process -Filter "name = 'emulator.exe'" | Where-Object {
        $_.CommandLine -match ('-avd\s+"?' + [regex]::Escape($AvdName) + '(?:"|\s|$)') -and
        $_.CommandLine -match '-no-window'
    })
    if ($deviceId -and $headless.Count -gt 0) {
        Write-Host 'Restarting this AVD with a visible window...'
        & $adb -s $deviceId emu kill | Out-Null
        $deadline = (Get-Date).AddSeconds(30)
        while (Find-AvdDevice) {
            if ((Get-Date) -gt $deadline) { throw 'Headless emulator did not stop. Close it and retry.' }
            Start-Sleep -Seconds 1
        }
        $deviceId = $null
    }
    if (-not $deviceId) {
        Start-Process -FilePath $emulator -ArgumentList @(
            '-avd', $AvdName, '-memory', $MemoryMB, '-gpu', 'swiftshader', '-no-snapshot-load'
        ) -WindowStyle Normal `
            -RedirectStandardOutput (Join-Path $logDir 'emulator.stdout.log') `
            -RedirectStandardError (Join-Path $logDir 'emulator.stderr.log') | Out-Null
    }
    $deadline = (Get-Date).AddMinutes(4)
    do {
        $deviceId = Find-AvdDevice
        $booted = $deviceId -and ((& $adb -s $deviceId shell getprop sys.boot_completed 2>$null) -eq '1')
        if ((Get-Date) -gt $deadline) { throw "Emulator boot timed out. See $logDir/emulator.stderr.log." }
        if (-not $booted) { Start-Sleep -Seconds 2 }
    } until ($booted)

    Write-Host '[3/4] Checking Flutter dependencies...'
    if ($UpdateDependencies -or -not (Test-Path -LiteralPath '.dart_tool/package_config.json')) {
        & $flutter pub get
        if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed. On Windows check Developer Mode / symlink support.' }
    }
    Write-Host "[4/4] Building and updating LibFlow without deleting app data..."
    & $flutter build apk --debug --no-pub "--dart-define=API_BASE_URL=http://10.0.2.2:$ApiPort"
    if ($LASTEXITCODE -ne 0) { throw 'APK build failed; the installed application was not changed.' }
    $apk = Join-Path $projectRoot 'build/app/outputs/flutter-apk/app-debug.apk'
    # flutter run retries a failed install by uninstalling the old application.
    # Use adb -r directly and stop on failure: never uninstall or clear user data.
    $installOutput = @(& $adb -s $deviceId install -r $apk 2>&1)
    $installExit = $LASTEXITCODE
    $installOutput | Set-Content -LiteralPath (Join-Path $logDir 'install.log')
    if ($installExit -ne 0 -or ($installOutput -join "`n") -match 'Failure') {
        throw "APK update failed. Existing app data was preserved. See $logDir/install.log. Do not uninstall the app to retry."
    }
    & $adb -s $deviceId shell am force-stop com.libflow.libflow
    if ($LASTEXITCODE -ne 0) { throw 'Could not stop the previous app process.' }
    $launched = $false
    # Android may briefly show PackageUpdateActivity after an APK replacement.
    for ($attempt = 0; $attempt -lt 5; $attempt++) {
        $launchOutput = @(& $adb -s $deviceId shell am start -W -n com.libflow.libflow/.MainActivity 2>&1)
        $launchExit = $LASTEXITCODE
        $launchText = $launchOutput -join "`n"
        if ($launchExit -eq 0 -and $launchText -match '(?m)^Activity:\s+com\.libflow\.libflow/') {
            Write-Host $launchText
            $launched = $true
            break
        }
        Start-Sleep -Seconds 2
    }
    if (-not $launched) { throw 'Could not launch LibFlow after the package update. App data was preserved.' }
    if ($Attach -and -not $NoAttach) {
        Write-Host 'LibFlow opened. Connecting hot reload; press q to exit.'
        & $flutter attach -d $deviceId --app-id com.libflow.libflow -t lib/main.dart "--dart-define=API_BASE_URL=http://10.0.2.2:$ApiPort"
        exit $LASTEXITCODE
    }
    Write-Host 'LibFlow is open. You may close this terminal; the app and saved accounts remain on the emulator.'
    exit 0
} catch {
    Write-Host "Launcher error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally { Pop-Location }
