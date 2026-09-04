# .env 에 시크릿 한 줄을 넣는다. 값은 화면에도, 명령 기록에도 남지 않는다.
#
# ★ 이 머신은 PowerShell 실행 정책이 .ps1 을 막는다. 아래 형태로 부른다.
#
#   powershell -ExecutionPolicy Bypass -File .\scripts\set-secret.ps1 INTERNAL_SHARED_SECRET
#
# ★ 더 간단한 길: Python 쪽을 쓰면 실행 정책과 무관하다. 그쪽을 권한다.
#
#   .\.venv\Scripts\python.exe -m app.setsecret INTERNAL_SHARED_SECRET
#
# 왜 이 스크립트인가 — 시크릿을 채팅·이슈·명령 인자로 넘기면 그 기록에 남는다.
# Read-Host -AsSecureString 은 입력이 화면에 찍히지 않고, PowerShell 기록에도
# 남지 않는다. 값은 이 프로세스 안에서만 평문이 되고 바로 .env 로 들어간다.
#
# 근거: 계약 §3-1(시크릿은 양쪽 환경변수로만, 저장소에 넣지 않는다)

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidatePattern('^[A-Z][A-Z0-9_]*$')]
    [string]$Name,

    [string]$EnvFile
)

$ErrorActionPreference = 'Stop'

if (-not $EnvFile) {
    $EnvFile = Join-Path (Split-Path -Parent $PSScriptRoot) '.env'
}

if (-not (Test-Path $EnvFile)) {
    Write-Host ".env 가 없습니다: $EnvFile" -ForegroundColor Red
    Write-Host "  .env.example 을 복사해서 만드세요:  Copy-Item .env.example .env"
    exit 1
}

Write-Host ""
Write-Host "$Name 값을 붙여넣고 Enter. 화면에 표시되지 않습니다." -ForegroundColor Cyan
$secure = Read-Host -AsSecureString

$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try {
    $value = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
}
finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
}

$value = $value.Trim()

if ([string]::IsNullOrWhiteSpace($value)) {
    Write-Host "빈 값입니다. 아무것도 바꾸지 않았습니다." -ForegroundColor Yellow
    exit 1
}

# 붙여넣기 사고를 먼저 잡는다. 여기서 안 잡으면 나중에 401을 디버깅하게 된다.
if ($value -match '^\s*["'']' -or $value -match '["'']\s*$') {
    Write-Host "값의 앞이나 뒤에 따옴표가 있습니다. 따옴표는 빼고 넣으세요." -ForegroundColor Yellow
    exit 1
}
# '=' 가 있다는 것만으로 거부하지 않는다 — openssl rand -base64 32 는 = 로 끝나고,
# 그게 INTERNAL_SHARED_SECRET 의 형식이다. 넣으려는 키 이름으로 시작할 때만 거부한다.
if ($value.ToUpper().StartsWith("$($Name.ToUpper())=")) {
    Write-Host "'$Name=값' 통째로 붙여넣으신 것 같습니다. 값만 넣으세요." -ForegroundColor Yellow
    exit 1
}
if ($value -match '\r|\n') {
    Write-Host "값에 줄바꿈이 있습니다. 한 줄로 붙여넣으세요." -ForegroundColor Yellow
    exit 1
}

$lines = [System.IO.File]::ReadAllLines($EnvFile)
$found = $false
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match "^\s*$([regex]::Escape($Name))\s*=") {
        $lines[$i] = "$Name=$value"
        $found = $true
        break
    }
}
if (-not $found) {
    $lines += "$Name=$value"
}

# UTF-8, BOM 없이. BOM이 붙으면 첫 줄의 키 이름이 깨져 읽히지 않는다.
$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($EnvFile, $lines, $utf8)

$shown = if ($value.Length -le 8) { "(설정됨, $($value.Length)자)" }
         else { "$($value.Substring(0,4))...$($value.Substring($value.Length-2)) ($($value.Length)자)" }

Write-Host ""
Write-Host "$Name 을(를) .env 에 넣었습니다.  $shown" -ForegroundColor Green
Write-Host "확인:  .\.venv\Scripts\python.exe -m app.envcheck"
Write-Host ""
