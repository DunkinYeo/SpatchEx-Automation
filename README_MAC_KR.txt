SpatchEx Automation (Mac)

이 프로그램은 S-Patch Ex 앱 테스트 중
증상(Symptom)을 일정 주기로 자동 입력하기 위한 테스트 자동화 도구입니다.

장시간 테스트 시 사람이 직접 증상을 반복 입력해야 하는 작업을 자동화하여
테스트를 보다 안정적으로 수행할 수 있도록 도와줍니다.


────────────────────────────────
1. 설치 방법
────────────────────────────────

1️⃣ install.command 실행

Finder에서 install.command 파일을 더블 클릭하여 실행합니다.

설치 과정에서 다음 항목들이 자동으로 준비됩니다.

• Homebrew 확인 및 설치
• Python 3.10+
• Node.js / npm
• Android platform-tools (adb)
• Appium
• Appium UiAutomator2 driver
• Python 가상환경 (.venv)
• Python 패키지 설치


⚠ 처음 실행 시 설치 과정이 3~5분 정도 걸릴 수 있습니다.



────────────────────────────────
2. 프로그램 실행
────────────────────────────────

설치가 완료되면 run.command 를 실행합니다.

Finder에서 run.command 파일을 더블 클릭하면 다음 작업이 자동으로 수행됩니다.

• Python 환경 활성화
• adb(Android SDK) 확인
• Appium 서버 실행
• Web UI 실행

브라우저가 자동으로 열립니다.

주소:

http://127.0.0.1:5001



────────────────────────────────
3. 테스트 시작 방법
────────────────────────────────

웹 화면에서 아래 항목을 설정 후 테스트를 시작합니다.

• Device (연결된 Android 기기)
• Test Name
• Tester Name
• Test Duration
• Symptom Interval
• Symptoms (자동 입력할 증상)

Start Test 버튼을 누르면 자동 테스트가 시작됩니다.



────────────────────────────────
4. 필수 조건
────────────────────────────────

• Android 기기가 USB로 Mac에 연결되어 있어야 합니다.
• Android 기기에서 "USB Debugging"이 활성화되어 있어야 합니다.
• 인터넷 연결이 필요합니다 (설치 시).



────────────────────────────────
5. 자주 발생하는 문제
────────────────────────────────

1️⃣ 기기가 보이지 않는 경우

휴대폰에서 USB Debugging이 켜져 있는지 확인해주세요.

터미널에서 아래 명령어로 확인할 수 있습니다.

adb devices

기기 목록에 device 상태로 표시되어야 합니다.



2️⃣ install.command 실행이 안 되는 경우

아래 명령어 실행 후 다시 시도하세요.

chmod +x install.command
chmod +x run.command



3️⃣ run.command 실행 후 브라우저가 열리지 않는 경우

아래 주소를 직접 브라우저에서 열어주세요.

http://127.0.0.1:5001



4️⃣ 테스트 시작 후 반응이 없는 경우

휴대폰 화면에 USB Debugging 허용 팝업이 나타났을 수 있습니다.

Allow 를 눌러주세요.



5️⃣ 첫 실행 시 시간이 오래 걸리는 경우

첫 실행 시 다음 항목들이 설치됩니다.

• Appium
• UiAutomator2 driver
• Python packages

설치 과정에서 몇 분 정도 시간이 걸릴 수 있습니다.



────────────────────────────────
문의
────────────────────────────────

문제가 발생할 경우 Dunkin에게 문의해주세요.
