#!/usr/bin/env bash
# SpatchEx 자동화 툴 — Mac 최초 설치 스크립트
# 실행: bash install.sh  (또는 ./install.sh)
set -e
cd "$(dirname "$0")"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GREEN}  ✓ $1${NC}"; }
step() { echo -e "\n${YELLOW}▶ $1${NC}"; }
err()  { echo -e "${RED}  ✗ $1${NC}"; exit 1; }

echo ""
echo "  ╔══════════════════════════════════════╗"
echo "  ║  SpatchEx 장기 실행 테스트 — 설치   ║"
echo "  ╚══════════════════════════════════════╝"
echo ""

# ── 1. Homebrew ───────────────────────────────────────────────────────────────
step "Homebrew 확인"
if ! command -v brew &>/dev/null; then
  echo "  Homebrew를 설치합니다 (관리자 비밀번호가 필요할 수 있습니다)..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Apple Silicon PATH fix
  eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv 2>/dev/null || true)"
  ok "Homebrew 설치 완료"
else
  ok "Homebrew 이미 설치됨"
fi

# ── 2. Python 3 ───────────────────────────────────────────────────────────────
step "Python 3 확인"
if ! command -v python3 &>/dev/null; then
  brew install python
  ok "Python 설치 완료"
else
  PY_VER=$(python3 --version)
  ok "Python 이미 설치됨 ($PY_VER)"
fi

# ── 3. Node.js (Appium 필수) ─────────────────────────────────────────────────
step "Node.js 확인"
if ! command -v node &>/dev/null; then
  brew install node
  ok "Node.js 설치 완료"
else
  ok "Node.js 이미 설치됨 ($(node --version))"
fi

# ── 4. Android Platform Tools (adb) ──────────────────────────────────────────
step "ADB(Android 연결 도구) 확인"
if ! command -v adb &>/dev/null; then
  brew install --cask android-platform-tools
  ok "ADB 설치 완료"
else
  ok "ADB 이미 설치됨 ($(adb --version | head -1))"
fi

# ── 5. Appium ─────────────────────────────────────────────────────────────────
step "Appium 확인"
if ! command -v appium &>/dev/null; then
  npm install -g appium
  ok "Appium 설치 완료"
else
  ok "Appium 이미 설치됨 ($(appium --version))"
fi

step "Appium UiAutomator2 드라이버 확인"
if ! appium driver list --installed 2>/dev/null | grep -q "uiautomator2"; then
  appium driver install uiautomator2
  ok "UiAutomator2 드라이버 설치 완료"
else
  ok "UiAutomator2 이미 설치됨"
fi

# ── 6. Python 가상환경 ────────────────────────────────────────────────────────
step "Python 가상환경 설정"
if [ ! -d ".venv" ]; then
  python3 -m venv .venv
  ok "가상환경 생성 완료"
else
  ok "가상환경 이미 존재함"
fi

source .venv/bin/activate
pip install -r requirements.txt -q
ok "Python 패키지 설치 완료"

# ── 완료 ─────────────────────────────────────────────────────────────────────
echo ""
echo "  ╔══════════════════════════════════════╗"
echo "  ║        설치가 완료되었습니다! 🎉     ║"
echo "  ╚══════════════════════════════════════╝"
echo ""
echo "  다음 단계:"
echo "  1. 안드로이드 폰을 USB로 연결하거나 WiFi로 페어링"
echo "  2. ./start.sh 실행 → 브라우저에서 테스트 시작"
echo ""
