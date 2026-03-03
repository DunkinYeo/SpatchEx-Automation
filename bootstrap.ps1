# SpatchEx Automation Tool -- Windows one-click bootstrap
# Usage (PowerShell as Administrator):
#   irm https://raw.githubusercontent.com/DunkinYeo/SpatchEx-Automation/main/bootstrap.ps1 | iex
#
# What this script does:
#   1. Install Git / Python 3 / Node.js / ADB via winget
#   2. Download code to $HOME\SpatchEx-Automation
#   3. Install Appium + Python packages
#   4. Launch web UI -> opens browser automatically
$ErrorActionPreference = "Stop"

$REPO_URL   = "https://github.com/DunkinYeo/SpatchEx-Automation.git"
$INSTALL_DIR = "$HOME\SpatchEx-Automation"

function ok($msg)   { Write-Host "  OK  $msg" -ForegroundColor Green }
function step($msg) { Write-Host "`n>> $msg" -ForegroundColor Yellow }

Write-Host ""
Write-Host "  +------------------------------------------+" -ForegroundColor Cyan
Write-Host "  |  SpatchEx Long-Run Test -- Setup Start   |" -ForegroundColor Cyan
Write-Host "  +------------------------------------------+" -ForegroundColor Cyan
Write-Host ""

# Refresh PATH helper
function Refresh-Path {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path","User")
}

# ── 1. Git ────────────────────────────────────────────────────────────────────
step "Checking Git"
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "  Installing Git via winget..."
    winget install Git.Git -e --accept-package-agreements --accept-source-agreements
    Refresh-Path
}
ok "Git $(git --version)"

# ── 2. Python ─────────────────────────────────────────────────────────────────
step "Checking Python 3"
if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    Write-Host "  Installing Python via winget..."
    winget install Python.Python.3.12 -e --accept-package-agreements --accept-source-agreements
    Refresh-Path
}
ok "Python $(python --version)"

# ── 3. Node.js ────────────────────────────────────────────────────────────────
step "Checking Node.js"
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "  Installing Node.js via winget..."
    winget install OpenJS.NodeJS.LTS -e --accept-package-agreements --accept-source-agreements
    Refresh-Path
}
ok "Node.js $(node --version)"

# ── 4. ADB ────────────────────────────────────────────────────────────────────
step "Checking ADB"
if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
    Write-Host "  Installing Android Platform Tools via winget..."
    winget install Google.PlatformTools -e --accept-package-agreements --accept-source-agreements
    Refresh-Path
}
ok "ADB installed"

# ── 5. Download code ──────────────────────────────────────────────────────────
step "Downloading code"
if (Test-Path "$INSTALL_DIR\.git") {
    Write-Host "  Already installed - updating to latest..."
    git -C $INSTALL_DIR pull --ff-only
    ok "Updated ($INSTALL_DIR)"
} else {
    git clone $REPO_URL $INSTALL_DIR
    ok "Downloaded ($INSTALL_DIR)"
}

# ── 6. Appium + UiAutomator2 ──────────────────────────────────────────────────
step "Checking Appium"
if (-not (Get-Command appium -ErrorAction SilentlyContinue)) {
    Write-Host "  Installing Appium..."
    npm install -g appium
}
$driverList = appium driver list --installed 2>&1
if ($driverList -notmatch "uiautomator2") {
    appium driver install uiautomator2
}
ok "Appium $(appium --version)"

# ── 7. Python virtual environment + packages ──────────────────────────────────
step "Installing Python packages"
Set-Location $INSTALL_DIR
if (-not (Test-Path ".venv")) {
    python -m venv .venv
}
& ".venv\Scripts\pip.exe" install -r requirements.txt -q
ok "Packages installed"

# ── 8. Launch web UI ─────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  +------------------------------------------+" -ForegroundColor Green
Write-Host "  |   Setup complete! Launching Test UI...   |" -ForegroundColor Green
Write-Host "  +------------------------------------------+" -ForegroundColor Green
Write-Host ""
& "$INSTALL_DIR\start.bat"
