"""
Inject a symptom event while the measurement is running.

Artifact policy (every injection):
  - screenshot  before tapping '증상 추가'
  - screenshot  after  symptom picker closes
  - screenshot  after  journal submission
  - adb logcat  after  submission
  - JSONL event with elapsed_sec + success/failure

On failure:
  - extra screenshot of current screen
  - last successful step is recorded in JSONL
"""

import time

from src.android.driver import AndroidDriver
from src.utils.retry import retry


@retry(tries=3, delay=3)
def inject_symptom_event(
    d: AndroidDriver,
    symptoms: list[str],
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

        # ── 3. Open symptom picker ────────────────────────────────────
        symptom_add = d.sel.get("symptom_add_text", "증상 추가")
        d.tap_text(symptom_add, timeout=15, contains=True)
        d.screenshot("symptom_picker_open")
        last_step = "picker_open"

        # ── 4. Select each symptom ────────────────────────────────────
        for s in symptoms:
            d.tap_text(s, timeout=10, contains=True)
        last_step = "symptoms_selected"

        # ── 5. Handle '기타' free-text input ──────────────────────────
        if other_text:
            _enter_other_text(d, other_text)
            last_step = "other_text_entered"

        # ── 6. Submit symptom picker ("증상 추가" confirm button) ──────
        # The picker has a "증상 추가" submit button at the bottom.
        # Wait briefly so the selection animation settles.
        d.wait_idle(0.5)
        symptom_confirm = d.sel.get("symptom_confirm_text", "증상 추가")
        d.tap_text(symptom_confirm, timeout=10, contains=True)
        d.screenshot("symptom_picker_submitted")
        last_step = "picker_submitted"

        # ── 7. Journal submission screen ──────────────────────────────
        submit = d.sel.get("symptom_done_text", "환자일지 등록")
        d.tap_text(submit, timeout=15, contains=True)
        d.screenshot("journal_submitted")
        last_step = "journal_submitted"

        # ── 8. Optional: add activities ───────────────────────────────
        if activities:
            _add_activities(d, activities)
            last_step = "activities_added"

        # ── 9. Screenshot AFTER + logcat ─────────────────────────────
        d.screenshot("inject_after")
        d.logcat("inject_logcat")

        elapsed = round(time.monotonic() - t_start, 1)
        d.reporter.log_event(
            "inject_symptom_done",
            {"status": "ok", "elapsed_sec": elapsed, "last_step": last_step},
        )

    except Exception as exc:
        elapsed = round(time.monotonic() - t_start, 1)
        # Capture failure evidence
        try:
            d.screenshot("inject_failed_screen")
            d.logcat("inject_failed_logcat")
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


def _enter_other_text(d: AndroidDriver, text: str):
    """
    Tap the '기타' input field and type free text.
    Selector priority: other_text_field_id (resource-id) > '기타' text tile.
    """
    field_id = d.sel.get("other_text_field_id")
    if field_id:
        el = d.find(field_id, timeout=5, contains=False)
    else:
        # Fall back: tap the '기타' tile which opens the text input
        d.tap_text("기타", timeout=5, contains=True)
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
    keyboard_done = d.sel.get("keyboard_done_text", "완료")
    if d.is_visible_text(keyboard_done):
        d.tap_text(keyboard_done, timeout=3, contains=False)
    else:
        try:
            d.drv.hide_keyboard()
        except Exception:
            pass


def _add_activities(d: AndroidDriver, activities: list[str]):
    add_act = d.sel.get("add_activity_text", "활동 추가")
    if not d.is_visible_text(add_act):
        return

    d.tap_text(add_act, timeout=10, contains=True)

    for a in activities:
        d.tap_text(a, timeout=10, contains=True)

    act_submit = d.sel.get("activity_submit_text", "활동 추가")
    if d.is_visible_text(act_submit):
        d.tap_text(act_submit, timeout=10, contains=True)

    d.screenshot("activity_added")
