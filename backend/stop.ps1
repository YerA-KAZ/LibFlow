param([string]$PostgresBin = 'C:\Program Files\PostgreSQL\18\bin')
$ErrorActionPreference = 'Stop'
$data = Join-Path $PSScriptRoot '.postgres\data'
if (Test-Path -LiteralPath (Join-Path $data 'PG_VERSION')) {
    & (Join-Path $PostgresBin 'pg_ctl.exe') stop -D $data -m fast -w
}
