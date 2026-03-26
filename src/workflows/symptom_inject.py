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

import logging
import time

from src.driver import AndroidDriver
from src.retry import retry

# Picker always shows English labels — map Korean alternatives to English
_KO_TO_EN: dict[str, str] = {
    "두근거림":    "Palpitations",
    "가슴 통증":   "Chest Pain",
    "어지러움":    "Dizziness",
    "호흡 가파름": "Short Breath",
    "흉통":        "Chest Pain",
    "호흡곤란":    "Short Breath",
}
_KNOWN_EN: frozenset[str] = frozenset({"Chest Pain", "Palpitations", "Dizziness", "Short Breath"})


def _resolve_english(texts: list[str]) -> str | None:
    """Return the canonical English picker label from a bilingual candidate list.

    Checks in order:
      1. Any element that is already a known English label.
      2. Any element that maps via the Korean → English table.
    Returns None if no English label can be resolved.
    """
    for t in texts:
        if t in _KNOWN_EN:
            return t
    for t in texts:
        en = _KO_TO_EN.get(t)
        if en:
            return en
    return None


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
        d.wait_idle(1.0)  # brief settle before checking picker (slow devices)

        # Wait for the picker title to confirm the UI is ready
        picker_title = d.sel.get(
            "symptom_picker_title",
            ["Check your symptoms", "증상을 선택해주세요."],
        )
        _wait_for_picker(d, picker_title, timeout=20)
        d.screenshot("symptom_picker_open")
        # NOTE: do NOT call _dump_page_source here — page_source triggers
        # UiAutomator2 accessibility events that dismiss the React Native
        # bottom-sheet picker before we can tap anything.
        d.wait_idle(0.3)  # brief settle; keep this short so picker stays open
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

        # ── 9b. Navigate back to ECG main tab if on diary screen ─────────
        # Samsung Korean app goes to diary tab after symptom injection.
        # Return to ECG tab so the next health check sees "증상 추가".
        if signal == "success_signal":
            main_tab = d.sel.get("main_tab_text")
            if main_tab and d.is_visible_text(main_tab):
                d.tap_text(main_tab, timeout=5, contains=True)
                d.wait_idle(1.0)

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


def _find_symptom_element(d: AndroidDriver, texts: list[str], timeout: int = 10):
    """
    Locate the symptom item element in the picker.

    Always resolves to the English label first (picker only exposes English
    content-desc / text). Falls back to textContains with all candidates.
    """
    from selenium.webdriver.common.by import By
    from selenium.webdriver.support.ui import WebDriverWait
    from selenium.webdriver.support import expected_conditions as EC

    en_label = _resolve_english(texts)
    logging.info("[SYMPTOM] _find_symptom_element: texts=%r  english_label=%r", texts, en_label)

    last_exc: Exception = RuntimeError(f"None of {texts!r} found in picker")

    # Pass 1: content-desc — single WebDriverWait polls English first, then Korean.
    # English picker → English matches on first cycle (Korean fails instantly).
    # Korean picker  → Korean matches on first cycle (English fails instantly).
    # Both cases resolve within the first poll without wasting per-label timeout.
    search_order = []
    if en_label:
        search_order.append(en_label)
    for t in texts:
        if t != en_label:
            search_order.append(t)

    def _any_desc(driver):
        # Exact description match first — avoids matching container elements
        # whose content-desc is a concatenation of all child labels.
        for t in search_order:
            try:
                return driver.find_element(
                    By.ANDROID_UIAUTOMATOR,
                    f'new UiSelector().description("{t}")',
                )
            except Exception:
                pass
        # Fall back to contains match if exact fails
        for t in search_order:
            try:
                return driver.find_element(
                    By.ANDROID_UIAUTOMATOR,
                    f'new UiSelector().descriptionContains("{t}")',
                )
            except Exception:
                pass
        return False

    try:
        el = WebDriverWait(d.drv, timeout).until(_any_desc)
        logging.info("[SYMPTOM] found via description, search_order=%r", search_order)
        return el
    except Exception as exc:
        logging.info("[SYMPTOM] description all failed: %s", exc)
        last_exc = exc

    # Pass 2: textContains fallback (finds inner TextView)
    per = max(timeout // max(len(search_order), 1), 1)
    for t in search_order:
        try:
            el = d.find(t, timeout=per, contains=True)
            logging.info("[SYMPTOM] found via textContains(%r)", t)
            return el
        except Exception as exc:
            last_exc = exc

    raise last_exc


def _find_coords_in_xml(xml_str: str, texts: list[str]) -> "tuple[int, int] | None":
    """
    Parse UiAutomator2 page_source XML and return the center (cx, cy) of the first
    node whose text or content-desc contains any of the given strings.
    Returns None if not found or parsing fails.
    """
    import xml.etree.ElementTree as ET
    import re

    try:
        root = ET.fromstring(xml_str)
    except Exception:
        return None
    for node in root.iter():
        node_text = node.get("text", "")
        node_desc = node.get("content-desc", "")
        for t in texts:
            if not t:
                continue
            if t == node_text or t in node_text or t == node_desc or t in node_desc:
                bounds = node.get("bounds", "")
                m = re.match(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', bounds)
                if m:
                    x1, y1, x2, y2 = (int(m.group(i)) for i in range(1, 5))
                    if x2 > x1 and y2 > y1:
                        return (x1 + x2) // 2, (y1 + y2) // 2
    return None


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
    from selenium.webdriver.common.by import By

    # Parse incoming value — handles both list and comma-joined string
    # e.g. "두근거림,Palpitations" → ["두근거림", "Palpitations"]
    if isinstance(symptom, str):
        texts = [t.strip() for t in symptom.split(",") if t.strip()]
    else:
        texts = list(symptom)

    en_label = _resolve_english(texts)
    logging.info(
        "[SYMPTOM] _tap_symptom_item: original=%r  parsed=%r  english_label=%r",
        symptom, texts, en_label,
    )
    label = (en_label or texts[0])[:12]

    d.screenshot(f"symptom_pre_{label}")
    last_exc: Exception = RuntimeError(f"Could not select symptom: {texts!r}")

    # --- strategy 0: page_source coord tap (Android 10 / slow-device safe) ---
    # WebDriverWait polling inside the picker can fire accessibility events that
    # dismiss React Native bottom sheets on older Android (e.g. Android 10).
    # One page_source dump may also dismiss the picker, but we re-open it and
    # then tap with stored coordinates — no further find_element calls needed.
    try:
        xml = d.drv.page_source
        coords_0 = _find_coords_in_xml(xml, texts)
        if coords_0:
            cx0, cy0 = coords_0
            logging.info("[SYMPTOM] strategy=page_source_coords cx=%d cy=%d", cx0, cy0)
            # Re-open picker if page_source dismissed it
            if picker_title and not d.is_visible_text(picker_title, timeout=2):
                logging.info("[SYMPTOM] picker dismissed by page_source, re-opening")
                _symptom_add = d.sel.get("symptom_add_text", ["증상 추가", "Add Symptom"])
                d.tap_text(_symptom_add, timeout=8, contains=True)
                _wait_for_picker(d, picker_title, timeout=8)
            d.drv.execute_script("mobile: clickGesture", {"x": cx0, "y": cy0})
            d.wait_idle(1.0)
            picker_still_open = picker_title and d.is_visible_text(picker_title, timeout=1)
            if picker_still_open:
                logging.info("[SYMPTOM] success via page_source_coords (multi-select)")
                return
            success_signal = d.sel.get("symptom_success_signal_text")
            main_indicator = d.sel.get("symptom_add_text", ["증상 추가", "Add Symptom"])
            if success_signal and d.is_visible_text(success_signal, timeout=2):
                logging.info("[SYMPTOM] success via page_source_coords (success_signal)")
                return
            if d.is_visible_text(main_indicator, timeout=2):
                logging.info("[SYMPTOM] success via page_source_coords (main_screen)")
                return
            logging.info("[SYMPTOM] page_source_coords: picker closed without success signal, "
                         "falling through to element-based strategies")
        else:
            logging.info("[SYMPTOM] page_source_coords: target not found in XML, "
                         "falling through")
    except Exception as e:
        logging.info("[SYMPTOM] strategy=page_source_coords error: %s", e)

    for attempt in range(scroll_tries + 1):
        # --- locate (try all language alternatives) ---
        try:
            el = _find_symptom_element(d, texts, timeout=10)
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

        # Element may go stale immediately after find if React Native re-renders.
        # Re-find once on StaleElementReferenceException before proceeding.
        try:
            el_clickable = el.get_attribute("clickable") == "true"
            logging.info("[SYMPTOM] attempt=%d element found: %r tag=%s bounds=%s clickable=%s",
                         attempt, label,
                         el.tag_name,
                         el.get_attribute("bounds"),
                         el_clickable)
        except Exception as stale_exc:
            logging.info("[SYMPTOM] element went stale after find, re-finding: %s", stale_exc)
            try:
                el = _find_symptom_element(d, texts, timeout=5)
                el_clickable = el.get_attribute("clickable") == "true"
            except Exception as refind_exc:
                last_exc = refind_exc
                continue

        # --- strategy 1: mobile:clickGesture on element coordinates ---
        # Use Android's W3C gesture API for React Native pickers.
        # drv.tap() generates an instantaneous (0ms) POINTER_DOWN/UP which React
        # Native may ignore; mobile:clickGesture goes through the native input
        # pipeline and properly synthesises a touch press+release.
        # Korean picker: content-desc is on inner non-clickable TextView whose
        # bounds are inside the individual button — tapping those coords is correct.
        try:
            loc = el.location
            sz  = el.size
        except Exception as stale_loc_exc:
            logging.info("[SYMPTOM] stale at el.location, re-finding: %s", stale_loc_exc)
            try:
                el = _find_symptom_element(d, texts, timeout=5)
                loc = el.location
                sz  = el.size
            except Exception as refind_loc_exc:
                last_exc = refind_loc_exc
                continue
        cx  = loc["x"] + sz["width"]  // 2
        cy  = loc["y"] + sz["height"] // 2
        logging.info("[SYMPTOM] strategy=click_gesture (clickable=%s) cx=%d cy=%d",
                     el_clickable, cx, cy)
        _tap_succeeded = False
        try:
            d.drv.execute_script("mobile: clickGesture", {"x": cx, "y": cy})
            _tap_succeeded = True
        except Exception as e:
            logging.info("[SYMPTOM] mobile:clickGesture failed, falling back to drv.tap: %s", e)
            try:
                d.drv.tap([(cx, cy)], 120)  # 120 ms duration
                _tap_succeeded = True
            except Exception as e2:
                logging.info("[SYMPTOM] drv.tap also failed: %s", e2)

        if _tap_succeeded:
            d.wait_idle(1.0)
            picker_still_open = picker_title and d.is_visible_text(picker_title, timeout=1)
            logging.info("[SYMPTOM] after click_gesture picker_still_open=%s", picker_still_open)

            if picker_still_open:
                # Picker still open after tap → item was SELECTED (multi-select Korean picker
                # keeps the sheet open until the confirm button is pressed).
                # Return success; step 6 in inject_symptom_event will handle the confirm button.
                logging.info("[SYMPTOM] success via click_gesture (picker open → multi-select)")
                return
            else:
                # Picker closed — check either success signal OR back on main ECG screen.
                # Korean app: navigates to diary tab ("환자일지 등록" button visible).
                # English app: stays on main ECG screen ("Add Symptom" button visible).
                # Only re-open picker if NEITHER is visible (genuine backdrop dismiss).
                success_signal = d.sel.get("symptom_success_signal_text")
                main_indicator = d.sel.get("symptom_add_text", ["증상 추가", "Add Symptom"])
                if success_signal and d.is_visible_text(success_signal, timeout=2):
                    logging.info("[SYMPTOM] success via click_gesture (success_signal confirmed)")
                    return
                if d.is_visible_text(main_indicator, timeout=2):
                    logging.info("[SYMPTOM] success via click_gesture (back on main screen)")
                    return
                # Neither signal found → likely backdrop dismiss
                logging.info("[SYMPTOM] click_gesture: picker closed but no success indicator "
                             "→ backdrop dismiss suspected; re-opening picker")
                try:
                    _symptom_add = d.sel.get("symptom_add_text", ["증상 추가", "Add Symptom"])
                    d.tap_text(_symptom_add, timeout=8, contains=True)
                    _wait_for_picker(d, picker_title, timeout=8)
                    el = _find_symptom_element(d, texts, timeout=8)
                    # Refresh bounds after re-open
                    loc = el.location
                    sz  = el.size
                    cx  = loc["x"] + sz["width"]  // 2
                    cy  = loc["y"] + sz["height"] // 2
                    logging.info("[SYMPTOM] picker re-opened after false dismiss; "
                                 "continuing to next strategy")
                except Exception as reopen_exc:
                    logging.info("[SYMPTOM] re-open after false dismiss failed: %s", reopen_exc)
                    last_exc = RuntimeError(
                        f"click_gesture false dismiss and re-open failed: {reopen_exc}"
                    )
                    continue

        # --- strategy 2: click nearest clickable ancestor (TouchableOpacity) ---
        # React Native renders Text inside View layers; the clickable
        # TouchableOpacity may be 1-3 levels above the text element.
        # XPATH ancestor-or-self finds the first element with clickable=true,
        # which is the actual touch handler that onPress is attached to.
        try:
            clickable = el.find_element(
                By.XPATH, "ancestor-or-self::*[@clickable='true'][1]"
            )
            anc_bounds = clickable.get_attribute("bounds")
            logging.info("[SYMPTOM] strategy=ancestor_click tag=%s bounds=%s",
                         clickable.tag_name, anc_bounds)
            clickable.click()
            d.wait_idle(0.5)
            picker_still_open = picker_title and d.is_visible_text(picker_title, timeout=1)
            logging.info("[SYMPTOM] after ancestor_click picker_still_open=%s", picker_still_open)
            if not picker_title or not picker_still_open:
                logging.info("[SYMPTOM] success via ancestor_click")
                return
        except Exception as e:
            logging.info("[SYMPTOM] ancestor_click failed: %s", e)

        # --- strategy 3: element.click() (W3C pointer action to element centre) ---
        try:
            logging.info("[SYMPTOM] strategy=element_click cx=%d cy=%d", cx, cy)
            el.click()
            d.wait_idle(0.5)
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
