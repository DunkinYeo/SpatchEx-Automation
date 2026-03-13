============================================================
  SpatchEx Automation (Mac)
============================================================

This tool is designed to automatically input symptoms during
S-Patch Ex app testing.

It helps automate long-running tests by periodically adding
symptoms to the S-Patch Ex application.


------------------------------------------------------------
  1. Installation
------------------------------------------------------------

  Run install.command

  Double-click install.command in Finder.

  The installer will automatically prepare the following:

    - Homebrew (if needed)
    - Python 3.10+
    - Node.js / npm
    - Android platform-tools (adb)
    - Appium
    - Appium UiAutomator2 driver
    - Python virtual environment (.venv)
    - Python dependencies

  First-time installation may take 3-5 minutes.


------------------------------------------------------------
  2. Running the Program
------------------------------------------------------------

  After installation completes, run run.command.

  Double-click run.command in Finder.

  The script will:

    - Activate Python environment
    - Detect adb / Android SDK
    - Start the Appium server
    - Launch the Web UI

  Your browser will automatically open:

    http://127.0.0.1:5001


------------------------------------------------------------
  3. Starting a Test
------------------------------------------------------------

  From the web interface configure:

    - Device
    - Test Name
    - Tester Name
    - Test Duration
    - Symptom Interval
    - Symptoms

  Then click "Start Test".

  The automation will begin controlling the device.


------------------------------------------------------------
  4. Requirements
------------------------------------------------------------

  - Android device must be connected via USB.
  - USB Debugging must be enabled on the device.
  - Internet connection is required during installation.


------------------------------------------------------------
  5. Notes
------------------------------------------------------------

  - Some steps may prompt for confirmation during installation.
  - Homebrew installation may require your Mac password.
  - Appium and driver installation may take a few minutes.


------------------------------------------------------------
  6. Troubleshooting
------------------------------------------------------------

  If installation fails:

  1) Check your internet connection.

  2) Run the following in Terminal, then try again:

       chmod +x install.command
       chmod +x run.command

  3) Run install.command again.


------------------------------------------------------------
  Support
------------------------------------------------------------

  If you encounter issues, please contact Dunkin.

============================================================
