# UAT Tool Plan — SpatchEx Automation

**Goal**: Convert the current developer-oriented automation tool into a portable, zero-setup UAT tool for CS/UAT staff, while preserving the framework's extensibility for future similar mobile apps.

---

## Non-Developer User Flow (Target)

```
1. Receive ZIP from IT/developer
2. Unzip anywhere (e.g., Desktop)
3. Connect phone via USB + allow USB debugging on phone
4. Double-click start.bat
5. Browser opens automatically → enter name → click Start Test
6. Walk away — test runs for 24/48/72 hours
7. Double-click STOP.bat when done
```

No Python installation. No Node.js. No Appium. No command line.

---

## Current State vs Target State

| Concern | Current (dev) | Target (UAT) |
|---------|--------------|--------------|
| Python | System install required | Bundled in `runtime/python/` |
| Node.js / Appium | System/global install | Bundled in `runtime/node/` |
| ADB | System PATH required | Bundled in `runtime/platform-tools/` |
| pip packages | `.venv` per-project | Pre-installed in bundled Python |
| User entry point | `run.bat` + manual steps | `start.bat` (one double-click) |
| Config | Complex YAML with selectors | `config.yaml` with 4 fields only |
| Stop | Kill terminals manually | `STOP.bat` |

---

## Proposed Folder Structure

```
SpatchEx-Automation/
│
│  ── USER-FACING (CS/UAT staff sees only these) ──────────────────────
├── start.bat                   ← Double-click to start everything
├── STOP.bat                    ← Double-click to stop
├── config.yaml                 ← Tester settings (name, device, duration)
├── README_QuickStart.txt       ← Non-technical guide
│
│  ── RUNTIME (auto-managed, gitignored) ────────────────────────────────
├── runtime/
│   ├── python/                 ← Python 3.12 embeddable + site-packages
│   │   └── python.exe
│   ├── node/                   ← Node.js 20 portable + Appium
│   │   ├── node.exe
│   │   └── node_modules/
│   │       └── .bin/appium
│   ├── platform-tools/         ← Android ADB tools
│   │   └── adb.exe
│   └── .ready                  ← Sentinel: runtime fully initialized
│
│  ── FRAMEWORK (developer-facing, do not expose to UAT staff) ──────────
├── src/
│   ├── main.py                 ← Automation entry point
│   ├── driver.py               ← Appium/Android driver
│   ├── device_manager.py
│   ├── scheduler.py            ← Job scheduling + health checks
│   ├── reporter.py             ← JSONL events + HTML reports
│   ├── artifacts.py            ← Screenshots + logcat
│   ├── retry.py
│   ├── slack.py
│   └── workflows/
│       ├── measurement_start.py
│       └── symptom_inject.py
│
├── web/
│   ├── app.py                  ← Flask web UI backend
│   └── templates/
│       ├── index.html
│       └── team.html
│
│  ── APP-SPECIFIC CONFIGS ──────────────────────────────────────────────
├── config/
│   ├── apps/                   ← One YAML per app (Phase 3)
│   │   └── spatch-ex.yaml      ← Package, activity, selectors, symptoms
│   ├── spatch-ex.yaml          ← Current app config (Phase 1/2)
│   └── run.example.yaml        ← Template for adding new apps
│
│  ── ARTIFACTS (auto-created, gitignored) ──────────────────────────────
├── output/
│   └── {timestamp}/
│       ├── events.jsonl
│       ├── summary.html
│       ├── screenshots/
│       └── logs/
│
│  ── DEVELOPER TOOLS ────────────────────────────────────────────────────
├── install/
│   ├── install.bat             ← Admin: prepare or refresh local runtime
│   ├── install.sh              ← Mac/Linux developer setup
│   └── make_test_zip.bat       ← Build the distributable ZIP
│
├── docs/
│   ├── CONFIG.md
│   └── UAT_TOOL_PLAN.md        ← This file
│
├── requirements.txt
└── .gitignore
```

---

## Config Separation Strategy

### Layer 1 — User-facing (`config.yaml` in root)
Only what a UAT tester needs to set:
```yaml
tester:
  name: "Your Name"

device:
  udid: "55ETQWBXYE1RA1"   # from: adb devices

test:
  app: spatch-ex            # which app profile to load
  duration_hours: 24
  symptom_interval_hours: 1.0
  start_immediately: true
```

### Layer 2 — App-specific (`config/apps/spatch-ex.yaml`, developer-managed)
```yaml
android:
  package: com.wellysis.spatchcardio.ex
  activity: com.wellysis.spatchcardio.ex.MainActivity

selectors:
  main_tab_text: ["My ECG", "나의 ECG"]
  symptom_add_text: ["Add Symptom", "증상 추가"]
  # ... all selectors

symptom_catalog:
  - Chest Pain
  - Palpitations
  - Dizziness
  - Short Breath
```

### Layer 3 — Framework config (hardcoded defaults, no YAML needed)
Recovery settings, timeouts, artifact paths — in `src/` code.

---

## Runtime Bundling Strategy

| Component | Method | Size | Timing |
|-----------|--------|------|--------|
| Python 3.12 | Embeddable ZIP from python.org | ~35 MB | Bundled in ZIP |
| pip packages | Pre-installed into `runtime/python/Lib/` | ~50 MB | Bundled in ZIP |
| ADB / Platform Tools | ZIP from Google | ~12 MB | Bundled in ZIP |
| Node.js 20 | Portable ZIP from nodejs.org | ~30 MB | Downloaded first run |
| Appium + UiAutomator2 | npm install into `runtime/node/` | ~150 MB | Downloaded first run |

**Initial ZIP size**: ~100 MB
**After first-run bootstrap**: ~300 MB on disk

`start.bat` detects `runtime\.ready` sentinel:
- If missing → calls `install\bootstrap.bat` (downloads Node + Appium)
- If present → skips setup, starts immediately

---

## Extensibility: Adding a New App (Phase 3)

1. Create `config/apps/<new-app>.yaml` with package, activity, selectors
2. If the app has non-standard flows: add `src/workflows/<new_app>_start.py`
3. UAT staff sets `config.yaml → test.app: <new-app>`

The framework auto-loads the matching app config. No framework code changes
needed for apps that follow the standard measurement + symptom injection flow.

---

## Migration Steps from Current Repository

### Phase 1 — Portable UAT for Current App (Now)
- [x] `start/start.bat`: Add bundled runtime detection (`runtime\python`, `runtime\node`, `runtime\platform-tools`)
- [x] Create `STOP.bat` in project root
- [x] Create `README_QuickStart.txt` for CS/UAT staff
- [x] Update `install/install.bat`: Make clear it is admin/developer tool only
- [ ] Create `install/bootstrap.bat`: Download Node.js + npm install Appium into `runtime/`
- [ ] Prepare Python embeddable bundle script (`install/bundle_python.bat`)
- [ ] Update `.gitignore` for `runtime/`, `output/`, `config.yaml`
- [ ] Create root `config.yaml` (user-facing, simplified)

### Phase 2 — Framework Refactor (Next)
- [ ] Separate `config/apps/spatch-ex.yaml` from user-facing `config.yaml`
- [ ] Update `src/main.py` to merge user config + app config
- [ ] Move `SPATCH_EX_SELECTORS` from `web/app.py` → `config/apps/spatch-ex.yaml`
- [ ] Create `install/make_test_zip.bat` that bundles runtime into ZIP

### Phase 3 — Multi-App Support (Future)
- [ ] App discovery: `src/main.py` reads `config/apps/<name>.yaml` based on `config.yaml → test.app`
- [ ] Add second app: `config/apps/<new-app>.yaml`
- [ ] Custom workflow injection: if `src/workflows/<app>_start.py` exists, use it

---

## Files to Keep User-Facing (Root Level)

| File | Audience | Notes |
|------|---------|-------|
| `start.bat` / `run.bat` | UAT staff | Entry point |
| `STOP.bat` | UAT staff | Clean shutdown |
| `config.yaml` | UAT staff | Name, device, duration only |
| `README_QuickStart.txt` | UAT staff | Non-technical guide |

## Files to Hide / Keep Developer-Only

| File/Folder | Reason |
|-------------|--------|
| `src/` | Core framework — not user-editable |
| `web/` | Flask backend — not user-editable |
| `config/apps/` | Managed by developer per app |
| `install/` | Developer/admin tool only |
| `runtime/` | Auto-managed, gitignored |
| `output/` | Auto-generated artifacts |
| `.venv/` | Internal Python env (Phase 1 only) |

---

## Trade-offs

| Decision | Pro | Con |
|----------|-----|-----|
| Bundle Python embeddable | Zero Python install for users | +35 MB ZIP size |
| Bundle ADB | No Android SDK needed | +12 MB ZIP size |
| Download Node+Appium first run | Keeps ZIP manageable | First run needs internet (~200 MB) |
| `runtime\.ready` sentinel | Fast startup on subsequent runs | Must delete `.ready` to force re-setup |
| Single `config.yaml` in root | Simple for users | Framework must merge with app YAML |
| Flat `start.bat` (no subprocesses) | Easier to debug | All logic in one file = longer file |

---

*Last updated: Phase 1 — Portable UAT Tool baseline*
