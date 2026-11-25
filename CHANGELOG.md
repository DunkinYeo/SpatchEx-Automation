# Changelog — S-Patch Ex Automation

## 2026-11-25

### Fixed
- 휴대폰 블루투스 on/off를 공용 헬퍼(`src/adb_bluetooth.py`, MA-automation에서 이식)로 일원화 — `svc bluetooth` → `cmd bluetooth_manager` → Appium Settings broadcast(`io.appium.settings`, UiAutomator2와 함께 설치, BLUETOOTH_ADMIN 보유) 순서로 시도하고, 각 단계마다 `bluetooth_on`이 원하는 값이 될 때까지 확인. `bt_disconnect` 워크플로우가 사용.
- Galaxy A32(삼성, Android 11)에서는 `svc bluetooth disable`이 kill(exit 137)되고, `cmd bluetooth_manager`는 "No shell command implementation"을 출력하면서 exit 0을 반환(이제 성공으로 보지 않음), shell에는 BLUETOOTH_ADMIN이 없음 — broadcast만 동작(실기기 확인). 기존 동의 다이얼로그(REQUEST_ENABLE/DISABLE + "허용" 탭) 방식은 adb 방법이 모두 실패한 경우의 마지막 대안으로 유지.

## 2026-09-10

### Fixed
- `bt_disconnect`/`airplane_mode` 워크플로우가 연결 끊김 구간(최대 수십 시간) 동안 한 번의 blind `time.sleep()`만 하던 것을 수정 — 5분마다 Appium 세션을 점검(`ensure_session()`)하는 `sleep_with_heartbeat` 공용 헬퍼(`src/sleep_utils.py`)로 교체. 호스트 sleep/wake나 세션 끊김을 그 구간이 끝날 때까지 몰랐던 문제, 그리고 장시간 무응답으로 `new_command_timeout`에 걸려 세션이 죽는 문제 방지.

## [v1.0.0] — 2026-05-28

### Fixed
- **Host sleep recovery**: injection chain 끊김 방지, web runner에 KeepAwake 추가

## 2026-05-07

### Fixed
- Flask 서버 IPv4+IPv6 dual-stack 바인딩 (`::`) — macOS localhost 접속 문제 수정

## 2026-04-15

### Fixed
- System sleep/pause 이후 injection job이 스킵되던 버그 방지

## 2026-04-10

### Added
- 144h / 168h / 200h duration 옵션 추가

## 2026-03-31

### Chore
- dist/ build output gitignore 추가, 불필요 파일 정리, artifact_manager를 src/로 이동

## 2026-03-26

### Fixed
- symptom picker open wait 20초로 증가, settle time 추가
- strategy 0 wait_for_symptom_success 타임아웃 8초로 조정
- StaleElementReferenceException 처리 (el.location 접근 시)
- Android 10 picker dismiss 방지 — page_source coord tap 방식 사용

## 2026-03-25

### Fixed
- Diary tab을 success signal로 감지, ECG tab으로 복귀 네비게이션
- 심박 picker 요소 좌표 직접 탭 (clickable=false 케이스)
- UiAutomator2 instrumentation crash 감지 및 세션 즉시 재생성
- Windows: WinForms Cursor fallback → user32 mouse_event 교체
- Windows: SetThreadExecutionState 전용 sleep 방지 방식으로 교체

## 2026-03-24

### Fixed
- 한국어/영어 picker content-desc 통합 처리
- symptom picker 요소 탐색 타임아웃 10초로 증가
- 영어/한국어 심박 라벨 단일 WebDriverWait로 처리
- clickable ancestor XPATH로 TouchableOpacity 타겟팅
