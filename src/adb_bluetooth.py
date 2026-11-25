"""Phone Bluetooth on / off over adb (2026-11-25, ported from MA-automation).

Three ways, tried in order until bluetooth_on reads the wanted value:
  svc bluetooth enable|disable          Pixel and most phones
  cmd bluetooth_manager enable|disable  Android 12+
  Appium Settings broadcast             io.appium.settings (installed with
                                        UiAutomator2) has BLUETOOTH_ADMIN

On the Galaxy A32 (Samsung, Android 11) the first two don't work: `svc
bluetooth disable` is killed (exit 137, the shell lacks BLUETOOTH_ADMIN --
see bt_disconnect's 2026-09-21 note), `cmd bluetooth_manager` prints "No
shell command implementation" with exit 0, and the shell (uid 2000) has no
BLUETOOTH_ADMIN for a direct binder call. The Appium Settings broadcast
turned it off and on (checked on the phone), with no system dialog and
without leaving the app under test.
"""

import subprocess
import time

APPIUM_SETTINGS = [
    "am", "broadcast", "-a", "io.appium.settings.bluetooth",
    "-n", "io.appium.settings/.receivers.BluetoothConnectionSettingReceiver",
    "--es", "setstatus",
]  # fmt: skip


def commands(on: bool) -> list[list[str]]:
    word = "enable" if on else "disable"
    return [
        ["svc", "bluetooth", word],
        ["cmd", "bluetooth_manager", word],
        APPIUM_SETTINGS + [word],
    ]


def accepted(r) -> bool:
    """Did the phone take the command? Exit 0 isn't enough: `cmd` without an
    implementation and a broadcast that didn't complete exit 0 too."""
    out = (r.stdout or b"") + (r.stderr or b"")
    low = (out.encode() if isinstance(out, str) else out).lower()
    if r.returncode != 0:
        return False
    bad = (b"no shell command implementation", b"error", b"exception", b"killed")
    if any(w in low for w in bad):
        return False
    if b"broadcasting:" in low and b"broadcast completed" not in low:
        return False
    return True


def state(adb: list, run=None) -> str | None:
    """ "1" on / "0" off (BLE-only counts as off), None unreadable."""
    run = run or subprocess.run
    try:
        out = run(
            adb + ["shell", "settings", "get", "global", "bluetooth_on"],
            capture_output=True, text=True, timeout=10,
        ).stdout.strip()  # fmt: skip
        if out in ("0", "1"):
            return out
        out = run(
            adb + ["shell", "dumpsys", "bluetooth_manager"],
            capture_output=True, text=True, timeout=10,
        ).stdout  # fmt: skip
    except Exception:
        return None
    for line in (out or "").splitlines():
        if line.strip().lower().startswith("enabled:"):
            return "0" if "false" in line.lower() else "1"
    return None


def set_bluetooth(
    adb: list, on: bool, wait_sec: float = 30, poll: float = 2.0, run=None, sleep=None
) -> tuple[str | None, bool]:
    """Turn Bluetooth on / off, trying each way until the phone reads it so.
    -> (the way that did it or "already", None if none; whether any command
    was taken at all -- False points at adb itself, not the phone)."""
    run, sleep = run or subprocess.run, sleep or time.sleep
    want = "1" if on else "0"
    if state(adb, run) == want:
        return "already", True
    any_taken = False
    for cmd in commands(on):
        try:
            r = run(adb + ["shell"] + cmd, capture_output=True, timeout=15)
        except Exception:
            continue
        if not accepted(r):
            continue
        any_taken = True
        for _ in range(max(1, int(wait_sec / poll))):
            sleep(poll)
            if state(adb, run) == want:
                if cmd[0] == "am":
                    return "Appium Settings broadcast", True
                return " ".join(cmd[:3]), True
    return None, any_taken
