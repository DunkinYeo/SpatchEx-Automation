"""Best-effort, idempotent measurement start flow.

Video observed (iOS) strings:
- 개인정보 수집 및 이용 동의서 -> 동의
- 나의 검사 내역 -> S-Patch 사용하기
- 검사 기간을 선택해주세요. -> 24/48/72 -> 확인
- spinner 잠시 기다려주세요...
- main running screen -> 증상 추가
"""

from src.android.driver import AndroidDriver
from src.utils.retry import retry

@retry(tries=3, delay=3)
def ensure_measurement_started(d: AndroidDriver):
    d.reporter.log_event("ensure_measurement_started", {})

    # If already running, symptom button exists.
    symptom_btn = d.sel.get("symptom_add_text", "증상 추가")
    if d.is_visible_text(symptom_btn):
        return

    # Consent
    agree = d.sel.get("consent_agree_text", "동의")
    if d.is_visible_text(agree):
        d.tap_text(agree)

    # Use device
    use_text = d.sel.get("use_spatch_text", "S-Patch 사용하기")
    if d.is_visible_text(use_text):
        d.tap_text(use_text)

    # Duration sheet
    sheet_title = d.sel.get("duration_sheet_title", "검사 기간을 선택해주세요.")
    if d.is_visible_text(sheet_title):
        # pick duration by run config? For MVP choose 24h if exists, else 48/72.
        for key in ("duration_24h_text","duration_48h_text","duration_72h_text"):
            txt = d.sel.get(key)
            if txt and d.is_visible_text(txt):
                d.tap_text(txt, contains=False)
                break
        confirm = d.sel.get("confirm_text", "확인")
        if d.is_visible_text(confirm):
            d.tap_text(confirm, contains=False)

    # Wait until symptom button appears (running screen)
    d.bring_to_foreground()
    d.wait_idle(2.0)
    if not d.is_visible_text(symptom_btn):
        # last attempt: wait a little more
        d.wait_idle(5.0)

    if not d.is_visible_text(symptom_btn):
        d.screenshot("measurement_start_failed")
        raise RuntimeError("Could not confirm measurement running (symptom button not visible).")
