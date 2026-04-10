"""
Best-effort, idempotent measurement start flow.

Supported paths:
  A)  Already running          → 'Add Symptom' visible → return immediately
  A1) Running but sub-screen   → dismiss dialog / tap main tab → return
  A2) "검사 진행 현황" screen  → press back → continue to B
  B)  Home screen (Korean)     → 'Start Now' → consent (all-agree + agree)
                                  → [test_info popup if web-portal test found]
                                  → [offline popup if no test found]
                                  → 'Use S-Patch' → duration → 'Confirm'
                                  → [battery warning popup]
  B)  Home screen (English)    → 'Start Now' → consent (checkbox + Accept)
                                  → [test_info popup if web-portal test found]
                                  → [offline popup "No test found" if offline]
                                  → duration → 'Confirm'

Offline detection:
  `offline_mode_text` (KO: "오프라인 모드로 실행" / EN: "No test found") triggers
  the offline consent flow: tick checkbox → tap confirm button.
"""

from src.driver import AndroidDriver
from src.retry import retry


@retry(tries=3, delay=3)
def ensure_measurement_started(d: AndroidDriver, duration_hours: int = 24):
    d.reporter.log_event("ensure_measurement_started", {})

    # ── 0. Ensure app is in foreground ────────────────────────────────
    d.bring_to_foreground()
    d.wait_idle(3.0)

    # ── A. Already running? ───────────────────────────────────────────
    symptom_btn = d.sel.get("symptom_add_text", "Add Symptom")
    if d.is_visible_text(symptom_btn):
        d.reporter.log_event("measurement_already_running", {})
        return

    # ── A1. Measurement running but on sub-screen or behind a dialog ─
    # Step 1: dismiss overlay dialogs (e.g. ECG quality warning).
    confirm = d.sel.get("confirm_text")
    if confirm and d.is_visible_text(confirm):
        try:
            d.tap_text(confirm, timeout=3, contains=False)
            d.wait_idle(0.5)
            if d.is_visible_text(symptom_btn):
                d.reporter.log_event("measurement_already_running", {})
                return
        except Exception:
            pass

    # Step 2: navigate to main ECG tab if on a sub-screen (e.g. Diary).
    main_tab = d.sel.get("main_tab_text")
    if main_tab and d.is_visible_text(main_tab):
        try:
            d.tap_text(main_tab, timeout=5, contains=True)
            d.wait_idle(1.0)
            if d.is_visible_text(symptom_btn):
                d.reporter.log_event("measurement_already_running", {})
                return
        except Exception:
            pass

    # ── A2. "검사 진행 현황" status screen → press back to return home ─
    status_screen = d.sel.get("measurement_status_screen_text")
    if status_screen and d.is_visible_text(status_screen):
        d.reporter.log_event("measurement_status_screen_detected", {})
        d.drv.press_keycode(4)  # KEYCODE_BACK
        d.wait_idle(1.5)

    # ── B. Home screen → tap "Start Now" first ────────────────────────
    start_now = d.sel.get("start_now_text", "Start Now")
    if d.is_visible_text(start_now, timeout=5):
        d.reporter.log_event("tapping_start_now", {})
        d.tap_text(start_now, contains=False)
        d.wait_idle(2.0)

    # ── Consent screen ────────────────────────────────────────────────
    agree = d.sel.get("consent_agree_text", "Agree")
    if d.is_visible_text(agree):
        # Tap "Agree to All" checkbox first if present (required before confirm button)
        all_agree = d.sel.get("consent_all_agree_text")
        if all_agree and d.is_visible_text(all_agree):
            d.tap_text(all_agree, contains=True)
            d.wait_idle(0.5)
        d.tap_text(agree, contains=False)
        d.wait_idle(1.5)

    # ── Connection error popup (e.g. "S-Patch connection lost") → dismiss ─
    # Retries up to 5 times in case the popup reappears after each OK tap.
    conn_error = d.sel.get("connection_lost_text")
    if conn_error:
        for _attempt in range(5):
            if not d.is_visible_text(conn_error):
                break
            d.reporter.log_event("connection_lost_popup_detected", {"attempt": _attempt + 1})
            ok_btn = d.sel.get("confirm_text", "OK")
            if d.is_visible_text(ok_btn):
                d.tap_text(ok_btn, contains=False)
            d.wait_idle(2.0)

    # ── Wait for web portal response (test_info or offline popup) ────
    # After consent the app queries the web portal; the response popup
    # can take up to ~30s depending on network. Poll until one appears
    # or we have moved past the popups already (Use S-Patch / symptom btn).
    import time as _t
    _test_info_sel  = d.sel.get("test_info_title_text")
    _offline_sel    = d.sel.get("offline_mode_text", "Offline")
    _use_spatch_sel = d.sel.get("use_spatch_text", "Use S-Patch")
    _portal_deadline = _t.monotonic() + 30
    while _t.monotonic() < _portal_deadline:
        if _test_info_sel and d.is_visible_text(_test_info_sel, timeout=1):
            break
        if d.is_visible_text(_offline_sel, timeout=1):
            break
        if d.is_visible_text(_use_spatch_sel, timeout=1):
            break
        if d.is_visible_text(symptom_btn, timeout=1):
            break

    # ── Web portal test info popup (test registered → just confirm) ───
    test_info = d.sel.get("test_info_title_text")
    if test_info and d.is_visible_text(test_info):
        d.reporter.log_event("test_info_popup_detected", {})
        confirm_btn = d.sel.get("confirm_text", "확인")
        if d.is_visible_text(confirm_btn):
            d.tap_text(confirm_btn, contains=False)
        d.wait_idle(1.5)

    # ── Offline branch ────────────────────────────────────────────────
    offline_text = d.sel.get("offline_mode_text", "Offline")
    if d.is_visible_text(offline_text):
        d.reporter.log_event("offline_mode_detected", {})
        _handle_offline_consent(d)

    # ── "Use S-Patch" button ──────────────────────────────────────────
    use_text = d.sel.get("use_spatch_text", "Use S-Patch")
    if d.is_visible_text(use_text):
        d.tap_text(use_text)

    # ── Duration sheet ────────────────────────────────────────────────
    sheet_title = d.sel.get("duration_sheet_title", "Select a test period")
    if d.is_visible_text(sheet_title):
        _select_duration(d, duration_hours)
        confirm = d.sel.get("confirm_text", "Confirm")
        if d.is_visible_text(confirm):
            d.tap_text(confirm, contains=False)
        d.wait_idle(2.0)

    # ── Battery warning popup (optional) ─────────────────────────────
    battery_warning = d.sel.get("battery_warning_text")
    if battery_warning and d.is_visible_text(battery_warning):
        d.reporter.log_event("battery_warning_detected", {})
        checkbox = d.sel.get("battery_confirm_checkbox_text")
        if checkbox and d.is_visible_text(checkbox):
            d.tap_text(checkbox, contains=True)
            d.wait_idle(0.5)
        start_btn = d.sel.get("battery_confirm_start_text")
        if start_btn and d.is_visible_text(start_btn):
            d.tap_text(start_btn, contains=False)
        d.wait_idle(2.0)

    # ── Wait for running screen ───────────────────────────────────────
    d.bring_to_foreground()
    d.wait_idle(2.0)

    if not d.is_visible_text(symptom_btn):
        d.wait_idle(5.0)

    if not d.is_visible_text(symptom_btn):
        d.screenshot("measurement_start_failed")
        raise RuntimeError(
            "Could not confirm measurement running (symptom button not visible)."
        )

    d.reporter.log_event("measurement_confirmed_running", {})


# ------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------


def _handle_offline_consent(d: AndroidDriver):
    """
    Tick the offline consent checkbox and confirm.
    Tries resource-id first, falls back to accessibility-id, then text.
    """
    checkbox_id = d.sel.get("offline_checkbox_id")
    if checkbox_id:
        try:
            el = d.find(checkbox_id, timeout=5, contains=False)
            if el.get_attribute("checked") != "true":
                el.click()
            return
        except Exception:
            pass

    # Fallback: tap the consent text area (some apps use a toggle row)
    offline_agree = d.sel.get("offline_agree_text", "I Agree")
    if d.is_visible_text(offline_agree):
        d.tap_text(offline_agree, contains=True)
        d.wait_idle(0.5)  # wait for button to become active after checkbox

    # Some apps show a separate confirm button for offline consent
    offline_confirm = d.sel.get("offline_confirm_text")
    if offline_confirm and d.is_visible_text(offline_confirm):
        d.tap_text(offline_confirm, contains=True)
        d.wait_idle(1.0)


def _select_duration(d: AndroidDriver, duration_hours: int = 24) -> None:
    """
    Select the duration option matching duration_hours (24, 48, 72, 144, 168, or 200).
    Tries the requested duration first, then falls back in ascending order.
    """
    _HOURS_TO_KEY = {
        24:  "duration_24h_text",
        48:  "duration_48h_text",
        72:  "duration_72h_text",
        144: "duration_144h_text",
        168: "duration_168h_text",
        200: "duration_200h_text",
    }
    _ALL_KEYS = (
        "duration_24h_text",
        "duration_48h_text",
        "duration_72h_text",
        "duration_144h_text",
        "duration_168h_text",
        "duration_200h_text",
    )
    preferred_key = _HOURS_TO_KEY.get(duration_hours)
    order = [preferred_key] if preferred_key else []
    for key in _ALL_KEYS:
        if key not in order:
            order.append(key)
    for key in order:
        txt = d.sel.get(key)
        if txt and d.is_visible_text(txt):
            d.tap_text(txt, contains=False)
            return
