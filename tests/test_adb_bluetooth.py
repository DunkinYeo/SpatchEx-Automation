"""Phone Bluetooth over adb (2026-11-25, ported from MA-automation). The
Galaxy A32 (Samsung, Android 11) answers exactly as recorded here: `svc
bluetooth disable` is killed (exit 137), `cmd bluetooth_manager disable`
prints "No shell command implementation" with exit 0, and only the Appium
Settings broadcast turns it off (bluetooth_on 0) and back on.

No real adb is ever run: every test hands in (or monkeypatches) a fake."""

from types import SimpleNamespace

import pytest

import src.workflows.bt_disconnect as btd
from src.adb_bluetooth import accepted, set_bluetooth

UDID = "RF9R503211R"
ADB = ["adb", "-s", UDID]


def _no_sleep(_s):
    return None


class Phone:
    """Answers adb like a phone; `works` = the ways that really switch BT."""

    def __init__(self, works, bt="1"):
        self.works, self.bt, self.calls = set(works), bt, []

    def __call__(self, cmd, **kw):
        sh = cmd[3:] if cmd[:3] == ADB else cmd[1:]
        sh = sh[1:] if sh and sh[0] == "shell" else sh
        self.calls.append(" ".join(sh[:3]))

        def r(out="", err="", rc=0):
            enc = (lambda x: x) if kw.get("text") else (lambda x: x.encode())
            return SimpleNamespace(returncode=rc, stdout=enc(out), stderr=enc(err))

        if sh[:3] == ["settings", "get", "global"]:
            return r(self.bt + "\n")
        if sh[0] not in ("svc", "cmd", "am"):
            # e.g. the consent-dialog fallback's `am start` -- must not happen here
            raise AssertionError(f"unexpected adb call: {sh}")
        word = sh[-1]
        if sh[0] == "svc":
            if "svc" not in self.works:
                return r(err="Killed\n", rc=137)
        elif sh[0] == "cmd":
            if "cmd" not in self.works:
                return r(out="No shell command implementation.\n")
        elif sh[0] == "am":
            if sh[1] != "broadcast":
                raise AssertionError(f"unexpected adb call: {sh}")
            if "appium" not in self.works:
                return r(out="Broadcasting: Intent { ... }\n")  # never completed
            self.bt = "1" if word == "enable" else "0"
            return r(
                out="Broadcasting: Intent { ... }\nBroadcast completed: result=-1\n"
            )
        self.bt = "1" if word == "enable" else "0"
        return r()


def test_a32_answers_aren_t_taken_for_success():
    k = SimpleNamespace(returncode=137, stdout=b"", stderr=b"Killed\n")
    n = SimpleNamespace(
        returncode=0, stdout=b"No shell command implementation.\n", stderr=b""
    )
    ok = SimpleNamespace(
        returncode=0,
        stdout=b"Broadcasting: x\nBroadcast completed: result=-1\n",
        stderr=b"",
    )
    assert not accepted(k) and not accepted(n) and accepted(ok)


def test_a32_turns_off_and_on_through_appium_settings():
    p = Phone(works={"appium"})
    assert set_bluetooth(ADB, on=False, run=p, sleep=_no_sleep) == (
        "Appium Settings broadcast",
        True,
    )
    assert p.bt == "0"
    assert set_bluetooth(ADB, on=True, run=p, sleep=_no_sleep) == (
        "Appium Settings broadcast",
        True,
    )
    assert p.bt == "1"


def test_pixel_uses_svc_and_never_needs_the_broadcast():
    p = Phone(works={"svc"})
    assert (
        set_bluetooth(ADB, on=False, run=p, sleep=_no_sleep)[0]
        == "svc bluetooth disable"
    )
    assert not any(c.startswith("am ") for c in p.calls)


def test_nothing_works_is_none_and_no_command_taken():
    p = Phone(works=set())
    assert set_bluetooth(ADB, on=False, run=p, sleep=_no_sleep, wait_sec=4) == (
        None,
        False,
    )


def test_already_in_the_wanted_state_sends_nothing():
    p = Phone(works={"svc"}, bt="0")
    assert set_bluetooth(ADB, on=False, run=p, sleep=_no_sleep) == ("already", True)
    assert p.calls == ["settings get global"]


class FakeDriver:
    def __init__(self):
        self.cfg = {"udid": UDID}
        self.foregrounded = 0

    def wait_idle(self, _s):
        pass

    def bring_to_foreground(self):
        self.foregrounded += 1


@pytest.fixture
def a32(monkeypatch):
    p = Phone(works={"appium"})
    monkeypatch.setattr("subprocess.run", p)
    monkeypatch.setattr("time.sleep", _no_sleep)
    return p


def test_bt_disconnect_toggle_works_on_the_a32_without_the_consent_dialog(a32):
    drv = FakeDriver()
    assert btd._toggle_bluetooth(drv, enable=False) == (True, "")
    assert a32.bt == "0"
    assert btd._toggle_bluetooth(drv, enable=True) == (True, "")
    assert a32.bt == "1"
    # The consent-dialog fallback (am start + tap + re-foreground) never ran.
    assert drv.foregrounded == 0
    assert not any(c.startswith("am start") for c in a32.calls)


def test_consent_dialog_is_still_the_last_resort(monkeypatch):
    p = Phone(works=set())
    started = []

    def run(cmd, **kw):
        if cmd[4:6] == ["am", "start"]:
            started.append(cmd[-1])
            return SimpleNamespace(returncode=0, stdout=b"", stderr=b"")
        return p(cmd, **kw)

    monkeypatch.setattr("subprocess.run", run)
    monkeypatch.setattr("time.sleep", _no_sleep)
    drv = FakeDriver()
    drv.dump_ui_xml_via_adb = lambda: None  # no Allow button found
    drv.drv = SimpleNamespace(page_source=None)
    ok, err = btd._toggle_bluetooth(drv, enable=False)
    assert not ok and "still on" in err
    assert started == ["android.bluetooth.adapter.action.REQUEST_DISABLE"]
    assert drv.foregrounded == 1
