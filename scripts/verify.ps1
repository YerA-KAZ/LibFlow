param([string]$DeviceId = '', [switch]$SkipPubGet)
$ErrorActionPreference = 'Stop'
Push-Location (Split-Path $PSScriptRoot)
try {
    New-Item -ItemType Directory -Force build/final-evidence | Out-Null
    if (-not $SkipPubGet) {
        & flutter pub get
        if ($LASTEXITCODE -ne 0) { throw 'pub get failed. On Windows check Developer Mode / symlink support.' }
    }
    & flutter analyze --no-pub 2>&1 | Tee-Object build/final-evidence/analyze.log
    if ($LASTEXITCODE -ne 0) { throw 'Static analysis failed.' }
    & flutter test --no-pub --machine 2>&1 | Tee-Object build/final-evidence/flutter-tests.jsonl
    if ($LASTEXITCODE -ne 0) { throw 'Flutter tests failed.' }
    & backend/.venv/Scripts/python.exe -m pytest backend -q --tb=short --junitxml=build/final-evidence/backend-junit.xml 2>&1 | Tee-Object build/final-evidence/backend-tests.log
    if ($LASTEXITCODE -ne 0) { throw 'Backend tests failed. Check PostgreSQL / TEST_DATABASE_URL.' }
    if ($DeviceId) {
        & flutter test --no-pub integration_test/app_smoke_test.dart -d $DeviceId --reporter expanded 2>&1 | Tee-Object build/final-evidence/android-integration-final.log
        if ($LASTEXITCODE -ne 0) { throw 'Device integration test failed.' }
    }
    & flutter build apk --debug --no-pub 2>&1 | Tee-Object build/final-evidence/apk-build.log
    if ($LASTEXITCODE -ne 0) { throw 'APK build failed.' }
    & python scripts/summarize_evidence.py
    if ($LASTEXITCODE -ne 0) { throw 'Test report generation failed.' }
    & python scripts/package_final.py
    if ($LASTEXITCODE -ne 0) { throw 'Packaging failed.' }
} finally { Pop-Location }
