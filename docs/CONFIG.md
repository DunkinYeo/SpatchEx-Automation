# Configuration Reference

Full reference for `config/*.yaml` files.
Copy `config/run.example.yaml` as your starting point.

---

## `platform`

```yaml
platform: android
```

Only `"android"` is supported.

---

## `run`

| Key | Type | Required | Default | Description |
|-----|------|----------|---------|-------------|
| `name` | string | yes | — | Used as output folder name and log prefix |
| `duration_hours` | int | yes | — | Total test run duration (e.g. 24 / 48 / 72) |
| `symptom_interval_hours` | float | yes | — | Hours between injections in interval mode; ignored when `symptom_plan` is set |
| `start_immediately` | bool | no | `true` | If `true`, fires the first injection ~5 s after launch instead of waiting one full interval |
| `jitter_seconds` | float | no | `0` | Uniform random jitter applied to each scheduled trigger: `±jitter_seconds`. E.g. `300` = ±5 min |
| `quiet_hours` | object | no | — | Suppress injections during low-activity hours (see below) |

### `run.quiet_hours`

```yaml
run:
  quiet_hours:
    start: 23.0   # 11 PM
    end:   6.0    # 6 AM
```

`start` and `end` are decimal hours (0–24).
Overnight windows (`start > end`) are supported, e.g. 23–6 skips 11 PM–6 AM.

---

## `android`

| Key | Type | Required | Default | Description |
|-----|------|----------|---------|-------------|
| `appium_server_url` | string | yes | — | Appium server address, e.g. `http://127.0.0.1:4723` |
| `device_name` | string | yes | — | Human-readable label (any string) |
| `udid` | string | yes* | — | Device serial from `adb devices`. Required when more than one device is connected |
| `app_package` | string | yes | — | Android package name, e.g. `com.wellysis.spatchcardio.ex` |
| `app_activity` | string | yes | — | Fully-qualified activity name |
| `no_reset` | bool | no | `true` | Keep app data between Appium sessions |
| `new_command_timeout` | int | no | `3600` | Seconds before Appium drops an idle session |

---

## `selectors`

Each selector value can be a **string** or a **list of strings** (tried in order, first match wins). Use lists to support multiple app languages:

```yaml
selectors:
  android:
    start_now_text: ["Start Now", "지금 시작"]
```

### Measurement start

| Key | Description |
|-----|-------------|
| `start_now_text` | "Start" button on the home screen |
| `consent_agree_text` | Consent/agree button |
| `use_spatch_text` | Device selection button |
| `duration_sheet_title` | Title of the duration picker sheet (used to detect when it's open) |
| `duration_24h_text` | 24-hour option label |
| `duration_48h_text` | 48-hour option label |
| `duration_72h_text` | 72-hour option label |
| `confirm_text` | Generic confirm/OK button |

### Offline mode (leave blank if not applicable)

| Key | Description |
|-----|-------------|
| `offline_mode_text` | Offline mode option text |
| `offline_checkbox_id` | Resource-id of the consent checkbox (resource-id preferred over text for checkboxes) |
| `offline_agree_text` | Agree button inside the offline consent dialog |
| `offline_confirm_text` | Separate confirm button (if any) |

### Running screen

| Key | Description |
|-----|-------------|
| `symptom_add_text` | "Add Symptom" button on the measurement screen |

### Symptom picker

| Key | Description |
|-----|-------------|
| `symptom_picker_title` | Title of the symptom picker sheet |
| `symptom_confirm_text` | Submit button inside the picker. Leave **blank** if the picker closes automatically on symptom tap (no confirm button) |
| `symptom_done_text` | Final journal/done button after the picker. Leave **blank** if not present |
| `symptom_success_signal_text` | Toast or dialog text confirming the symptom was saved. Leave **blank** to skip the post-injection confirmation check |

### Other (free-text) input

| Key | Description |
|-----|-------------|
| `other_text_field_id` | Resource-id of the free-text EditText. Used when "Other" is selected |
| `keyboard_done_text` | IME action button label (Done / 완료) |

### Activity picker

| Key | Description |
|-----|-------------|
| `add_activity_text` | "Add Activity" trigger button |
| `activity_submit_text` | Submit/add button inside the activity picker |

---

## `symptom_plan`

Explicit injection schedule (hours after test start). When set, `symptom_interval_hours` is ignored.

```yaml
symptom_plan:
  - at_hour: 4
    symptoms: ["Palpitations"]
    other_text: ""
    activities: []
  - at_hour: 8
    symptoms: ["Chest Pain"]
    other_text: "mild after walking"
    activities: ["Walking"]
```

| Key | Type | Description |
|-----|------|-------------|
| `at_hour` | float | Hours after test start to fire this injection |
| `symptoms` | list[str] | One or more symptom names from the picker |
| `other_text` | string | Free-text entry for the "Other" field (optional) |
| `activities` | list[str] | Activity names to select (optional) |

Leave `symptom_plan: []` to use interval-based random selection from `symptom_catalog`.

---

## `symptom_catalog` / `activity_catalog`

Used in **interval mode** (when `symptom_plan` is empty). One symptom is selected at random for each injection.

```yaml
symptom_catalog:
  - "Chest Pain"
  - "Palpitations"

activity_catalog:
  - "Walking"
  - "Sleeping"
```

---

## `recovery`

Controls the 3-step escalating recovery that triggers when a pre-job health check fails.

| Step | Action |
|------|--------|
| 1 | Press Back key + short wait |
| 2 | `start_activity` (force relaunch) |
| 3 | `terminate` + `activate` (kill / cold-start) |

After each step the driver waits `cooldown_seconds_between_steps`, then re-checks UI health. Returns immediately on the first successful re-check.

```yaml
recovery:
  cooldown_seconds_between_steps: 30
```

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `cooldown_seconds_between_steps` | int | `30` | Wait time between each recovery step |

---

## `artifacts`

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `output_dir` | string | `"artifacts"` | Root directory for all run outputs (logs, screenshots, HTML report) |
| `collect_logcat_on` | string | `"on_failure"` | When to capture adb logcat: `"every_job"` or `"on_failure"` |

---

## `reporting`

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `html_report` | bool | `true` | Generate `summary.html` in the output directory after the run |

---

## `slack`

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `enabled` | bool | `false` | Enable Slack notifications |
| `webhook_url` | string | `""` | Incoming Webhook URL |
| `mention` | string | `""` | Mention string, e.g. `"@here"` |

---

## `hub`

Sends real-time events to a team dashboard (another PC running the Web UI).

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `enabled` | bool | `false` | Enable hub forwarding |
| `url` | string | `""` | Hub address, e.g. `http://192.168.1.100:5001` |
| `tester_name` | string | `""` | Label shown on the dashboard |

---

## CLI flags

| Flag | Description |
|------|-------------|
| `--config PATH` | Path to YAML config (required) |
| `--dry-run` | Validate config and print the schedule without connecting to a device |
| `--once` | Run exactly one injection immediately, then exit |
