============================================================
  SpatchEx UAT Tool  —  Windows Setup & Usage Guide
============================================================

This tool automates symptom input during long-running
S-Patch EX ECG tests. No coding knowledge required.


------------------------------------------------------------
  BEFORE YOU START — Unblock the ZIP File
------------------------------------------------------------

If you received this ZIP from email or a shared drive,
Windows may have blocked it for security reasons.

How to unblock:
  1) Right-click the ZIP file
  2) Select Properties
  3) At the bottom, check "Unblock" if it appears
  4) Click OK, then extract the ZIP

  If you skip this step, install.bat may show a
  "Windows protected your PC" error.


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
     Python, Node.js, ADB, Appium, and package installation will proceed automatically.

  Note: First-time setup takes 5–10 minutes.
  Note: If the CMD window appears stuck, press Enter once.


------------------------------------------------------------
  2. RUNNING A TEST
------------------------------------------------------------

  1) Open S-Patch EX and confirm ECG measurement is running.

  2) Double-click  run.bat
     A browser window opens automatically.
     If not, open manually:  http://127.0.0.1:5001

  3) In the browser, fill in:
     - Device       : Select your connected device
     - Test Name    : Enter a name for this test run
     - Tester Name  : Enter your name
     - Team Hub URL : Enter if remote monitoring is needed (optional)
     - Duration     : Total test length
     - Interval     : How often symptoms are injected
     - Symptoms     : Select symptoms to inject automatically

  4) Click  Start Test

  5) Keep the run.bat window open for the entire test.


------------------------------------------------------------
  3. STOPPING A TEST
------------------------------------------------------------

  Double-click  STOP.bat
    — or —
  Click  Stop Test  in the browser.


------------------------------------------------------------
  4. USB / WiFi CONNECTION
------------------------------------------------------------

  First-time use: USB connection is required.
  After the device has been prepared for ADB over WiFi on the same machine,
  it can also be used wirelessly.

  If a device has been previously set up for WiFi ADB,
  set the environment variable SPATCH_DEVICE_IP and
  run.bat will attempt a WiFi connection automatically.

  How to set SPATCH_DEVICE_IP:
    System Properties → Environment Variables → New
    Variable name:  SPATCH_DEVICE_IP
    Variable value: device IP address (e.g. 192.168.0.41)

  Note: If WiFi connection fails, the program continues normally.
  Note: No separate WiFi launcher is needed.


------------------------------------------------------------
  5. TROUBLESHOOTING
------------------------------------------------------------

  Phone not detected?
    - Unplug and replug the USB cable
    - Re-enable USB Debugging on the phone
    - Tap "Allow" on the phone if prompted

  install.bat errors?
    - Re-run install.bat — most issues resolve on retry
    - If you see "Windows protected your PC":
      click More info → Run anyway

  Script appears stuck?
    - Press Enter once or twice

  Browser doesn't open?
    - Go to:  http://127.0.0.1:5001  manually

  Test keeps failing?
    - Check the Failures tab in the browser for screenshots
      and error details


------------------------------------------------------------
  6. TEAM DASHBOARD  (optional)
------------------------------------------------------------

  To monitor test progress from another machine,
  see  README_TEAM_DASHBOARD_EN.txt

============================================================
