# spatch-longrun-automation

Long-running app test orchestrator for S-PATCH EX style apps (24/48/72h) with **scheduled symptom injection**.
Android first (Appium + UiAutomator2). iOS stub included for later.

## What this does (MVP)
- Starts a measurement (handles online/offline consent path)
- While test is running: injects symptoms every N hours (or by a plan)
- Collects artifacts on every injection (screenshot + logcat)
- Watchdog: retries, brings app to foreground, and attempts recovery
- Outputs: `output/<run_id>/...` with JSONL event log + HTML summary

---

## 사용 방법 (Web UI — 비개발자용)

### 🚀 원클릭 설치 + 실행

#### 방법 1 — ZIP 파일 공유 (가장 간단, 채팅으로 전달 가능)

**[⬇ ZIP 다운로드](https://github.com/DunkinYeo/SpatchEx-Automation/archive/refs/heads/main.zip)**

1. ZIP 다운로드 → 압축 해제
2. 폴더 안의 파일을 더블클릭:

| OS | 파일 |
|----|------|
| Mac | `실행.command` 더블클릭 |
| Windows | `실행.bat` 더블클릭 |

> 처음 실행 시 Python·Node.js·ADB·Appium 자동 설치 (5~15분).
> 두 번째 실행부터는 바로 웹 UI가 열립니다.

> **Mac 주의**: 처음 더블클릭 시 "개발자를 확인할 수 없음" 경고 → 우클릭 → 열기 → 열기

---

#### 방법 2 — 터미널 한 줄 (터미널에 익숙한 경우)

**Mac:**
```bash
curl -fsSL https://raw.githubusercontent.com/DunkinYeo/SpatchEx-Automation/main/bootstrap.sh | bash
```
**Windows** (PowerShell 관리자):
```powershell
irm https://raw.githubusercontent.com/DunkinYeo/SpatchEx-Automation/main/bootstrap.ps1 | iex
```

---

### 이미 설치한 경우 — 실행만 하기

| OS | 파일 |
|----|------|
| Mac | `실행.command` 또는 `start.sh` 더블클릭 |
| Windows | `실행.bat` 또는 `start.bat` 더블클릭 |

브라우저가 자동으로 열리면 → 설정 후 **▶ 테스트 시작** 클릭

### 3. 디바이스 연결 방법

#### USB 케이블 (기본)
1. 개발자 옵션 활성화 (설정 → 빌드 번호 7번 탭)
2. USB 디버깅 ON
3. USB 케이블 연결 후 팝업에서 "허용"
4. 확인: `adb devices` → 시리얼 번호 표시되면 OK

#### WiFi 무선 연결 (Android 11+, 케이블 불필요)
1. 개발자 옵션 → **무선 디버깅** ON
2. **페어링 코드로 기기 페어링** 탭
3. 화면에 표시된 IP:포트와 코드 확인 후 아래 명령 실행:
   ```bash
   adb pair <IP>:<페어링포트>     # 예: adb pair 192.168.1.5:39517
   # 코드 입력 후 "Successfully paired" 메시지 확인
   adb connect <IP>:<디버깅포트>  # 예: adb connect 192.168.1.5:42135
   ```
4. `adb devices`로 연결 확인 → Web UI에서 자동 감지됨

> ⚠️ PC와 폰이 **동일한 WiFi**에 연결되어 있어야 합니다.

---

## 개발자용 CLI 실행

```bash
# Appium 서버 먼저 시작 (별도 터미널)
appium --relaxed-security

# 실행
python main.py --config config/spatch-ex.yaml
```

설정 파일 생성:
```bash
cp config/run.example.yaml config/my-app.yaml
# app_package, app_activity, udid, selectors 수정
```

---

## Notes on selectors
This project prefers **text/accessibility-id** selectors (no resource-id needed).
Selectors support `str | list[str]` — list means "try each in order":
```yaml
symptom_add_text: ["증상 추가", "Add Symptom"]  # Korean first, English fallback
```

## Output structure
```
output/<YYYYMMDD_HHMMSS>/
  events.jsonl          # machine-readable event log
  report.html           # human-readable HTML summary
  inject_before_*.png   # screenshots
  inject_logcat_*.txt   # adb logcat snapshots
```

---

If you want, we can extend to multi-node (miniPC/RPi) orchestration and Slack notifications.
