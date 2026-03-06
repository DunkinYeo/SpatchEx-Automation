==============================================================
  SpatchEx Automation -- Quick Start Guide
  For CS / UAT Staff
==============================================================

BEFORE YOU START
----------------
1. Connect your Android phone to this computer using a USB cable.
   Use the cable that came with your phone if possible.

2. On your phone:
   a. Go to Settings > About Phone
   b. Tap "Build Number" 7 times in a row
      (You may see "You are now a developer!")
   c. Go back to Settings > Developer Options (new menu)
   d. Turn ON "USB Debugging"

   NOTE: The exact menu location varies by phone brand:
     Samsung:  Settings > About Phone > Software Information > Build Number
     Pixel:    Settings > About Phone > Build Number
     OnePlus:  Settings > About Device > Build Number
     Xiaomi:   Settings > About Phone > MIUI Version

3. A popup will appear on your phone screen:
   "Allow USB debugging from this computer?"
   Tap ALLOW (or "Always allow from this computer" to avoid repeating).

4. Your phone screen should stay ON while the test runs.
   You do not need to touch the phone during the test.


HOW TO START THE TEST
---------------------
1. Double-click  run.bat  (or  start.bat  in the start\ folder)

2. A black window opens -- this is normal.
   Wait while it checks and starts all required services (~30 seconds).

3. Your browser opens automatically at:
   http://127.0.0.1:5001

   If the browser does not open: open it manually and go to that address.

4. In the browser:
   - Type your name
   - Confirm your device appears in the device list
   - Click "Start Test"

5. Leave the black window OPEN during the entire test.
   Do NOT close it -- it keeps the test running.
   You can minimize it.


HOW TO STOP THE TEST
--------------------
Option A (recommended): Double-click  STOP.bat

Option B: Close the black window with the X button.
          Then close the Appium window too (the second black window).


==============================================================
TROUBLESHOOTING
==============================================================

──────────────────────────────────────────────────────────────
PROBLEM: Browser does not open automatically
──────────────────────────────────────────────────────────────
  FIX: Open your browser manually and type:
         http://127.0.0.1:5001
       Press Enter.

  If you see "This site can't be reached" or "Connection refused":
  → The web server has not started yet. Wait 10 more seconds
    and try again.
  → If it still fails, close and re-run run.bat.

──────────────────────────────────────────────────────────────
PROBLEM: "Connection refused" or "This site can't be reached"
──────────────────────────────────────────────────────────────
  CAUSE: The web server failed to start.
  FIX:
  1. Close any open SpatchEx black windows.
  2. Run STOP.bat to clean up.
  3. Wait 5 seconds, then run run.bat again.
  4. If it still fails, contact your IT admin.

──────────────────────────────────────────────────────────────
PROBLEM: My phone is not detected (no device shown in browser)
──────────────────────────────────────────────────────────────
  FIX - Step by step:
  1. Check your phone screen -- is there a popup asking
     "Allow USB debugging"?  Tap ALLOW.

  2. If no popup appeared:
     a. Unplug the USB cable.
     b. Wait 3 seconds.
     c. Plug it back in.
     d. Check the phone screen again for the popup.

  3. If still no device:
     a. Try a different USB cable.
     b. Try a different USB port on this computer.
     c. Make sure USB Debugging is still turned ON
        (Settings > Developer Options > USB Debugging).

  4. Some phones ask you to choose a USB connection mode.
     If prompted, choose "File Transfer" or "MTP" mode.

  IMPORTANT: You can still open the web UI and start the test
  even if the device is not connected yet. Just reconnect
  the phone before clicking "Start Test".

──────────────────────────────────────────────────────────────
PROBLEM: Black window closes immediately or shows an error
──────────────────────────────────────────────────────────────
  FIX:
  1. Read the error message shown in the black window.
  2. Common causes:
     - Phone USB cable was disconnected
     - Antivirus blocked a startup file
     - The ZIP was extracted into a subfolder (run.bat must be
       in the SpatchEx-Automation folder, not a folder inside it)
  3. Try: close everything, reconnect the phone, run run.bat again.
  4. Contact your IT admin if the error keeps happening.

──────────────────────────────────────────────────────────────
PROBLEM: USB debugging popup appeared but tapping ALLOW did nothing
──────────────────────────────────────────────────────────────
  FIX:
  1. Unplug the USB cable and plug it back in.
  2. Look for the popup again.
  3. Tap "Always allow from this computer" this time.
  4. If the popup keeps disappearing before you can tap it,
     unlock your phone screen first (enter PIN/pattern) and
     then reconnect the USB cable.

──────────────────────────────────────────────────────────────
PROBLEM: Appium window shows red errors or closes itself
──────────────────────────────────────────────────────────────
  FIX:
  1. Close all black windows.
  2. Run STOP.bat.
  3. Wait 10 seconds.
  4. Run run.bat again.
  5. If the error repeats, contact your IT admin.

──────────────────────────────────────────────────────────────
PROBLEM: Test shows "FAILED" in the browser
──────────────────────────────────────────────────────────────
  FIX:
  1. Check that your phone screen is on (not locked or sleeping).
  2. Check that the USB cable is still connected.
  3. In the browser, click "Stop", then click "Start Test" again.
  4. If failures repeat, contact your IT admin with the error message.

──────────────────────────────────────────────────────────────
PROBLEM: "web\app.py not found" error
──────────────────────────────────────────────────────────────
  CAUSE: You ran start.bat from inside a subfolder.
  FIX:
  1. Navigate up one level so you can see run.bat at the top.
  2. Double-click run.bat from there (not from inside any folder).


==============================================================
NEED HELP?
==============================================================
Contact your IT admin or developer for assistance.
Provide them with the error message you saw in the black window.

For admins: logs are saved to %TEMP%\spatch_*.log

Do NOT edit any files other than config.yaml.

==============================================================
