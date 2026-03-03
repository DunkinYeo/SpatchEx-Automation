# SpatchEx 장기 실행 테스트 자동화

24/48/72시간 ECG 측정 + 증상 자동 주입 오케스트레이터.
**비개발자도 아래 순서만 따라하면 바로 사용 가능합니다.**

---

## 1단계 — 프로그램 설치

**[⬇ ZIP 다운로드](https://github.com/DunkinYeo/SpatchEx-Automation/archive/refs/heads/main.zip)**

### Windows

1. ZIP 파일 우클릭 → **속성(Properties)**
   하단 **"차단 해제(Unblock)"** 체크 → **확인**
   *(이 단계 빠뜨리면 아무 창도 안 뜹니다)*

2. ZIP 압축 해제

3. **`install.bat`** 더블클릭
   Python · Node.js · ADB · Appium 자동 설치 (첫 실행 시 몇 분 소요)
   *"CLOSE and RE-RUN" 메시지가 나오면 창 닫고 다시 실행하세요*

### Mac

1. ZIP 압축 해제

2. 터미널에서 아래 명령 실행 (Gatekeeper 차단 해제):
   ```bash
   xattr -cr ~/Downloads/SpatchEx-Automation
   ```

3. **`run.command`** 더블클릭
   Python · Node.js · ADB · Appium 자동 설치 (첫 실행 시 몇 분 소요)

---

## 2단계 — 안드로이드 기기 연결

> 기기 연결은 **테스트 PC와 기기를 USB 케이블**로 연결하는 방법을 추천합니다.

1. 기기 **개발자 옵션** 활성화
   설정 → 휴대폰 정보 → **빌드 번호 7번 연속 탭**

2. 개발자 옵션 → **USB 디버깅 ON**

3. USB 케이블로 PC에 연결
   기기에 팝업 뜨면 **"항상 허용"** 선택

---

## 3단계 — 테스트 실행

설치 완료 후:

| OS | 파일 |
|----|------|
| Windows | `start.bat` 더블클릭 |
| Mac | `run.command` 더블클릭 |

브라우저가 자동으로 열립니다.
테스트 이름 · 측정 시간 · 증상 주입 간격 입력 후 **▶ 테스트 시작** 클릭.

---

## 팀 결과 모니터링 (관리자용)

여러 팀원의 테스트를 한 화면에서 실시간으로 확인:

1. 관리자 PC에서 서버 실행 (`start.bat` 또는 `run.command`)
2. 브라우저에서 `http://localhost:5001/team` 접속
3. 팀원들에게 관리자 PC의 IP 주소 알려주기
   (Mac 터미널: `ipconfig getifaddr en0` 또는 `en1`)

팀원 웹 UI 하단에서:
- **팀 허브 URL**: `http://<관리자IP>:5001`
- **내 이름**: 대시보드에서 구분할 이름 입력 후 테스트 시작

> 팀원과 관리자가 **같은 WiFi(사내 네트워크)**에 있어야 합니다.

---

## 문제 해결

| 증상 | 해결 방법 |
|------|-----------|
| Windows에서 아무 창도 안 뜸 | ZIP 우클릭 → 속성 → Unblock 체크 후 재시도 |
| "Python을 찾을 수 없다" 오류 | install.bat 재실행 (자동 설치됨) |
| ADB 기기 인식 안 됨 | USB 디버깅 ON 확인, 케이블 재연결 |
| 브라우저가 안 열림 | `http://127.0.0.1:5001` 직접 입력 |

---

## Windows Quick Start (ZIP)

ZIP 파일 기반으로 처음 세팅하는 경우 단계별 체크리스트:

**Step 1 — ZIP 차단 해제 및 압축 해제**
1. ZIP 우클릭 → **속성(Properties)** → 하단 **Unblock** 체크 → 확인
2. ZIP 압축 해제 (바탕화면 등 경로에 한글/공백 없는 곳 권장)

**Step 2 — 설치 실행**
1. `install.bat` 더블클릭
2. Python · Node.js · ADB가 없으면 winget으로 자동 설치됨
3. 각 항목 설치 후 "CLOSE and RE-RUN" 메시지가 나오면 창 닫고 재실행

**Step 3 — Appium 및 UiAutomator2 확인**

`install.bat` 완료 후 CMD 창에서 확인:
```cmd
npx -y appium@3 -v
npx -y appium@3 driver list
```
`uiautomator2 [installed]` 가 보여야 합니다. 없으면:
```cmd
npx -y appium@3 driver install uiautomator2
```

**Step 4 — Appium 서버 시작**

`start.bat` 을 실행하면 웹 UI가 자동으로 열립니다.
CLI로 직접 실행하는 경우:
```cmd
npx -y appium@3 --relaxed-security
```
별도 CMD 창에서 실행 후 유지하세요.

**Step 5 — 테스트 실행**

웹 UI 또는 CLI:
```cmd
.venv\Scripts\activate
python main.py --config config\run.example.yaml
```

---

## 문제 해결

| 증상 | 해결 방법 |
|------|-----------|
| Windows에서 아무 창도 안 뜸 | ZIP 우클릭 → 속성 → Unblock 체크 후 재시도 |
| "Python을 찾을 수 없다" 오류 | install.bat 재실행 (자동 설치됨) |
| ADB 기기 인식 안 됨 | USB 디버깅 ON 확인, 케이블 재연결 |
| 브라우저가 안 열림 | `http://127.0.0.1:5001` 직접 입력 |
| `uiautomator2 [not installed]` | `npx -y appium@3 driver install uiautomator2` 실행 |
| `adb devices` 결과가 비어 있음 | 기기에서 USB 디버깅 ON → 케이블 재연결 → 팝업에서 "항상 허용" |
| "Appium cannot create session" | Appium 서버 실행 중인지 확인, udid·app_package 설정 확인 |
| logcat capture failed on Windows | adb가 PATH에 없는 경우 발생 — 동작에는 영향 없음 (best-effort) |
| Appium 설치 후 바로 종료됨 | 이미 캐시됨 — 정상 동작. `npx -y appium@3 -v` 로 확인 |

---

## 개발자용 CLI 실행

```bash
python main.py --config config/spatch-ex.yaml
```

설정 파일 생성:
```bash
cp config/run.example.yaml config/my-app.yaml
```
