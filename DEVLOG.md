# Development Log

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
