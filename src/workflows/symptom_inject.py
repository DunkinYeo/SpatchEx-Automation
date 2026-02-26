"""Inject symptom event while measurement is running.

Observed screens (from provided video):
- Main running: bottom button '증상 추가'
- Symptom picker: '증상을 선택해주세요.' with icon tiles (e.g., 두근거림, 가슴 통증, 어지러움, 호흡 가쁨)
- Journal entry: shows selected symptoms; bottom '환자일지 등록'
- Optional activity: '활동 추가' with chips; bottom '활동 추가'
"""

from src.android.driver import AndroidDriver
from src.utils.retry import retry

@retry(tries=3, delay=3)
def inject_symptom_event(d: AndroidDriver, symptoms: list[str], other_text: str = "", activities: list[str] | None = None):
    activities = activities or []
    d.reporter.log_event("inject_symptom_start", {"symptoms": symptoms, "other_text": other_text, "activities": activities})

    d.bring_to_foreground()
    d.wait_idle(1.0)

    symptom_add = d.sel.get("symptom_add_text", "증상 추가")
    d.tap_text(symptom_add, timeout=15, contains=True)
    d.screenshot("symptom_picker_open")

    # pick each symptom by text (icon label)
    for s in symptoms:
        if s == "기타":
            # If your UI has a dedicated "기타" tile, keep as text tap.
            d.tap_text("기타", timeout=10, contains=True)
        else:
            d.tap_text(s, timeout=10, contains=True)

    # TODO: other_text entry depends on app UI; placeholder hook:
    # If there is an "기타" input field, you can add resource-id into YAML and implement here.

    # Submit journal
    submit = d.sel.get("symptom_done_text", "환자일지 등록")
    d.tap_text(submit, timeout=15, contains=True)
    d.screenshot("journal_submitted")

    # Optional: add activity
    if activities:
        add_act = d.sel.get("add_activity_text", "활동 추가")
        if d.is_visible_text(add_act):
            d.tap_text(add_act, timeout=10, contains=True)
            for a in activities:
                d.tap_text(a, timeout=10, contains=True)
            act_submit = d.sel.get("activity_submit_text", "활동 추가")
            if d.is_visible_text(act_submit):
                d.tap_text(act_submit, timeout=10, contains=True)
            d.screenshot("activity_added")

    d.reporter.log_event("inject_symptom_done", {})
