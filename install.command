#!/usr/bin/env bash
# ┌─────────────────────────────────────────────────────────┐
# │  SpatchEx 자동화 툴 — Mac 최초 설치                     │
# │  이 파일을 더블클릭하면 설치가 자동으로 진행됩니다.     │
# └─────────────────────────────────────────────────────────┘
set -e

# 이 스크립트가 있는 폴더로 이동
cd "$(dirname "$0")"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'
ok()   { echo -e "${GREEN}  ✓ $1${NC}"; }
step() { echo -e "\n${YELLOW}${BOLD}▶ $1${NC}"; }
err()  { echo -e "${RED}  ✗ 오류: $1${NC}"; echo ""; read -p "  Enter를 눌러 창을 닫으세요..."; exit 1; }

clear
echo ""
echo "  ╔══════════════════════════════════════════╗"
echo "  ║   S-Patch EX 자동화 툴 — 설치 시작 🚀   ║"
echo "  ╚══════════════════════════════════════════╝"
echo ""
echo "  필요한 프로그램을 자동으로 설치합니다."
echo "  중간에 비밀번호 입력이 필요할 수 있습니다."
echo ""
read -p "  계속하려면 Enter를 누르세요..."

# ── 1. Xcode Command Line Tools (git, cc 포함) ────────────────────────────────
step "기본 개발 도구 확인"
if ! xcode-select -p &>/dev/null; then
  echo "  개발 도구를 설치합니다 (팝업창에서 '설치'를 클릭하세요)..."
  xcode-select --install
  echo "  설치가 완료되면 Enter를 누르세요..."
  read -p ""
fi
ok "기본 개발 도구"

# ── 2. Homebrew ───────────────────────────────────────────────────────────────
step "Homebrew 확인 (패키지 관리자)"
if ! command -v brew &>/dev/null; then
  echo "  Homebrew를 설치합니다..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || err "Homebrew 설치 실패"
  # Apple Silicon PATH 설정
  if [ -f /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
  fi
  ok "Homebrew 설치 완료"
else
  ok "Homebrew 이미 설치됨"
fi

# ── 3. Python ────────────────────────────────────────────────────────────────
step "Python 확인"
if ! command -v python3 &>/dev/null; then
  brew install python || err "Python 설치 실패"
  ok "Python 설치 완료"
else
  ok "Python 이미 설치됨 ($(python3 --version))"
fi

# ── 4. Node.js ───────────────────────────────────────────────────────────────
step "Node.js 확인 (Appium 실행에 필요)"
if ! command -v node &>/dev/null; then
  brew install node || err "Node.js 설치 실패"
  ok "Node.js 설치 완료"
else
  ok "Node.js 이미 설치됨 ($(node --version))"
fi

# ── 5. ADB ───────────────────────────────────────────────────────────────────
step "Android 연결 도구(ADB) 확인"
if ! command -v adb &>/dev/null; then
  brew install --cask android-platform-tools || err "ADB 설치 실패"
  ok "ADB 설치 완료"
else
  ok "ADB 이미 설치됨"
fi

# ── 6. Appium ────────────────────────────────────────────────────────────────
step "Appium 확인 (앱 자동화 서버)"
if ! command -v appium &>/dev/null; then
  npm install -g appium || err "Appium 설치 실패"
  ok "Appium 설치 완료"
else
  ok "Appium 이미 설치됨 ($(appium --version))"
fi

step "Appium Android 드라이버 확인"
if ! appium driver list --installed 2>/dev/null | grep -q "uiautomator2"; then
  appium driver install uiautomator2 || err "UiAutomator2 드라이버 설치 실패"
  ok "UiAutomator2 드라이버 설치 완료"
else
  ok "UiAutomator2 드라이버 이미 설치됨"
fi

# ── 7. Python 패키지 ─────────────────────────────────────────────────────────
step "Python 패키지 설치"
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt -q || err "패키지 설치 실패"
ok "Python 패키지 설치 완료"

# ── 완료 ─────────────────────────────────────────────────────────────────────
echo ""
echo "  ╔══════════════════════════════════════════╗"
echo "  ║         설치 완료! 🎉                    ║"
echo "  ╚══════════════════════════════════════════╝"
echo ""
echo "  ✅ 모든 프로그램이 설치되었습니다."
echo ""
echo "  다음 단계:"
echo "  1. 안드로이드 폰을 USB 케이블로 PC에 연결"
echo "     (폰 화면에 '디버깅 허용?' 팝업이 뜨면 '허용' 탭)"
echo ""
echo "  2. start.command 파일을 더블클릭하여 테스트 시작"
echo ""
read -p "  Enter를 눌러 창을 닫으세요..."
