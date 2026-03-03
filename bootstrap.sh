#!/usr/bin/env bash
# SpatchEx 자동화 툴 — Mac 원클릭 부트스트랩
# 사용법: curl -fsSL https://raw.githubusercontent.com/DunkinYeo/SpatchEx-Automation/main/bootstrap.sh | bash
#
# 이 스크립트가 하는 일:
#   1. Homebrew 설치 (없으면)
#   2. Git 설치 (없으면)
#   3. 코드 다운로드 (~/SpatchEx-Automation)
#   4. Python / Node.js / ADB / Appium / Python 패키지 설치
#   5. 웹 UI 실행 → 브라우저 자동 오픈
set -e

REPO_URL="https://github.com/DunkinYeo/SpatchEx-Automation.git"
INSTALL_DIR="$HOME/SpatchEx-Automation"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'
ok()   { echo -e "${GREEN}  ✓ $1${NC}"; }
step() { echo -e "\n${YELLOW}${BOLD}▶ $1${NC}"; }

echo ""
echo "  ╔════════════════════════════════════════════╗"
echo "  ║   SpatchEx 장기 실행 테스트 — 설치 시작   ║"
echo "  ╚════════════════════════════════════════════╝"
echo ""

# ── 1. Homebrew ───────────────────────────────────────────────────────────────
step "Homebrew 확인"
if ! command -v brew &>/dev/null; then
  echo "  Homebrew를 설치합니다 (관리자 비밀번호가 필요할 수 있습니다)..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
# Apple Silicon / Intel PATH
eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv 2>/dev/null || true)"
ok "Homebrew $(brew --version | head -1)"

# ── 2. Git ────────────────────────────────────────────────────────────────────
step "Git 확인"
if ! command -v git &>/dev/null; then
  brew install git
fi
ok "Git $(git --version)"

# ── 3. 코드 다운로드 ──────────────────────────────────────────────────────────
step "코드 다운로드"
if [ -d "$INSTALL_DIR/.git" ]; then
  echo "  이미 설치됨 — 최신 버전으로 업데이트 중..."
  git -C "$INSTALL_DIR" pull --ff-only
  ok "업데이트 완료 ($INSTALL_DIR)"
else
  git clone "$REPO_URL" "$INSTALL_DIR"
  ok "다운로드 완료 ($INSTALL_DIR)"
fi

# ── 4. 의존성 설치 (install.sh 위임) ─────────────────────────────────────────
step "의존성 설치 (Python / Node.js / ADB / Appium)"
bash "$INSTALL_DIR/install.sh"

# ── 5. 웹 UI 실행 ─────────────────────────────────────────────────────────────
echo ""
echo "  ╔════════════════════════════════════════════╗"
echo "  ║         설치 완료! 테스트 UI 시작 중…     ║"
echo "  ╚════════════════════════════════════════════╝"
echo ""
bash "$INSTALL_DIR/start.sh"
