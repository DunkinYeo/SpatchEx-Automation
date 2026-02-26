# S-Patch EX 장기 실행 자동화 테스트

24/48/72시간 ECG 측정 중 **증상을 자동으로 주입**해주는 테스트 자동화 툴입니다.

---

## 🚀 시작하기 (3단계)

### 1단계 — 다운로드

아래 링크를 클릭해 ZIP 파일을 다운로드하고 압축을 해제하세요.

**[⬇ 최신 버전 다운로드 (ZIP)](https://github.com/DunkinYeo/SpatchEx-Automation/archive/refs/heads/main.zip)**

### 2단계 — 설치 (최초 1회만)

압축 해제된 폴더에서:

| OS | 실행 파일 | 방법 |
|----|-----------|------|
| **Mac** | `install.command` | 더블클릭 → 팝업에서 "열기" 클릭 |
| **Windows** | `install.bat` | 더블클릭 |

> Python, Node.js, ADB, Appium이 자동으로 설치됩니다. (5~15분 소요)

### 3단계 — 테스트 실행

| OS | 실행 파일 | 결과 |
|----|-----------|------|
| **Mac** | `start.command` | 더블클릭 → 브라우저 자동 오픈 |
| **Windows** | `start.bat` | 더블클릭 → 브라우저 자동 오픈 |

브라우저에서 설정 후 **▶ 테스트 시작** 클릭!

---

## 📱 폰 연결 방법

### USB 케이블 연결 (가장 쉬운 방법)
1. 설정 → 빌드 번호를 **7번** 연속 탭 → "개발자 옵션 활성화" 메시지 확인
2. 설정 → 개발자 옵션 → **USB 디버깅 ON**
3. USB 케이블로 PC에 연결
4. 폰 화면에 팝업 뜨면 **"허용"** 탭

### WiFi 무선 연결 (Android 11+, 케이블 불필요)
1. 설정 → 개발자 옵션 → **무선 디버깅 ON**
2. **"페어링 코드로 기기 페어링"** 탭
3. 터미널(Mac) 또는 명령 프롬프트(Windows)에서:
   ```bash
   adb pair <화면의 IP>:<페어링 포트>   # 코드 입력
   adb connect <화면의 IP>:<디버깅 포트>
   ```
4. Web UI가 자동으로 기기를 감지합니다

> ⚠️ PC와 폰이 **같은 WiFi**에 연결되어 있어야 합니다.

---

## ❓ 자주 묻는 질문

**Q. `install.command`를 더블클릭하면 텍스트 파일로 열려요**
→ 파일에서 우클릭 → "다른 앱으로 열기" → "터미널" 선택

**Q. "개발자를 확인할 수 없음" 팝업이 떠요 (Mac)**
→ 시스템 설정 → 개인 정보 보호 및 보안 → 하단에서 "무관하게 허용" 클릭

**Q. 폰이 웹 UI에서 안 보여요**
→ USB 케이블 재연결 후 폰 화면에서 "허용" 확인

---

## 개발자용 정보

### CLI 직접 실행
```bash
# Appium 서버 먼저 시작 (별도 터미널)
appium --relaxed-security

# 실행
python main.py --config config/spatch-ex.yaml
```

### 설정 파일 구조
```bash
cp config/run.example.yaml config/my-app.yaml
# app_package, app_activity, udid, selectors 수정
```

### 셀렉터 형식
```yaml
# 한/영 모두 지원 — 순서대로 시도
symptom_add_text: ["증상 추가", "Add Symptom"]
```

### 결과 파일 위치
```
output/<YYYYMMDD_HHMMSS>/
  events.jsonl      # 이벤트 로그
  report.html       # HTML 요약 리포트
  *.png             # 스크린샷
  *_logcat.txt      # ADB 로그
```
