============================================================
  SpatchEx UAT Tool  —  Team Dashboard Guide
============================================================

The Team Dashboard lets you monitor multiple testers' runs
from a single browser on your network.

------------------------------------------------------------
  DO I NEED THIS?
------------------------------------------------------------

  NO  — if you are testing alone or not on a shared network.
        Leave the Hub URL field empty. The test runs normally.

  YES — if a team lead or QA coordinator wants to watch
        all testers' progress on one screen.

------------------------------------------------------------
  HOW IT WORKS
------------------------------------------------------------

  DASHBOARD MACHINE  (the one everyone watches)
  ─────────────────
  1. Run  run.bat  (Windows) or  run.command  (Mac).
  2. Find out its local IP address:
       Windows: open Command Prompt → type  ipconfig
       Mac:     open Terminal → type  ifconfig | grep inet
  3. Keep the run.bat / run.command window open.
  4. Open the team view in a browser:
       http://<dashboard-IP>:5001/team
     Example:  http://192.168.0.4:5001/team

  TESTER MACHINE  (each person running a test)
  ──────────────
  1. Run  run.bat  or  run.command  on your own machine.
  2. In the browser that opens, fill in:
       Hub URL:      http://192.168.0.4:5001
                     (use the dashboard machine's IP)
       Tester Name:  your name or ID
  3. Click  Start Test  as normal.

  Your run data will now appear on the dashboard machine
  at  http://192.168.0.4:5001/team

------------------------------------------------------------
  IMPORTANT NOTES
------------------------------------------------------------

• Both machines must be on the same local network (Wi-Fi or
  LAN). This will NOT work over the internet.

• The dashboard machine must be running the web UI before
  testers start their tests.

• If Hub URL is left empty, the test still runs normally
  — only the remote reporting is skipped.

• Each tester should use a unique Tester Name so their
  cards appear separately on the dashboard.

------------------------------------------------------------
  WHAT THE DASHBOARD SHOWS
------------------------------------------------------------

  /team             — live cards for each active tester
                      (status, device, last event)
  /failures         — failure screenshots + logs
  /timeline         — event timeline across all runs

============================================================
