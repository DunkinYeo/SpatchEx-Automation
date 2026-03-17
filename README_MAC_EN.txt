============================================================
  SpatchEx UAT Tool  —  macOS Setup & Usage Guide
============================================================

This tool automates symptom input during long-running
S-Patch EX ECG tests. No coding knowledge required.


------------------------------------------------------------
  BEFORE YOU START — Allow the scripts to run
------------------------------------------------------------

macOS may block .command files downloaded from the internet.

How to fix:
  Option 1) Right-click the file → select Open
  Option 2) In Terminal, run:
              chmod +x install.command run.command STOP.command
  Option 3) To remove quarantine flag entirely:
              xattr -d com.apple.quarantine install.command run.command STOP.command


------------------------------------------------------------
  1. FIRST-TIME SETUP  (run once)
------------------------------------------------------------

  1) Connect your Android phone to the Mac via USB cable.

  2) Enable USB Debugging on the phone:
       Settings → About Phone → Software Information
       → Tap Build Number 7 times
       Settings → Developer Options → USB Debugging ON

  3) When the phone shows "Allow USB Debugging?" — tap Allow.

  4) Double-click  install.command  in Finder.
     Homebrew, Python, Node.js, ADB, Appium, and package
     installation will proceed automatically.

  Note: First-time setup takes 5–10 minutes.
  Note: If a password is requested, enter your Mac login password
        (nothing will appear on screen as you type — this is normal).


------------------------------------------------------------
  2. RUNNING A TEST
------------------------------------------------------------

  1) Open S-Patch EX and confirm ECG measurement is running.

  2) Double-click  run.command  in Finder.
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

  5) Keep the Terminal window open for the entire test.


------------------------------------------------------------
  3. STOPPING A TEST
------------------------------------------------------------

  Double-click  STOP.command
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
  run.command will attempt a WiFi connection automatically.

  How to set SPATCH_DEVICE_IP (in Terminal):
    export SPATCH_DEVICE_IP=192.168.0.41

  To make it permanent, add the line above to ~/.zshrc
  or ~/.bash_profile.

  Note: This setting applies only to the current Terminal session.
  You may need to set it again when opening a new Terminal window.

  Note: If WiFi connection fails, the program continues normally.
  Note: No separate WiFi launcher is needed.


------------------------------------------------------------
  5. TROUBLESHOOTING
------------------------------------------------------------

  Phone not detected?
    - Unplug and replug the USB cable
    - Re-enable USB Debugging on the phone
    - Tap "Allow" on the phone if prompted

  .command file won't open?
    - Right-click the file → Open
    - Or in Terminal:
        chmod +x install.command run.command STOP.command

  macOS blocked the file?
    - In Terminal:
        xattr -d com.apple.quarantine install.command run.command STOP.command

  Browser doesn't open?
    - Go to:  http://127.0.0.1:5001  manually

  Password prompt during install?
    - Homebrew needs your Mac admin password
    - Type your Mac login password and press Enter
    - Nothing will appear on screen — this is normal

  Test keeps failing?
    - Check the Failures tab in the browser for screenshots
      and error details


------------------------------------------------------------
  6. TEAM DASHBOARD  (optional)
------------------------------------------------------------

  To monitor test progress from another machine,
  see  README_TEAM_DASHBOARD_EN.txt

============================================================
