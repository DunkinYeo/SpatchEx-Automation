============================================================
  SpatchEx UAT Tool  --  WiFi Device Connection Guide
============================================================

This guide explains how to run SpatchEx over a WiFi
connection instead of a USB cable.

Once connected over WiFi, all features work identically
to the USB workflow.


------------------------------------------------------------
  WHEN TO USE THIS
------------------------------------------------------------

  Use WiFi mode when:
  - A USB cable is unavailable or inconvenient
  - The device needs to be worn freely during the test
  - You want to reduce cable clutter

  USB mode (run.bat) is still available and unchanged.


------------------------------------------------------------
  REQUIREMENTS
------------------------------------------------------------

  - Android device and PC must be on the SAME Wi-Fi network
  - USB Debugging must be enabled on the device
  - Android 11+: Wireless Debugging can be used directly
  - Android 10 and below: USB required for initial setup


------------------------------------------------------------
  ONE-TIME SETUP  (Android 10 and below)
------------------------------------------------------------

  Step 1 -- Connect the phone via USB
    Plug the Android phone into this PC via USB cable.

  Step 2 -- Enable ADB over TCP/IP
    Open a Command Prompt and run:

      adb tcpip 5555

    You will see: "restarting in TCP mode port: 5555"

  Step 3 -- Note the phone's IP address
    On the phone:
      Settings -> About Phone -> Status -> IP Address
      (or Settings -> Wi-Fi -> tap your network)

  Step 4 -- Unplug the USB cable
    You can now disconnect the USB cable.

  Step 5 -- Connect via WiFi
    Run:

      adb connect 192.168.0.50:5555

    (Replace with your phone's actual IP address)

  This setup is only needed once per device reboot.
  After reboot, repeat from Step 2.


------------------------------------------------------------
  ONE-TIME SETUP  (Android 11+, Wireless Debugging)
------------------------------------------------------------

  On the phone:
    Settings -> Developer Options -> Wireless Debugging -> ON
    Tap "Pair device with pairing code"
    Note the IP address and port shown on screen

  On the PC:
    adb pair <ip>:<pairing-port>
    (Enter the 6-digit code shown on the phone)

    Then connect:
    adb connect <ip>:5555


------------------------------------------------------------
  RUNNING THE TEST OVER WIFI
------------------------------------------------------------

  Double-click  run_wifi.bat

  1. The script will prompt for Device IP:Port:

       Enter Android device IP:Port
       Example: 192.168.0.50:5555

  2. Enter your device's IP and port (default: 5555).

  3. The script will connect and verify the device,
     then automatically launch the test environment
     (identical to run.bat).

  4. The browser opens automatically.
     Proceed exactly as with the USB workflow.


------------------------------------------------------------
  WEB UI -- WIFI MODE  (optional)
------------------------------------------------------------

  The web UI also supports WiFi connection directly:

  1. Open the browser (http://127.0.0.1:5001)
  2. Under "Device Connection", select "WiFi ADB"
  3. Enter Device Address: 192.168.0.50:5555
  4. Click Start Test

  The system will run  adb connect  automatically
  before starting the test.


------------------------------------------------------------
  TROUBLESHOOTING
------------------------------------------------------------

  "Device not found" or "unauthorized"?
    - Make sure the phone is on the same Wi-Fi network
    - Re-run  adb tcpip 5555  while USB is connected
    - Check the IP address on the phone again
    - Tap "Allow" on the phone if a dialog appears

  Connection drops during test?
    - Keep the phone screen on or disable screen timeout
    - Disable Wi-Fi sleep on the device
    - Ensure the phone does not enter airplane mode

  Want to switch back to USB?
    - Simply use run.bat as usual
    - USB mode is fully independent of WiFi mode

============================================================
