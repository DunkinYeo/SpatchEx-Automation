============================================================
  SpatchEx UAT Tool  —  Team Dashboard Guide
============================================================


------------------------------------------------------------
  DO YOU NEED THIS?
------------------------------------------------------------

  NO — if you are testing alone, or outside the office
       network. Leave the Hub URL field empty.
       The test runs normally without it.

  YES — if a QA lead or coordinator wants to watch all
        testers' progress on a single screen.


------------------------------------------------------------
  HOW IT WORKS
------------------------------------------------------------

  DASHBOARD MACHINE  (the shared monitoring screen)
  ─────────────────
  1. Run  run.bat  (Windows) or  run.command  (Mac).

  2. Find its local IP address:
       Windows: open Command Prompt → type  ipconfig
       Mac:     open Terminal → type  ifconfig | grep "inet "

  3. Keep the run.bat / run.command window open.

  4. Open the team view in any browser:
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

  Your run data appears on the dashboard machine
  at  http://192.168.0.4:5001/team


------------------------------------------------------------
  IMPORTANT NOTES
------------------------------------------------------------

  · Both machines must be on the same Wi-Fi or office LAN.
    This will NOT work over the internet.

  · The dashboard machine must be running run.bat /
    run.command BEFORE testers start their tests.

  · Each tester should use a unique name so their cards
    appear separately on the dashboard.

  · If Hub URL is left empty, the test still runs normally.
    Only remote reporting is skipped.


------------------------------------------------------------
  WHAT THE DASHBOARD SHOWS
------------------------------------------------------------

  /team       — live cards per tester (status, device, last event)
  /failures   — failure screenshots + error logs
  /timeline   — event timeline across all runs

============================================================
