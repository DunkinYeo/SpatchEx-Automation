"""
Best-effort, idempotent measurement start flow.

Supported paths:
  A) Already running      → '증상 추가' visible → return immediately
  B) Home screen          → 'Start Now' → consent → S-Patch 사용하기 → duration → 확인
  C) Offline mode         → offline notice visible → check consent checkbox
                            → S-Patch 사용하기 → duration → 확인

Offline detection:
  The YAML key `offline_mode_text` (default: "오프라인") is checked first.
  If visible, the offline consent checkbox is ticked before proceeding.
"""

from src.android.driver import AndroidDriver
from src.utils.retry import retry


@retry(tries=3, delay=3)
def ensure_measurement_started(d: AndroidDriver):
    d.reporter.log_event("ensure_measurement_started", {})

    # ── 0. Ensure app is in foreground ────────────────────────────────
    d.bring_to_foreground()
    d.wait_idle(1.5)

    # ── A. Already running? ───────────────────────────────────────────
    symptom_btn = d.sel.get("symptom_add_text", "증상 추가")
    if d.is_visible_text(symptom_btn):
        d.reporter.log_event("measurement_already_running", {})
        return

    # ── B. Home screen → tap "Start Now" first ────────────────────────
    start_now = d.sel.get("start_now_text", "Start Now")
    if d.is_visible_text(start_now):
        d.reporter.log_event("tapping_start_now", {})
        d.tap_text(start_now, contains=False)
        d.wait_idle(2.0)

    # ── Consent screen ────────────────────────────────────────────────
    agree = d.sel.get("consent_agree_text", "동의")
    if d.is_visible_text(agree):
        d.tap_text(agree)

    # ── Offline branch ────────────────────────────────────────────────
    offline_text = d.sel.get("offline_mode_text", "오프라인")
    if d.is_visible_text(offline_text):
        d.reporter.log_event("offline_mode_detected", {})
        _handle_offline_consent(d)

    # ── "S-Patch 사용하기" ─────────────────────────────────────────────
    use_text = d.sel.get("use_spatch_text", "S-Patch 사용하기")
    if d.is_visible_text(use_text):
        d.tap_text(use_text)

    # ── Duration sheet ────────────────────────────────────────────────
    sheet_title = d.sel.get("duration_sheet_title", "검사 기간을 선택해주세요")
    if d.is_visible_text(sheet_title):
        _select_duration(d)
        confirm = d.sel.get("confirm_text", "확인")
        if d.is_visible_text(confirm):
            d.tap_text(confirm, contains=False)

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
    offline_agree = d.sel.get("offline_agree_text", "동의합니다")
    if d.is_visible_text(offline_agree):
        d.tap_text(offline_agree, contains=True)

    # Some apps show a separate confirm button for offline consent
    offline_confirm = d.sel.get("offline_confirm_text")
    if offline_confirm and d.is_visible_text(offline_confirm):
        d.tap_text(offline_confirm, contains=True)


def _select_duration(d: AndroidDriver):
    """
    Select the configured duration option (prefers 24 h → 48 h → 72 h).
    """
    for key in ("duration_24h_text", "duration_48h_text", "duration_72h_text"):
        txt = d.sel.get(key)
        if txt and d.is_visible_text(txt):
            d.tap_text(txt, contains=False)
            return
