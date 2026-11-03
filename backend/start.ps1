param(
    [string]$PostgresBin = 'C:\Program Files\PostgreSQL\18\bin',
    [int]$DatabasePort = 55432,
    [int]$ApiPort = 8000,
    [switch]$DatabaseOnly
)
$ErrorActionPreference = 'Stop'
$runtime = Join-Path $PSScriptRoot '.postgres'
$data = Join-Path $runtime 'data'
$pgCtl = Join-Path $PostgresBin 'pg_ctl.exe'
if (-not (Test-Path -LiteralPath $pgCtl)) { throw 'PostgreSQL bin was not found. Set -PostgresBin.' }
New-Item -ItemType Directory -Force -Path $runtime | Out-Null
if ((Test-Path -LiteralPath (Join-Path $data 'PG_VERSION')) -and
    -not (Test-Path -LiteralPath (Join-Path $data 'pg_hba.conf'))) {
    throw 'Incomplete PostgreSQL cluster. Move .postgres/data aside before retrying.'
}
if (-not (Test-Path -LiteralPath (Join-Path $data 'PG_VERSION'))) {
    if (Test-Path -LiteralPath (Join-Path $PSScriptRoot '.env')) {
        throw 'backend/.env already exists. Use its existing database or move it aside before initializing.'
    }
    $password = [Guid]::NewGuid().ToString('N')
    $passwordFile = Join-Path $runtime 'init-password.tmp'
    try {
        Set-Content -LiteralPath $passwordFile -Value $password -Encoding ascii
        & (Join-Path $PostgresBin 'initdb.exe') -D $data -U libflow -A scram-sha-256 --encoding=UTF8 --locale=C --pwfile=$passwordFile
        if ($LASTEXITCODE -ne 0) { throw 'PostgreSQL initialization failed.' }
        # Runtime credentials remain in the ignored .env file.
        Set-Content -LiteralPath (Join-Path $PSScriptRoot '.env') -Encoding ascii -Value "DATABASE_URL=postgresql://libflow:$password@127.0.0.1:$DatabasePort/libflow"
    } finally {
        if (Test-Path -LiteralPath $passwordFile) { Remove-Item -LiteralPath $passwordFile }
    }
}
& $pgCtl status -D $data *> $null
if ($LASTEXITCODE -ne 0) {
    & $pgCtl start -D $data -l (Join-Path $runtime 'postgres.log') -o "-h 127.0.0.1 -p $DatabasePort" -w
    if ($LASTEXITCODE -ne 0) { throw 'PostgreSQL failed to start. See .postgres/postgres.log.' }
}
$python = Join-Path $PSScriptRoot '.venv\Scripts\python.exe'
if (-not (Test-Path -LiteralPath $python)) { throw 'Create backend/.venv and install requirements.txt first.' }
# Create only this application's database. Never alter an existing installation.
& $python (Join-Path $PSScriptRoot 'create_database.py')
if ($LASTEXITCODE -ne 0) { throw 'Database creation failed.' }
if ($DatabaseOnly) { return }
Push-Location (Split-Path $PSScriptRoot)
try {
    & $python -m uvicorn backend.app:app --host 0.0.0.0 --port $ApiPort
} finally { Pop-Location }
