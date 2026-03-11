============================================================
  SpatchEx UAT Tool  —  Mac Setup & Usage Guide
============================================================

Note: Mac support is currently under active validation.
If you run into issues not listed here, contact the team.


------------------------------------------------------------
  1. FIRST-TIME SETUP  (run once)
------------------------------------------------------------

  1) Connect your Android phone to the Mac via USB cable.

  2) Enable USB Debugging on the phone:
       Settings → About Phone → Software Information
       → Tap Build Number 7 times
       Settings → Developer Options → USB Debugging ON

  3) When the phone shows "Allow USB Debugging?" — tap Allow.

  4) Double-click  install.command
     This installs Homebrew, Node.js, ADB, Appium, and
     Python packages automatically.

  Note: macOS may show "cannot verify the developer."
    - Right-click the file in Finder → Open
    - Or: System Settings → Privacy & Security
      → click "Open Anyway" at the bottom


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
    — or —
  Click  Stop Test  in the browser.
    — or —
  Press Ctrl+C in the run.command terminal window.


------------------------------------------------------------
  4. TROUBLESHOOTING
------------------------------------------------------------

  Phone not detected?
    - Unplug and replug the USB cable
    - In Terminal:  adb devices
    - Tap "Allow" on the phone if prompted

  Browser doesn't open?
    - Go to:  http://127.0.0.1:5001  manually

  Appium fails?
    - Re-run  install.command


------------------------------------------------------------
  5. TEAM DASHBOARD  (optional)
------------------------------------------------------------

  To monitor test progress from another machine,
  see  README_TEAM_DASHBOARD_EN.txt

============================================================
