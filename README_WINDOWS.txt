============================================================
  SpatchEx UAT Tool  —  Windows Guide
============================================================

This tool automates long-term ECG symptom logging.
No coding knowledge required.

------------------------------------------------------------
  FIRST-TIME SETUP  (run once)
------------------------------------------------------------

1. Connect your Android phone via USB cable.

2. Enable USB Debugging on the phone:
     Settings → About Phone → tap Build Number 7 times
     Settings → Developer Options → enable USB Debugging

3. When prompted on the phone, tap "Allow" for USB Debugging.

4. Double-click  install.bat
   This installs all required software automatically.
   (Takes 5–10 minutes on first run.)

------------------------------------------------------------
  STARTING A TEST
------------------------------------------------------------

1. Make sure the phone is connected and the S-Patch EX app
   is open and measuring.

2. Double-click  run.bat
   A browser window opens automatically.

3. In the browser:
   - Select your device from the dropdown
   - Enter a run name (optional)
   - Click  Start Test

4. Leave the run.bat window open during the entire test.

------------------------------------------------------------
  STOPPING A TEST
------------------------------------------------------------

Double-click  STOP.bat
  — or —
Close the run.bat window, then run STOP.bat to clean up.

------------------------------------------------------------
  IF SOMETHING GOES WRONG
------------------------------------------------------------

• Phone not detected?
    - Unplug and replug the USB cable
    - Re-enable USB Debugging
    - Run  selftest.bat  for automatic diagnosis

• "Appium not found" error?
    - Re-run  install.bat

• Browser does not open?
    - Manually go to:  http://127.0.0.1:5001

• Test keeps failing?
    - Check the Failures tab in the browser for screenshots
      and error details

------------------------------------------------------------
  TEAM DASHBOARD
------------------------------------------------------------

See  README_TEAM_DASHBOARD.txt  if you want to monitor the
test from another machine on the same network.

============================================================
