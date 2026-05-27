# Changelog — S-Patch Ex Automation

## 2026-05-26

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
