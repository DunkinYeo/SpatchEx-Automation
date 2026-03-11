============================================================
  SpatchEx UAT Tool  —  Windows Setup & Usage Guide
============================================================

This tool automates long-term ECG symptom logging for
S-Patch EX app testing. No coding knowledge required.


------------------------------------------------------------
  BEFORE YOU START — Unblock the ZIP File
------------------------------------------------------------

If you received this ZIP from email or a shared drive,
Windows may have blocked it for security reasons.

How to unblock:
  1) Right-click the ZIP file
  2) Select Properties
  3) At the bottom, if you see "This file came from another
     computer..." with an Unblock checkbox — check it
  4) Click OK, then extract the ZIP

  If you skip this step, you may see a "Windows protected
  your PC" error when running install.bat.


------------------------------------------------------------
  1. FIRST-TIME SETUP  (run once)
------------------------------------------------------------

  1) Connect your Android phone to the PC via USB cable.

  2) Enable USB Debugging on the phone:
       Settings → About Phone → Software Information
       → Tap Build Number 7 times
       Settings → Developer Options → USB Debugging ON

  3) When the phone shows "Allow USB Debugging?" — tap Allow.

  4) Double-click  install.bat
     This installs Python, Node.js, ADB, Appium, and
     Python packages automatically.
     (First run takes 5–10 minutes.)

  Tip: If the CMD window appears to hang with no visible
  progress, press Enter once or twice. The install is
  likely still running in the background.


------------------------------------------------------------
  2. STARTING A TEST
------------------------------------------------------------

  1) Open S-Patch EX and confirm ECG measurement is running.

  2) Double-click  run.bat
     A browser window opens automatically.

  3) In the browser:
     - Select your connected device from the dropdown
     - Enter a run name (optional)
     - Click  Start Test

  4) Keep the run.bat window open during the entire test.


------------------------------------------------------------
  3. STOPPING A TEST
------------------------------------------------------------

  Double-click  STOP.bat
    — or —
  Click  Stop Test  in the browser.


------------------------------------------------------------
  4. TROUBLESHOOTING
------------------------------------------------------------

  Phone not detected?
    - Unplug and replug the USB cable
    - Re-enable USB Debugging
    - Tap "Allow" on the phone if prompted

  install.bat errors?
    - Re-run  install.bat  — most issues resolve on retry

  Browser doesn't open?
    - Go to:  http://127.0.0.1:5001  manually

  Test keeps failing?
    - Open the Failures tab in the browser for screenshots
      and error details


------------------------------------------------------------
  5. TEAM DASHBOARD  (optional)
------------------------------------------------------------

  To monitor test progress from another machine,
  see  README_TEAM_DASHBOARD_EN.txt

============================================================
