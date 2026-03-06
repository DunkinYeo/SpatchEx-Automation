==============================================================
  SpatchEx Automation -- Quick Start Guide
  For CS / UAT Staff
==============================================================

BEFORE YOU START
----------------
1. Connect your Android phone to this computer using a USB cable.

2. On your phone, go to:
   Settings > About Phone > tap "Build Number" 7 times
   (This enables Developer Options)

3. Go to:
   Settings > Developer Options > turn ON "USB Debugging"

4. A popup will appear on your phone asking:
   "Allow USB debugging from this computer?"
   Tap ALLOW (or "Always allow from this computer").

5. Your phone screen should stay ON while the test runs.
   You do not need to interact with the phone manually.


HOW TO START THE TEST
---------------------
1. Double-click  start.bat  (or  run.bat)

2. A black window will open -- this is normal.
   Wait for it to finish checking your setup (about 30 seconds).

3. Your browser will open automatically at:
   http://127.0.0.1:5001

4. In the browser:
   - Enter your name
   - Check that your device appears in the device list
   - Click "Start Test"

5. Leave the black window and browser open for the full test.
   Do NOT close the black window -- it runs the test in the background.


HOW TO STOP THE TEST
--------------------
Option A: Double-click  STOP.bat  -- stops all services cleanly.

Option B: Close the black command window with the X button.
          Then close the Appium window too (also black).


==============================================================
TROUBLESHOOTING
==============================================================

PROBLEM: Browser does not open automatically
  > Open your browser manually and go to: http://127.0.0.1:5001

PROBLEM: Device not detected (no device shown in browser UI)
  > Make sure USB cable is properly connected
  > Check phone screen for the "Allow USB Debugging" popup and tap Allow
  > Try a different USB cable or port

PROBLEM: Black window closes immediately with an error
  > Read the error message before it closes
  > Common fix: reconnect USB cable and run start.bat again

PROBLEM: "web\app.py not found" error
  > You may have run start.bat from inside a subfolder
  > Move start.bat back to the main SpatchEx-Automation folder

PROBLEM: Appium window shows errors
  > Close all windows and run start.bat again
  > If the problem continues, contact your IT admin

PROBLEM: Test shows "FAILED" in the browser
  > Check that the phone is still connected (not locked/sleeping)
  > Tap "Stop" and then "Start Test" again in the browser


==============================================================
NEED HELP?
==============================================================
Contact your IT admin or developer for assistance.
Do NOT edit any files other than config.yaml.

==============================================================
