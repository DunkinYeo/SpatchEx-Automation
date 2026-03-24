"""
Inject a symptom event while the measurement is running.

Artifact policy (every injection):
  - screenshot  before tapping 'Add Symptom'
  - screenshot  after  symptom picker closes
  - screenshot  after  journal submission
  - adb logcat  after  submission
  - JSONL event with elapsed_sec + success/failure

On failure:
  - extra screenshot of current screen
  - last successful step is recorded in JSONL
"""

import time

from src.driver import AndroidDriver
from src.retry import retry


@retry(tries=3, delay=3)
def inject_symptom_event(
    d: AndroidDriver,
    symptoms: list[str | list[str]],
    other_text: str = "",
    activities: list[str] | None = None,
):
    activities = activities or []
    t_start = time.monotonic()

    d.reporter.log_event(
        "inject_symptom_start",
        {
            "symptoms": symptoms,
            "other_text": other_text,
            "activities": activities,
        },
    )

    last_step = "init"
    try:
        # ── 1. Bring app to foreground ────────────────────────────────
        d.bring_to_foreground()
        d.wait_idle(1.0)

        # ── 2. Screenshot BEFORE ──────────────────────────────────────
        d.screenshot("inject_before")
        last_step = "before_screenshot"

        # ── 2b. Dismiss any blocking popup/dialog ────────────────────
        confirm = d.sel.get("confirm_text")
        if confirm and d.is_visible_text(confirm):
            d.reporter.log_event("popup_dismissed_before_inject", {})
            d.tap_text(confirm, timeout=5, contains=False)
            d.wait_idle(0.5)

        # ── 2b-1. Dismiss '기기 착용 상태 확인' warning popup ──
        # Modal with S-Patch placement illustration + '확인' button at bottom.
        # Appears when signal quality is unstable.
        conn_check = d.sel.get(
            "device_conn_check_text",
            ["기기 착용 상태 확인", "Check device wearing", "Wearing Check"],
        )
        if d.is_visible_text(conn_check):
            d.reporter.log_event("conn_check_popup_detected", {})
            confirm_btn = d.sel.get("confirm_text", ["확인", "Confirm", "OK"])
            if d.is_visible_text(confirm_btn):
                d.tap_text(confirm_btn, timeout=5, contains=False)
            else:
                d.drv.press_keycode(4)  # KEYCODE_BACK fallback
            d.reporter.log_event("conn_check_popup_dismissed", {})
            d.wait_idle(1.0)

        # ── 2b-2. Dismiss battery low popup (배터리 잔량 부족 / Battery Low 958) ─
        # Appears during measurement when S-Patch battery is depleted.
        # Korean: "배터리 잔량 부족 (958)" / English: "Battery Low (958)" (exact wording TBC)
        # Action: tap 확인 / OK to dismiss and continue.
        battery_low = d.sel.get(
            "battery_low_text",
            ["배터리 잔량 부족", "Battery Low", "Insufficient Battery", "Low Battery"],
        )
        if d.is_visible_text(battery_low, contains=True):
            d.reporter.log_event("battery_low_popup_detected", {})
            confirm_btn = d.sel.get("confirm_text", ["확인", "OK", "Confirm"])
            if d.is_visible_text(confirm_btn):
                d.tap_text(confirm_btn, timeout=5, contains=False)
            d.reporter.log_event("battery_low_popup_dismissed", {})
            d.wait_idle(1.0)

        # ── 2b-4. Handle 연결 끊김 (Bluetooth disconnection) popup ───
        # Retries until the main screen is restored or max attempts exceeded.
        disconnect = d.sel.get(
            "device_disconnect_text",
            ["연결 끊김", "Disconnected", "Connection Lost"],
        )
        reconnect = d.sel.get(
            "device_reconnect_text",
            ["재연결", "Reconnect", "다시 연결"],
        )
        waiting_text = d.sel.get("device_reconnect_waiting_text", "잠시 기다려주세요")
        symptom_add_check = d.sel.get("symptom_add_text", "Add Symptom")
        if d.is_visible_text(disconnect):
            d.reporter.log_event("disconnect_popup_detected", {})
            for attempt in range(10):
                if d.is_visible_text(symptom_add_check):
                    break  # back on main screen
                if d.is_visible_text(reconnect):
                    d.tap_text(reconnect, timeout=5, contains=True)
                    d.reporter.log_event("reconnect_tapped", {"attempt": attempt + 1})
                    d.wait_idle(6.0)  # wait for reconnect result
                elif d.is_visible_text(waiting_text):
                    d.wait_idle(3.0)  # still reconnecting
                else:
                    d.wait_idle(3.0)

        # ── 2c. Navigate back to main ECG tab if on a sub-screen ─────
        # Known sub-screens (all require KEYCODE_BACK to exit):
        #   - "기기 착용 상태" / Wearing Status
        #   - "실시간 심전도" / Real-time ECG  (landscape)
        #   - "검사 진행 현황" / Test Progress
        #   - "설정" / Settings  (2 levels deep: Settings → Test Progress → main)
        # Loop presses BACK until "증상 추가" is visible or max attempts reached.
        # After escaping sub-screens, tap main ECG tab if on Diary tab.
        symptom_add = d.sel.get("symptom_add_text", ["증상 추가", "Add Symptom"])
        sub_screens = [
            d.sel.get("device_wearing_status_text", ["기기 착용 상태", "Device Status", "Wearing Status"]),
            d.sel.get("realtime_ecg_text", ["실시간 심전도", "Real-time ECG", "Realtime ECG"]),
            d.sel.get("test_progress_text", ["검사 진행 현황", "Test Progress", "Exam Progress"]),
            d.sel.get("settings_text", ["설정", "Settings"]),
        ]
        for attempt in range(4):
            if d.is_visible_text(symptom_add):
                break
            on_sub = next((s for s in sub_screens if d.is_visible_text(s)), None)
            if on_sub:
                d.reporter.log_event("sub_screen_dismissed", {"screen": str(on_sub), "attempt": attempt + 1})
                d.drv.press_keycode(4)  # KEYCODE_BACK
                d.wait_idle(1.5)
            else:
                break

        main_tab = d.sel.get("main_tab_text")
        if main_tab and d.is_visible_text(main_tab) and not d.is_visible_text(symptom_add):
            d.reporter.log_event("navigate_to_main_tab", {})
            d.tap_text(main_tab, timeout=5, contains=True)
            d.wait_idle(1.0)

        # ── 3. Open symptom picker ────────────────────────────────────
        symptom_add = d.sel.get("symptom_add_text", "Add Symptom")
        d.tap_text(symptom_add, timeout=15, contains=True)

        # Wait for the picker title to confirm the UI is ready
        picker_title = d.sel.get(
            "symptom_picker_title",
            ["Check your symptoms", "증상을 선택해주세요."],
        )
        _wait_for_picker(d, picker_title, timeout=10)
        d.screenshot("symptom_picker_open")
        _dump_page_source(d, "picker_open_diagnostic")  # capture picker XML for debugging
        d.wait_idle(1.0)  # allow React Native list items to become fully interactive
        last_step = "picker_open"

        # ── 4. Select each symptom ────────────────────────────────────
        for s in symptoms:
            _tap_symptom_item(d, s, picker_title=picker_title)
        last_step = "symptoms_selected"

        # ── 5. Handle 'Other' free-text input ────────────────────────
        if other_text:
            _enter_other_text(d, other_text)
            last_step = "other_text_entered"

        # ── 6. Submit symptom picker (optional confirm button) ────────
        # Some app versions (e.g. Korean) have an explicit confirm button;
        # others (e.g. English) auto-close the picker on selection.
        d.wait_idle(0.5)
        symptom_confirm = d.sel.get("symptom_confirm_text")
        if symptom_confirm and d.is_visible_text(symptom_confirm):
            d.tap_text(symptom_confirm, timeout=10, contains=True)
            d.screenshot("symptom_picker_submitted")
            last_step = "picker_submitted"

        # ── 7. Journal submission screen (optional) ────────────────────
        submit = d.sel.get("symptom_done_text")
        if submit and d.is_visible_text(submit, contains=True):
            d.tap_text(submit, timeout=15, contains=True)
            d.screenshot("journal_submitted")
            last_step = "journal_submitted"

        # ── 8. Optional: add activities ───────────────────────────────
        if activities:
            _add_activities(d, activities)
            last_step = "activities_added"

        # ── 9. Wait for success confirmation ─────────────────────────────
        # Checks (in order): configured success text → main screen indicator.
        # Only fails if BOTH are absent within timeout.
        signal = d.wait_for_symptom_success(timeout=10)
        d.screenshot(f"symptom_success_{signal}")
        last_step = f"success_{signal}"

        # ── 10. Screenshot AFTER + logcat ────────────────────────────
        d.screenshot("inject_after")
        logcat_path = d.logcat("inject_logcat")

        elapsed = round(time.monotonic() - t_start, 1)
        d.reporter.log_event(
            "inject_symptom_done",
            {
                "status": "ok",
                "elapsed_sec": elapsed,
                "last_step": last_step,
                "logcat_path": logcat_path,
            },
        )

    except Exception as exc:
        elapsed = round(time.monotonic() - t_start, 1)
        # Capture comprehensive failure evidence
        try:
            d.screenshot("inject_failed_screen")
            d.logcat("inject_failed_logcat")
            _dump_page_source(d, "inject_failed")
            # Also capture current UI state if possible
            try:
                from selenium.webdriver.common.by import By
                ui_elements = d.drv.find_elements(By.CLASS_NAME, "android.view.View")
                ui_text = ";".join([el.text for el in ui_elements[:20] if el.text])
                d.reporter.log_event(
                    "inject_failure_ui_state",
                    {"visible_text": ui_text, "element_count": len(ui_elements)},
                )
            except Exception:
                pass
        except Exception:
            pass

        d.reporter.log_event(
            "inject_symptom_failed",
            {
                "error": str(exc),
                "elapsed_sec": elapsed,
                "last_step": last_step,
            },
        )
        raise


# ------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------


def _wait_for_picker(d: AndroidDriver, title: str | list, timeout: int = 10) -> None:
    """
    Poll until one of the picker title strings appears on screen.
    Raises RuntimeError if none appear within timeout.
    """
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if d.is_visible_text(title):
            return
        time.sleep(0.5)
    d.screenshot("picker_not_opened")
    raise RuntimeError(f"Symptom picker did not open within {timeout}s (title: {title!r})")


def _find_symptom_element(d: AndroidDriver, texts: list[str], timeout: int = 5):
    """
    Try each text in `texts` (English first, Korean second, etc.) and return
    the first element found.

    Strategy (in order):
      1. content-desc (accessibility label) — returns the outer clickable ViewGroup
         directly, which is exactly what we need for React Native TouchableOpacity.
      2. text / textContains — returns the inner non-clickable TextView as fallback.
    Raises the last exception if none match.
    """
    from selenium.webdriver.common.by import By
    from selenium.webdriver.support.ui import WebDriverWait
    from selenium.webdriver.support import expected_conditions as EC

    per = max(timeout // len(texts), 2)
    last_exc: Exception = RuntimeError(f"None of {texts!r} found")

    # Pass 1: content-desc match (finds the clickable outer ViewGroup directly)
    for t in texts:
        try:
            locator = (
                By.ANDROID_UIAUTOMATOR,
                f'new UiSelector().descriptionContains("{t}")',
            )
            return WebDriverWait(d.drv, per).until(
                EC.presence_of_element_located(locator)
            )
        except Exception as exc:
            last_exc = exc

    # Pass 2: text match fallback (finds inner TextView)
    for t in texts:
        try:
            return d.find(t, timeout=per, contains=True)
        except Exception as exc:
            last_exc = exc

    raise last_exc


def _tap_symptom_item(
    d: AndroidDriver,
    symptom: str | list[str],
    scroll_tries: int = 3,
    picker_title: str | list | None = None,
) -> None:
    """
    Tap a single symptom item in the picker.

    `symptom` may be a single string or a list of bilingual alternatives
    (e.g. ["Chest Pain", "가슴 통증"]). Each alternative is tried in order.

    Strategy per attempt:
      1. Locate the element by textContains (all language alternatives tried).
      2. Click the nearest clickable ancestor (TouchableOpacity) via XPATH.
      3. Fallback: tap via coordinates.
      4. Fallback: element.click() directly.
    If the element is not visible, scroll the list and retry up to scroll_tries times.
    Before each scroll retry, validate that the picker is still open (if picker_title given).
    On final failure: screenshot + page source dump before raising.
    """
    import logging
    from selenium.webdriver.common.by import By

    texts = [symptom] if isinstance(symptom, str) else symptom
    label = texts[0][:12]

    d.screenshot(f"symptom_pre_{label}")
    last_exc: Exception = RuntimeError(f"Could not select symptom: {texts!r}")

    for attempt in range(scroll_tries + 1):
        # --- locate (try all language alternatives) ---
        try:
            el = _find_symptom_element(d, texts, timeout=5)
        except Exception as exc:
            last_exc = exc
            if attempt < scroll_tries:
                # Validate picker is still open before retrying.
                if picker_title and not d.is_visible_text(picker_title):
                    d.screenshot(f"picker_closed_{label}_attempt{attempt + 1}")
                    _dump_page_source(d, f"picker_closed_{label}_attempt{attempt + 1}")
                    raise RuntimeError(
                        f"Symptom picker closed unexpectedly before "
                        f"'{label}' could be selected (attempt {attempt + 1})"
                    )
                _scroll_symptom_list(d)
                continue
            break

        logging.info("[SYMPTOM] attempt=%d element found: %r tag=%s bounds=%s clickable=%s",
                     attempt, label,
                     el.tag_name,
                     el.get_attribute("bounds"),
                     el.get_attribute("clickable"))

        # --- click nearest clickable ancestor (TouchableOpacity) ---
        # React Native renders Text inside View layers; the clickable
        # TouchableOpacity may be 1-3 levels above the text element.
        # XPATH ancestor-or-self finds the first element with clickable=true,
        # which is the actual touch handler that onPress is attached to.
        try:
            clickable = el.find_element(
                By.XPATH, "ancestor-or-self::*[@clickable='true'][1]"
            )
            logging.info("[SYMPTOM] strategy=ancestor_click tag=%s bounds=%s",
                         clickable.tag_name, clickable.get_attribute("bounds"))
            clickable.click()
            d.wait_idle(0.5)
            picker_still_open = picker_title and d.is_visible_text(picker_title, timeout=1)
            logging.info("[SYMPTOM] after ancestor_click picker_still_open=%s", picker_still_open)
            if not picker_title or not picker_still_open:
                logging.info("[SYMPTOM] success via ancestor_click")
                return
        except Exception as e:
            logging.info("[SYMPTOM] ancestor_click failed: %s", e)

        # --- fallback: tap via coordinates ---
        try:
            loc = el.location
            sz = el.size
            cx = loc["x"] + sz["width"] // 2
            cy = loc["y"] + sz["height"] // 2
            logging.info("[SYMPTOM] strategy=coord_tap cx=%d cy=%d", cx, cy)
            d.drv.tap([(cx, cy)])
            d.wait_idle(0.5)
            picker_still_open = picker_title and d.is_visible_text(picker_title, timeout=1)
            logging.info("[SYMPTOM] after coord_tap picker_still_open=%s", picker_still_open)
            if not picker_title or not picker_still_open:
                logging.info("[SYMPTOM] success via coord_tap")
                return
        except Exception as e:
            logging.info("[SYMPTOM] coord_tap failed: %s", e)

        # --- fallback: element.click() ---
        try:
            logging.info("[SYMPTOM] strategy=element_click")
            el.click()
            d.wait_idle(0.3)
            picker_still_open = picker_title and d.is_visible_text(picker_title, timeout=1)
            logging.info("[SYMPTOM] after element_click picker_still_open=%s", picker_still_open)
            if not picker_title or not picker_still_open:
                logging.info("[SYMPTOM] success via element_click")
                return
        except Exception as exc:
            logging.info("[SYMPTOM] element_click failed: %s", exc)
            last_exc = exc

        if attempt < scroll_tries:
            _scroll_symptom_list(d)

    # All attempts exhausted
    d.screenshot(f"symptom_fail_{label}")
    _dump_page_source(d, f"symptom_fail_{label}")
    raise last_exc


def _scroll_symptom_list(d: AndroidDriver) -> None:
    """Swipe the symptom picker list upward (scroll content down)."""
    try:
        size = d.drv.get_window_size()
        w, h = size["width"], size["height"]
        d.drv.swipe(w // 2, int(h * 0.70), w // 2, int(h * 0.30), duration=400)
        d.wait_idle(0.4)
    except Exception:
        pass


def _dump_page_source(d: AndroidDriver, label: str) -> None:
    """Write current UI XML (page source) to the log dir as a debug artifact."""
    import os

    try:
        xml = d.drv.page_source
        ts = d.artifacts._ts()
        path = os.path.join(d.artifacts.log_dir, f"{ts}_{label}.xml")
        with open(path, "w", encoding="utf-8") as f:
            f.write(xml)
        d.reporter.log_event("page_source_dumped", {"label": label, "path": path})
    except Exception:
        pass


def _enter_other_text(d: AndroidDriver, text: str):
    """
    Tap the 'Other' input field and type free text.
    Selector priority: other_text_field_id (resource-id) > 'Other' text tile.
    """
    field_id = d.sel.get("other_text_field_id")
    if field_id:
        el = d.find(field_id, timeout=5, contains=False)
    else:
        # Fall back: tap the 'Other' tile which opens the text input
        d.tap_text("Other", timeout=5, contains=True)
        # Then try to find any visible EditText
        from selenium.webdriver.common.by import By
        from selenium.webdriver.support.ui import WebDriverWait
        from selenium.webdriver.support import expected_conditions as EC

        el = WebDriverWait(d.drv, 5).until(
            EC.presence_of_element_located((By.CLASS_NAME, "android.widget.EditText"))
        )

    el.clear()
    el.send_keys(text)

    # Dismiss keyboard
    keyboard_done = d.sel.get("keyboard_done_text", "Done")
    if d.is_visible_text(keyboard_done):
        d.tap_text(keyboard_done, timeout=3, contains=False)
    else:
        try:
            d.drv.hide_keyboard()
        except Exception:
            pass


def _add_activities(d: AndroidDriver, activities: list[str]):
    add_act = d.sel.get("add_activity_text", "Add Activity")
    if not d.is_visible_text(add_act):
        return

    d.tap_text(add_act, timeout=10, contains=True)

    for a in activities:
        d.tap_text(a, timeout=10, contains=True)

    act_submit = d.sel.get("activity_submit_text", "Add Activity")
    if d.is_visible_text(act_submit):
        d.tap_text(act_submit, timeout=10, contains=True)

    d.screenshot("activity_added")
