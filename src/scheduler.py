"""
Long-run scheduler.

Drift prevention strategy:
- plan mode  : each job is a one-shot `date` trigger at an absolute wall-clock time.
- interval mode: after every successful execution, the *next* job is re-registered
  as a new `date` trigger (start_time + N * interval). This avoids APScheduler
  interval drift caused by execution time or system sleep.

Pre-job health checks (in order):
  1. Appium session alive     — driver.ensure_session()
  2. App brought to foreground — driver.bring_to_foreground()
  3. UI health assert          — driver.assert_ui_health()
     (checks that the measurement screen is unobstructed)
Any check failure triggers 3-step escalating recovery before the job runs.
"""

import dataclasses
import datetime
import random
import time

from apscheduler.schedulers.blocking import BlockingScheduler
from apscheduler.schedulers.background import BackgroundScheduler


# ------------------------------------------------------------------
# Job result
# ------------------------------------------------------------------

@dataclasses.dataclass
class JobResult:
    """Structured outcome returned (and logged) for every scheduled job."""
    job_name: str
    success: bool
    start_ts: str
    end_ts: str = ""
    attempt: int = 1
    reason: str = ""
    artifact_paths: list = dataclasses.field(default_factory=list)


# ------------------------------------------------------------------
# Scheduler
# ------------------------------------------------------------------

class LongRunScheduler:
    def __init__(
        self,
        duration_hours: int,
        interval_hours: float,
        start_immediately: bool,
        plan: list,
        catalog: list,
        reporter,
        jitter_seconds: float = 0,
        quiet_hours: dict = None,
        recovery_cfg: dict = None,
    ):
        self.duration_hours = duration_hours
        self.interval_hours = interval_hours
        self.start_immediately = start_immediately
        self.plan = plan
        self.catalog = catalog
        self.reporter = reporter
        self.jitter_seconds = float(jitter_seconds or 0)
        self.quiet_hours = quiet_hours or {}
        self.recovery_cfg = recovery_cfg or {}

    def run(self, job_callable, driver=None):
        """
        Block until the run duration has elapsed.

        Args:
            job_callable: called with (at_hour, payload) kwargs.
            driver: AndroidDriver instance (optional) used for session health checks.
        """
        start = datetime.datetime.now()
        end = start + datetime.timedelta(hours=self.duration_hours)

        if self.plan:
            self._run_plan(job_callable, driver, start, end)
        else:
            self._run_interval(job_callable, driver, start, end)

    # ------------------------------------------------------------------
    # Plan mode — absolute time offsets
    # ------------------------------------------------------------------

    def _run_plan(self, job_callable, driver, start, end):
        self.reporter.log_event(
            "scheduler_started",
            {
                "mode": "plan",
                "duration_hours": self.duration_hours,
                "start_time": start.isoformat(),
                "end_time": end.isoformat(),
                "jitter_seconds": self.jitter_seconds,
                "quiet_hours": self.quiet_hours,
                "warning": "PC must remain powered on and awake; disable sleep/suspend/hibernation",
            },
        )

        sched = BlockingScheduler()
        cooldown = int(self.recovery_cfg.get("cooldown_seconds_between_steps", 30))

        for item in self.plan:
            at = float(item.get("at_hour", 0))
            jitter = random.uniform(-self.jitter_seconds, self.jitter_seconds) if self.jitter_seconds else 0
            when = start + datetime.timedelta(hours=at) + datetime.timedelta(seconds=jitter)

            if when > end:
                continue

            if _is_quiet_hour(when, self.quiet_hours):
                self.reporter.log_event(
                    "job_skipped_quiet_hours",
                    {"at_hour": at, "run_at": when.isoformat(), "quiet_hours": self.quiet_hours},
                )
                continue

            payload = {
                "symptoms": item.get("symptoms"),
                "other_text": item.get("other_text", ""),
                "activities": item.get("activities") or [],
            }
            self.reporter.log_event(
                "schedule_add",
                {"type": "plan", "at_hour": at, "run_at": when.isoformat(), "jitter_sec": round(jitter, 1)},
            )

            def _make_job(at_h, p, cd):
                def _job():
                    _run_with_health_check(job_callable, driver, at_h, p, self.reporter, cd)
                return _job

            sched.add_job(_make_job(at, payload, cooldown), "date", run_date=when)

        sched.add_job(lambda: sched.shutdown(wait=False), "date", run_date=end)
        sched.start()

    # ------------------------------------------------------------------
    # Interval mode — drift-free re-registration
    # ------------------------------------------------------------------

    def _run_interval(self, job_callable, driver, start, end):
        sched = BackgroundScheduler()
        counter = [0]
        cooldown = int(self.recovery_cfg.get("cooldown_seconds_between_steps", 30))

        def _schedule_next():
            counter[0] += 1
            offset_hours = counter[0] * self.interval_hours
            jitter = random.uniform(-self.jitter_seconds, self.jitter_seconds) if self.jitter_seconds else 0
            next_run = start + datetime.timedelta(hours=offset_hours) + datetime.timedelta(seconds=jitter)

            if next_run >= end:
                return

            self.reporter.log_event(
                "schedule_add",
                {
                    "type": "interval",
                    "index": counter[0],
                    "run_at": next_run.isoformat(),
                    "jitter_sec": round(jitter, 1),
                },
            )

            def _job():
                # Check quiet hours at run time (interval jobs are chained dynamically)
                if _is_quiet_hour(datetime.datetime.now(), self.quiet_hours):
                    self.reporter.log_event(
                        "job_skipped_quiet_hours",
                        {"index": counter[0], "quiet_hours": self.quiet_hours},
                    )
                else:
                    _run_with_health_check(job_callable, driver, None, None, self.reporter, cooldown)
                _schedule_next()

            sched.add_job(_job, "date", run_date=next_run)

        self.reporter.log_event(
            "scheduler_started",
            {
                "mode": "interval",
                "duration_hours": self.duration_hours,
                "interval_hours": self.interval_hours,
                "start_time": start.isoformat(),
                "end_time": end.isoformat(),
                "jitter_seconds": self.jitter_seconds,
                "quiet_hours": self.quiet_hours,
                "warning": "PC must remain powered on and awake; disable sleep/suspend/hibernation",
            },
        )

        if self.start_immediately:
            first_run = datetime.datetime.now() + datetime.timedelta(seconds=5)
            self.reporter.log_event(
                "schedule_add",
                {"type": "interval_immediate", "run_at": first_run.isoformat()},
            )

            def _first_job():
                _run_with_health_check(job_callable, driver, None, None, self.reporter, cooldown)
                _schedule_next()

            sched.add_job(_first_job, "date", run_date=first_run)
        else:
            _schedule_next()

        sched.start()

        while datetime.datetime.now() < end:
            time.sleep(10)

        sched.shutdown(wait=True)


# ------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------


def _is_quiet_hour(dt: datetime.datetime, quiet_hours: dict) -> bool:
    """Return True if dt falls within the configured quiet window."""
    if not quiet_hours:
        return False
    start = quiet_hours.get("start")
    end = quiet_hours.get("end")
    if start is None or end is None:
        return False
    h = dt.hour + dt.minute / 60.0
    if start <= end:          # same-day window, e.g. 02:00–06:00
        return start <= h < end
    else:                     # overnight window, e.g. 23:00–06:00
        return h >= start or h < end


def _run_with_health_check(job_callable, driver, at_hour, payload, reporter, cooldown_seconds=30):
    """
    Run pre-job health checks then execute the job.
    Returns a JobResult; also emits job_result event to the reporter.

    Checks (in order):
      1. Appium session alive
      2. Bring app to foreground
      3. UI health assert (measurement screen unobstructed)
    Any failure triggers 3-step escalating recovery with cooldown+recheck.
    """
    start_ts = datetime.datetime.now().isoformat(timespec="seconds")
    result = JobResult(
        job_name="symptom_inject",
        success=False,
        start_ts=start_ts,
    )
    reporter.log_event("job_start", {"at_hour": at_hour, "start_ts": start_ts})

    if driver is not None:
        # 1. Session check
        try:
            driver.ensure_session()
        except Exception as e:
            reporter.log_event("session_check_failed", {"error": str(e)})
            _attempt_recovery(driver, reporter, cooldown_seconds)

        # 2. Bring app to foreground
        driver.bring_to_foreground()
        driver.wait_idle(1.0)

        # 3. UI health check
        try:
            driver.assert_ui_health()
        except Exception as e:
            reporter.log_event("ui_health_check_failed", {"error": str(e)})
            _attempt_recovery(driver, reporter, cooldown_seconds)

    try:
        job_callable(at_hour=at_hour, payload=payload)
        result.success = True
        result.reason = "ok"
    except Exception as e:
        result.success = False
        result.reason = str(e)
        reporter.log_event("job_failed", {"error": str(e), "at_hour": at_hour})
        raise
    finally:
        result.end_ts = datetime.datetime.now().isoformat(timespec="seconds")
        reporter.log_event("job_result", dataclasses.asdict(result))

    return result


def _attempt_recovery(driver, reporter, cooldown_seconds=30):
    """
    3-step escalating recovery with cooldown + UI re-check after each step.

    Step 1: back key + short wait
    Step 2: start_activity (force relaunch)
    Step 3: terminate + activate (kill/relaunch)

    After each step: wait cooldown_seconds, then re-check UI health.
    Returns as soon as a step results in a healthy UI.
    """
    for step in [1, 2, 3]:
        reporter.log_event("recovery_step_start", {"step": step})
        try:
            driver.recover_session(step=step)
        except Exception as e:
            reporter.log_event("recovery_step_error", {"step": step, "error": str(e)})
            continue

        # Wait for app to stabilize before checking
        time.sleep(cooldown_seconds)

        try:
            driver.ensure_session()
            driver.bring_to_foreground()
            driver.wait_idle(2.0)
            driver.assert_ui_health()
            reporter.log_event("recovery_succeeded", {"step": step})
            return  # healthy — done
        except Exception:
            reporter.log_event("recovery_ui_still_unhealthy", {"step": step})
            # Fall through to next step

    reporter.log_event("session_recovery_failed", {"tried_steps": 3})
