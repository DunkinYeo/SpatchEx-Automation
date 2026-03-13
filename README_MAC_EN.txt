SpatchEx Automation (Mac)

This tool automates symptom input during S-Patch Ex app testing.

It periodically adds symptoms to the app during long-running tests,
helping testers avoid manual repetitive input.



────────────────────────────────
1. Installation
────────────────────────────────

Run install.command.

Double-click install.command in Finder.

The installer will automatically prepare the following:

• Homebrew (if needed)
• Python 3.10+
• Node.js / npm
• Android platform-tools (adb)
• Appium
• Appium UiAutomator2 driver
• Python virtual environment (.venv)
• Python dependencies


First-time installation may take several minutes.



────────────────────────────────
2. Running the Program
────────────────────────────────

After installation completes, run run.command.

Double-click run.command in Finder.

The script will:

• Activate Python environment
• Detect Android SDK / adb
• Start the Appium server
• Launch the Web UI

Your browser will automatically open:

http://127.0.0.1:5001



────────────────────────────────
3. Starting a Test
────────────────────────────────

From the web interface configure:

• Device
• Test Name
• Tester Name
• Test Duration
• Symptom Interval
• Symptoms

Then click "Start Test".

The automation will begin controlling the device.



────────────────────────────────
4. Requirements
────────────────────────────────

• Android device must be connected via USB.
• USB Debugging must be enabled on the device.
• Internet connection is required during installation.



────────────────────────────────
5. Common Issues
────────────────────────────────

1️⃣ Device not detected

Check that USB Debugging is enabled.

You can verify with:

adb devices



2️⃣ install.command does not run

Try:

chmod +x install.command
chmod +x run.command



3️⃣ Browser does not open

Open manually:

http://127.0.0.1:5001



4️⃣ Test does not start

Check if the phone shows a USB debugging authorization popup.



5️⃣ First run is slow

The first run installs:

• Appium
• UiAutomator2 driver
• Python packages



────────────────────────────────
Support
────────────────────────────────

If you encounter issues, please contact Dunkin.
