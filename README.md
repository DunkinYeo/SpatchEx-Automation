# SpatchEx 장기 실행 테스트 자동화

24/48/72시간 ECG 측정 + 증상 자동 주입 오케스트레이터.
Android (Appium + UiAutomator2) 기반. 비개발자도 ZIP 한 번으로 바로 사용 가능.

---

## 사용 방법 (비개발자용)

### 1단계 — ZIP 받아서 실행

**[⬇ ZIP 다운로드](https://github.com/DunkinYeo/SpatchEx-Automation/archive/refs/heads/main.zip)**

1. ZIP 다운로드 → 압축 해제
2. 폴더 안의 파일 더블클릭:

| OS | 파일 |
|----|------|
| Mac | `run.command` 더블클릭 |
| Windows | `run.bat` 더블클릭 |

> 처음 실행 시 Python·Node.js·ADB·Appium 자동 설치 (5~15분).
> 두 번째 실행부터는 바로 웹 UI가 열립니다.

> **Mac 주의 — Gatekeeper 경고 해제**
>
> 인터넷에서 다운로드한 파일은 macOS가 실행을 막습니다.
>
> **방법 A — 터미널 (가장 확실)**: 압축 해제한 폴더 안에서 터미널 열고 아래 명령 실행 후 더블클릭:
> ```bash
> xattr -cr .
> ```
>
> **방법 B — 시스템 설정**: `run.command` 더블클릭 → 경고창 확인 → **시스템 설정 → 개인 정보 보호 및 보안** → 하단 "보안" 섹션에서 **"확인 없이 열기"** 클릭

---

### 2단계 — 디바이스 연결

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
   adb connect <IP>:<디버깅포트>  # 예: adb connect 192.168.1.5:42135
   ```
4. `adb devices`로 연결 확인 → Web UI에서 자동 감지됨

> ⚠️ PC와 폰이 **동일한 WiFi**에 연결되어 있어야 합니다.

---

### 3단계 — 웹 UI에서 테스트 시작

브라우저가 자동으로 열리면:

| 항목 | 설명 |
|------|------|
| 디바이스 | 연결된 기기 선택 |
| 테스트 이름 | 결과 파일 구분용 (예: Alice_Round1) |
| 측정 시간 | 24h / 48h / 72h |
| 증상 주입 간격 | 4시간마다 등 |
| 증상 선택 | 주입할 증상 체크 |
| **팀 허브 URL** | 담당자가 알려준 주소 입력 (선택) |
| **내 이름** | 허브 대시보드에서 구분할 이름 (선택) |

설정 후 **▶ 테스트 시작** 클릭

---

## 팀 결과 모니터링 (관리자용)

여러 팀원의 테스트 결과를 한 화면에서 실시간으로 확인할 수 있습니다.

### 관리자가 할 일

1. 본인 PC에서 서버 실행: `run.command` (Mac) 또는 `run.bat` (Windows)
2. 브라우저에서 팀 대시보드 열기:
   ```
   http://localhost:5001/team
   ```
3. 본인 PC의 IP 주소를 팀원들에게 알려주기
   (Mac 터미널: `ifconfig | grep "inet " | grep -v 127`)

### 팀원이 할 일

웹 UI 하단 두 칸 입력 후 테스트 시작:
- **팀 허브 URL**: 관리자가 알려준 주소 (예: `http://192.168.0.4:5001`)
- **내 이름**: 대시보드에서 구분할 이름 (예: 김철수)

### 대시보드 화면

```
┌─────────────────────┐  ┌─────────────────────┐
│ 김철수      실행중● │  │ 이영희        완료✓ │
│ Pixel 7             │  │ Galaxy S23          │
│ 증상 주입: 2회      │  │ 증상 주입: 6회      │
│ 마지막: 14:32:05    │  │ 마지막: 15:01:22    │
│ ─ 증상 주입 완료    │  │ ─ 테스트 완료       │
└─────────────────────┘  └─────────────────────┘
```

> ⚠️ 관리자와 팀원이 **같은 WiFi(사내 네트워크)**에 있어야 합니다.
> 허브 URL 미입력 시 테스트는 정상 동작하며 대시보드에만 전송되지 않습니다.

---

## 이미 설치한 경우 — 실행만 하기

| OS | 파일 |
|----|------|
| Mac | `run.command` 또는 `start.sh` |
| Windows | `run.bat` 또는 `start.bat` |

---

## 터미널 한 줄 설치 (터미널에 익숙한 경우)

**Mac:**
```bash
curl -fsSL https://raw.githubusercontent.com/DunkinYeo/SpatchEx-Automation/main/bootstrap.sh | bash
```
**Windows** (PowerShell 관리자):
```powershell
irm https://raw.githubusercontent.com/DunkinYeo/SpatchEx-Automation/main/bootstrap.ps1 | iex
```

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

config에서 허브 연동 설정:
```yaml
hub:
  enabled: true
  url: "http://192.168.0.4:5001"  # 관리자 PC 주소
  tester_name: "김철수"
```

---

## 출력 구조

```
output/<YYYYMMDD_HHMMSS>/
  events.jsonl          # 이벤트 로그 (JSONL)
  summary.html          # HTML 요약
  inject_before_*.png   # 증상 주입 전 스크린샷
  inject_logcat_*.txt   # logcat 스냅샷
```

## Notes on selectors

Selectors support `str | list[str]` — list means "try each in order":
```yaml
symptom_add_text: ["증상 추가", "Add Symptom"]  # Korean first, English fallback
```
