============================================================
  SpatchEx UAT Tool  —  Mac Setup & Usage Guide
============================================================


------------------------------------------------------------
  WHAT install.command DOES AND DOES NOT DO
------------------------------------------------------------

  install.command checks for required tools and:

  AUTO-INSTALLS (no action needed from you):
    - Appium          (via npm, if not found)
    - UiAutomator2    (via appium driver, if not found)
    - Python packages (via pip into .venv)

  AUTO-INSTALLS IF HOMEBREW IS PRESENT:
    - Node.js   (brew install node)
    - ADB       (brew install android-platform-tools)
    - Python    (brew install python@3.12)

  REQUIRES MANUAL INSTALL IF HOMEBREW IS NOT PRESENT:
    - Python 3.10+   https://www.python.org/downloads/
    - Node.js        https://nodejs.org/
    - ADB            brew install android-platform-tools
                     (or Android Studio)

  Homebrew is strongly recommended for a clean Mac.
  Install Homebrew first if you do not already have it:

    /bin/bash -c "$(curl -fsSL https://brew.sh/install.sh)"

  Then run install.command — it will handle the rest.


------------------------------------------------------------
  1. FIRST-TIME SETUP  (run once)
------------------------------------------------------------

  1) Install Homebrew if not already installed:

       /bin/bash -c "$(curl -fsSL https://brew.sh/install.sh)"

     If Homebrew is already installed, skip this step.

  2) Connect your Android phone via USB cable.

  3) Enable USB Debugging on the phone:
       Settings -> About Phone -> Software Information
       -> Tap Build Number 7 times
       Settings -> Developer Options -> USB Debugging ON

  4) When the phone shows "Allow USB Debugging?" -- tap Allow.

  5) Double-click  install.command

     The installer will:
     - Check for Python, Node.js, ADB
     - Auto-install missing tools via Homebrew
     - Install Appium and UiAutomator2 driver
     - Set up the Python virtual environment

  Note: macOS may show "cannot verify the developer."
    - Right-click the file in Finder -> Open
    - Or: System Settings -> Privacy & Security
      -> click "Open Anyway" at the bottom


------------------------------------------------------------
  2. STARTING A TEST
------------------------------------------------------------

  1) Open S-Patch EX and confirm ECG measurement is running.

  2) Double-click  run.command
     A browser window opens automatically:
     http://127.0.0.1:5001

  3) In the browser:
     - Select your connected device
     - Click  Start Test


------------------------------------------------------------
  3. STOPPING A TEST
------------------------------------------------------------

  Double-click  STOP.command
    -- or --
  Click  Stop Test  in the browser.
    -- or --
  Press Ctrl+C in the run.command terminal window.


------------------------------------------------------------
  4. TROUBLESHOOTING
------------------------------------------------------------

  install.command fails with "Python not found":
    - Open Terminal and run: brew install python@3.12
    - Then re-run install.command

  install.command fails with "Node.js not found":
    - Open Terminal and run: brew install node
    - Then re-run install.command

  install.command fails with "ADB not found":
    - Open Terminal and run: brew install android-platform-tools
    - Then re-run install.command

  Phone not detected when running run.command?
    - Unplug and replug the USB cable
    - In Terminal: adb devices
    - Tap "Allow" on the phone if prompted

  Browser doesn't open?
    - Go to: http://127.0.0.1:5001  manually

  Appium fails?
    - Re-run install.command


------------------------------------------------------------
  5. TEAM DASHBOARD  (optional)
------------------------------------------------------------

  To monitor test progress from another machine,
  see  README_TEAM_DASHBOARD_EN.txt

============================================================
