============================================================
  SpatchEx UAT Tool  —  Mac Guide
============================================================

Note: Mac support is currently under active validation.
If you run into issues not covered here, please contact
the engineering team.

------------------------------------------------------------
  FIRST-TIME SETUP  (run once)
------------------------------------------------------------

1. Connect your Android phone via USB cable.

2. Enable USB Debugging on the phone:
     Settings → About Phone → tap Build Number 7 times
     Settings → Developer Options → enable USB Debugging

3. When prompted on the phone, tap "Allow" for USB Debugging.

4. Open Terminal and run:
     bash install.sh
   Or double-click  install.command

   This installs Homebrew, Node.js, ADB, Appium, and
   Python packages automatically.

------------------------------------------------------------
  STARTING A TEST
------------------------------------------------------------

1. Make sure the phone is connected and the S-Patch EX app
   is open and measuring.

2. Double-click  run.command
   Or in Terminal:  bash run.command

   A browser window opens automatically at:
   http://127.0.0.1:5001

3. In the browser:
   - Select your device
   - Click  Start Test

------------------------------------------------------------
  STOPPING A TEST
------------------------------------------------------------

Double-click  STOP.command
  — or —
In the browser, click  Stop Test

------------------------------------------------------------
  IF SOMETHING GOES WRONG
------------------------------------------------------------

• Phone not detected?
    - Unplug and replug USB
    - In Terminal:  adb devices
    - Tap "Allow" on the phone if prompted

• Appium fails to start?
    - Re-run  install.sh  or  install.command

• Browser does not open?
    - Manually go to:  http://127.0.0.1:5001

------------------------------------------------------------
  TEAM DASHBOARD
------------------------------------------------------------

See  README_TEAM_DASHBOARD.txt  to monitor from another
machine on the same network.

============================================================
