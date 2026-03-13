============================================================
  SpatchEx UAT 도구  —  Mac 설치 및 사용 가이드
============================================================


------------------------------------------------------------
  install.command 가 실제로 하는 일
------------------------------------------------------------

  install.command 는 필수 도구를 확인하고:

  자동 설치 (별도 조작 불필요):
    - Appium          (npm 사용, 미설치 시)
    - UiAutomator2    (appium driver 사용, 미설치 시)
    - Python 패키지   (pip, .venv 에 설치)

  Homebrew 가 있을 경우 자동 설치:
    - Node.js   (brew install node)
    - ADB       (brew install android-platform-tools)
    - Python    (brew install python@3.12)

  Homebrew 가 없을 경우 수동 설치 필요:
    - Python 3.10+   https://www.python.org/downloads/
    - Node.js        https://nodejs.org/
    - ADB            brew install android-platform-tools
                     (또는 Android Studio)

  클린 Mac 환경에서는 Homebrew 사용을 강력히 권장합니다.
  Homebrew 가 없다면 먼저 설치하세요:

    /bin/bash -c "$(curl -fsSL https://brew.sh/install.sh)"

  그 후 install.command 를 실행하면 나머지는 자동 처리됩니다.


------------------------------------------------------------
  1. 최초 1회 설치
------------------------------------------------------------

  1) Homebrew 설치 (없는 경우에만):

       /bin/bash -c "$(curl -fsSL https://brew.sh/install.sh)"

     이미 설치되어 있다면 이 단계는 건너뜁니다.

  2) 안드로이드 스마트폰을 USB 케이블로 Mac 에 연결합니다.

  3) 스마트폰에서 USB 디버깅을 활성화합니다:
       설정 → 휴대전화 정보 → 소프트웨어 정보
       → [빌드 번호]를 7번 빠르게 탭
       설정 → 개발자 옵션 → USB 디버깅 ON

  4) 스마트폰에 "USB 디버깅을 허용하시겠습니까?" 팝업이 뜨면
     [허용]을 탭합니다.

  5) install.command 를 더블클릭합니다.

     설치 프로그램이 다음을 자동으로 처리합니다:
     - Python, Node.js, ADB 확인
     - 누락된 도구를 Homebrew 로 자동 설치
     - Appium 및 UiAutomator2 드라이버 설치
     - Python 가상환경 설정

  ※ macOS 보안 설정으로 인해 "개발자를 확인할 수 없습니다"
    메시지가 뜰 수 있습니다. 이 경우:
    - Finder 에서 파일을 오른쪽 클릭 → [열기] 선택
    - 또는: 시스템 설정 → 개인 정보 보호 및 보안
      → 하단의 [확인 없이 열기] 클릭


------------------------------------------------------------
  2. 테스트 시작
------------------------------------------------------------

  1) S-Patch EX 앱을 켜고 ECG 측정이 진행 중인지 확인합니다.

  2) run.command 를 더블클릭합니다.
     잠시 후 브라우저가 자동으로 열립니다:
     http://127.0.0.1:5001

  3) 브라우저에서:
     - 연결된 디바이스를 선택합니다.
     - [Start Test] 버튼을 클릭합니다.


------------------------------------------------------------
  3. 테스트 중지
------------------------------------------------------------

  STOP.command 를 더블클릭합니다.
    — 또는 —
  브라우저에서 [Stop Test] 버튼을 클릭하세요.
    — 또는 —
  run.command 터미널 창에서 Ctrl+C 를 누르세요.


------------------------------------------------------------
  4. 문제 해결
------------------------------------------------------------

  install.command 에서 "Python not found" 오류:
    - 터미널을 열고 실행: brew install python@3.12
    - 이후 install.command 재실행

  install.command 에서 "Node.js not found" 오류:
    - 터미널을 열고 실행: brew install node
    - 이후 install.command 재실행

  install.command 에서 "ADB not found" 오류:
    - 터미널을 열고 실행: brew install android-platform-tools
    - 이후 install.command 재실행

  기기가 인식되지 않는 경우:
    - USB 케이블을 뽑았다가 다시 꽂아 보세요.
    - 터미널에서 확인: adb devices
    - 스마트폰 화면에 "허용" 팝업이 있으면 탭하세요.

  브라우저가 열리지 않는 경우:
    - 수동으로 접속하세요: http://127.0.0.1:5001

  Appium 실행 오류:
    - install.command 를 다시 실행하세요.


------------------------------------------------------------
  5. 팀 대시보드 (선택 사항)
------------------------------------------------------------

  다른 PC 에서 테스트를 모니터링하려면
  README_TEAM_DASHBOARD_KR.txt 를 참고하세요.

============================================================
