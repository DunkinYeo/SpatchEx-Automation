# Development Log

## [2026-03-05] Task #4: Core Automation Architecture

### Changes

**Scheduler (`src/scheduler.py`)**
- Added `JobResult` dataclass — structured return value for every job with `job_name`, `success`, `start_ts`, `end_ts`, `attempt`, `reason`, `artifact_paths`
- Added `jitter_seconds` support: uniform random offset applied to each trigger time
- Added `quiet_hours` support: suppress injections during overnight/low-activity windows (supports same-day and overnight windows)
- Added `recovery_cfg` parameter threaded through to `_run_with_health_check`
- Rewrote `_attempt_recovery`: now waits `cooldown_seconds` and **re-checks UI health after each step** — returns immediately on first healthy state instead of always running all 3 steps
- `_run_with_health_check` emits `job_start` event and always emits `job_result` event (via `finally`) with full `JobResult` payload

**DeviceManager (`src/device_manager.py`)** — NEW FILE
- Minimal wrapper around a single `AndroidDriver`
- Exposes `.driver` and `.udid` properties
- Designed so a future multi-device implementation can replace the class without changing callers: `for driver in dm` replaces `dm.driver`
- No global singletons

**Main entry point (`src/main.py`)**
- `--dry-run` flag: validates config and prints the schedule/catalog, then exits without connecting to a device — safe for CI / pre-flight checks
- `--once` flag: fires exactly one injection and exits — useful for manual spot-testing
- Replaced direct `AndroidDriver` instantiation with `DeviceManager`
- Passes `jitter_seconds`, `quiet_hours`, `recovery_cfg` from config to `LongRunScheduler`

**Reporter (`src/reporter.py`)**
- HTML summary now includes: PASS/FAIL badge, summary cards (Total Jobs / Passed / Failed), device info section
- Color-coded event rows: red (fail), yellow (warn), green (ok)
- Added `FAIL_EVENTS`, `WARN_EVENTS`, `OK_EVENTS` sets — easy to extend

**Config (`config/run.example.yaml`)**
- Added `run.jitter_seconds` — optional random jitter per injection
- Added `run.quiet_hours` — optional overnight suppression window (commented example)
- Added `recovery` section — `cooldown_seconds_between_steps`
- Added `artifacts` section — `output_dir`, `collect_logcat_on`
- Added `reporting` section — `html_report`, Slack webhook placeholder

**Docs (`docs/CONFIG.md`)** — NEW FILE
- Full config key reference with types, defaults, and descriptions

### Reasoning

1. **JobResult dataclass**: Raw `bool` return from jobs gives no forensic information. A dataclass makes success/failure data introspectable and serialisable to the event log without coupling caller to reporter.

2. **Jitter**: Injections landing on exact hour boundaries (4:00:00, 8:00:00...) look unnatural and can cluster with other scheduled OS events. A small jitter prevents systematic timing artifacts in ECG data.

3. **Quiet hours**: 72 h runs span at least one night cycle. Injecting symptoms at 2 AM when the patient is sleeping produces invalid/useless data. Quiet-hours suppression keeps injections to plausible waking hours.

4. **Recovery recheck per step**: The previous recovery ran all 3 steps regardless of outcome. The new design returns immediately after the first step that restores a healthy UI — minimises disruption to the measurement and is easier to debug (the event log shows exactly which step worked).

5. **DeviceManager abstraction**: `AndroidDriver` is tightly scoped to one device. `DeviceManager` adds the minimum indirection needed to replace it with a multi-device iterator in the future without touching `main.py` or `scheduler.py`.

6. **--dry-run**: Long-run configs are complex. A dry-run lets testers verify plan logic, quiet-hour coverage, and jitter bounds before attaching a device — catches schedule mistakes without wasting lab time.

### How to add a new test case

1. Copy `config/run.example.yaml` → `config/<app-name>.yaml`
2. Fill in `android.app_package`, `android.app_activity`, `android.udid`
3. Update `selectors.android.*` to match the app's UI text (use lists for multilingual support)
4. Set symptom/activity catalogs, or define an explicit `symptom_plan`
5. Run: `python src/main.py --config config/<app-name>.yaml --dry-run` to verify
6. Run: `python src/main.py --config config/<app-name>.yaml --once` for a single live injection test

### Multi-device extension path

When multi-device support is needed:
1. `DeviceManager` accepts `config["devices"]` as a list
2. Creates one `AndroidDriver` + `ArtifactManager` sub-dir per UDID
3. Expose `__iter__` instead of `.driver` property
4. Run jobs concurrently using `threading` (one thread per device)
5. `LongRunScheduler` and `main.py` caller code requires no changes (pass `dm` instead of `dm.driver`)

---

## [2026-03-03] Installer reliability + auto browser open

### Changes
- **start.bat**: Replace delayed-cmd browser open with direct `start "" "http://127.0.0.1:5001"`
- **start.sh**: Replace background subshell `(sleep 2 && open ...) &` with direct `open "http://127.0.0.1:5001"`
- **install.sh**: Switch Appium from `npm install -g appium` to `npx -y appium@3`; same for driver list/install — avoids global PATH issues
- **install.bat**: Convert remaining parenthesized `IF ERRORLEVEL` block (npm check) to `IF NOT ERRORLEVEL 1 GOTO` style — consistent with all other steps, prevents silent exit edge case

### Reasoning
1. **Browser open**: Delay-based open is fragile; Flask starts fast enough that direct `start`/`open` is reliable and simpler
2. **npx vs global appium**: Global install requires admin rights and PATH refresh after winget installs Node; npx uses a local cache (`~/.npm/_npx`) with no PATH side effects
3. **install.bat GOTO style**: CMD parenthesized blocks with `GOTO` inside can behave unexpectedly on some Windows versions; pure label-based flow is unambiguous

---

## [2026-02-26] Logcat & Artifact Logging Enhancement + Symptom Success Detection

### Changes
- **src/android/driver.py**: Added reporter events around logcat capture (start/done/fail)
- **src/utils/artifacts.py**: Return None on failure; expose `seconds` parameter for adb call tuning
- **.github/copilot-instructions.md**: Added rule #5 to document multi-file changes in DEVLOG
- **src/workflows/symptom_inject.py**: 
  - Added success signal wait (critical for long runs)
  - Enhanced failure evidence capture (UI state dump)
  - Include logcat path in event log
- **config/run.example.yaml**: Added `symptom_success_signal_text` selector

### Reasoning
1. **Artifact logging**: 72h runs need precise "when did we capture" timestamps and success/failure status
   - Reporter events bridge driver/artifact layers (visibility)
   - Failures return None (not silently disappear)
   
2. **Success signal detection**: Clicking button ≠ symptom registered
   - Added explicit wait for confirmation (toast/dialog/screen state)
   - Configurable via selector for app-specific variants
   - On failure, capture current UI text for forensics

3. **DEVLOG rule**: Multi-file changes must document intent
   - Avoids "why was this changed?" questions later
   - Helps onboard future maintainers

---

## [2026-02-26] Watchdog Recovery + Scheduler Sleep Prevention

### Changes
- **src/android/driver.py**: 
  - Added `recover_session(step)` method with 3 escalating recovery steps:
    1. Press back key + idle
    2. start_activity() + idle
    3. terminate_app() + activate_app() + idle
  - Each step emits reporter events for forensics
- **src/orchestrator/scheduler.py**:
  - Both `_run_plan()` and `_run_interval()` now emit `scheduler_started` event with PC sleep warning
  - Warning logged to reporter: "PC must remain powered on and awake; disable sleep/suspend/hibernation"
  - Updated `_run_with_health_check()` to automatically attempt 3-step recovery on session failure
  - Recovery logic: try each step sequentially, verify after each, stop on first success

### Reasoning
1. **Watchdog recovery**: Long runs fail not from crashes but from stuck UI
   - 3 steps let us escalate: gentle (back) → forceful (start_activity) → destructive (kill)
   - Each step is logged, so we can see which recovery level was needed
   - Automated recovery means fewer manual interventions

2. **Sleep prevention**: PC hibernation silently breaks Appium sessions
   - Explicit warning logged at start ensures operators know requirement
   - Sleep warning is in event log, captured in reports & alerts

### Next
- [ ] Test recovery sequence on real device
- [ ] Add config option for recovery step cooldown (wait between retries)
- [ ] Monitor which recovery steps are needed most in production
- [ ] Merge to main after testing
