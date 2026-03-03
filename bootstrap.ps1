# SpatchEx 자동화 툴 — Windows 원클릭 부트스트랩
# 사용법 (PowerShell 관리자):
#   irm https://raw.githubusercontent.com/DunkinYeo/SpatchEx-Automation/main/bootstrap.ps1 | iex
#
# 이 스크립트가 하는 일:
#   1. Git / Python 3 / Node.js / ADB 설치 (winget 사용)
#   2. 코드 다운로드 ($HOME\SpatchEx-Automation)
#   3. Appium + Python 패키지 설치
#   4. 웹 UI 실행 → 브라우저 자동 오픈
$ErrorActionPreference = "Stop"

$REPO_URL   = "https://github.com/DunkinYeo/SpatchEx-Automation.git"
$INSTALL_DIR = "$HOME\SpatchEx-Automation"

function ok($msg)   { Write-Host "  OK  $msg" -ForegroundColor Green }
function step($msg) { Write-Host "`n>> $msg" -ForegroundColor Yellow }

Write-Host ""
Write-Host "  +------------------------------------------+" -ForegroundColor Cyan
Write-Host "  |  SpatchEx 장기 실행 테스트 - 설치 시작  |" -ForegroundColor Cyan
Write-Host "  +------------------------------------------+" -ForegroundColor Cyan
Write-Host ""

# winget PATH 새로고침 헬퍼
function Refresh-Path {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path","User")
}

# ── 1. Git ────────────────────────────────────────────────────────────────────
step "Git 확인"
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "  Git 설치 중 (winget)..."
    winget install Git.Git -e --accept-package-agreements --accept-source-agreements
    Refresh-Path
}
ok "Git $(git --version)"

# ── 2. Python ─────────────────────────────────────────────────────────────────
step "Python 3 확인"
if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    Write-Host "  Python 설치 중 (winget)..."
    winget install Python.Python.3.12 -e --accept-package-agreements --accept-source-agreements
    Refresh-Path
}
ok "Python $(python --version)"

# ── 3. Node.js ────────────────────────────────────────────────────────────────
step "Node.js 확인"
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "  Node.js 설치 중 (winget)..."
    winget install OpenJS.NodeJS.LTS -e --accept-package-agreements --accept-source-agreements
    Refresh-Path
}
ok "Node.js $(node --version)"

# ── 4. ADB ────────────────────────────────────────────────────────────────────
step "ADB 확인"
if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
    Write-Host "  Android Platform Tools 설치 중 (winget)..."
    winget install Google.PlatformTools -e --accept-package-agreements --accept-source-agreements
    Refresh-Path
}
ok "ADB 설치됨"

# ── 5. 코드 다운로드 ──────────────────────────────────────────────────────────
step "코드 다운로드"
if (Test-Path "$INSTALL_DIR\.git") {
    Write-Host "  이미 설치됨 - 최신 버전으로 업데이트 중..."
    git -C $INSTALL_DIR pull --ff-only
    ok "업데이트 완료 ($INSTALL_DIR)"
} else {
    git clone $REPO_URL $INSTALL_DIR
    ok "다운로드 완료 ($INSTALL_DIR)"
}

# ── 6. Appium + UiAutomator2 ──────────────────────────────────────────────────
step "Appium 확인"
if (-not (Get-Command appium -ErrorAction SilentlyContinue)) {
    Write-Host "  Appium 설치 중..."
    npm install -g appium
}
$driverList = appium driver list --installed 2>&1
if ($driverList -notmatch "uiautomator2") {
    appium driver install uiautomator2
}
ok "Appium $(appium --version)"

# ── 7. Python 가상환경 + 패키지 ───────────────────────────────────────────────
step "Python 패키지 설치"
Set-Location $INSTALL_DIR
if (-not (Test-Path ".venv")) {
    python -m venv .venv
}
& ".venv\Scripts\pip.exe" install -r requirements.txt -q
ok "패키지 설치 완료"

# ── 8. 웹 UI 실행 ─────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  +------------------------------------------+" -ForegroundColor Green
Write-Host "  |    설치 완료! 테스트 UI 시작 중...       |" -ForegroundColor Green
Write-Host "  +------------------------------------------+" -ForegroundColor Green
Write-Host ""
& "$INSTALL_DIR\start.bat"
