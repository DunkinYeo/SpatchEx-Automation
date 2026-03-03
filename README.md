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
   Python · Node.js · ADB · Appium 자동 설치 (10~20분 소요)
   *(중간에 설치가 안 된다는 오류가 나오면 화면의 안내 따라 수동 설치 후 재실행)*

### Mac

1. ZIP 압축 해제

2. 터미널에서 아래 명령 실행 (Gatekeeper 차단 해제):
   ```bash
   xattr -cr ~/Downloads/SpatchEx-Automation
   ```

3. **`run.command`** 더블클릭
   Python · Node.js · ADB · Appium 자동 설치 (10~20분 소요)

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

## 개발자용 CLI 실행

```bash
python main.py --config config/spatch-ex.yaml
```

설정 파일 생성:
```bash
cp config/run.example.yaml config/my-app.yaml
```
