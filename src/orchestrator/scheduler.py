"""
Long-run scheduler.

Drift prevention strategy:
- plan mode  : each job is a one-shot `date` trigger at an absolute wall-clock time.
- interval mode: after every successful execution, the *next* job is re-registered
  as a new `date` trigger (start_time + N * interval). This avoids APScheduler
  interval drift caused by execution time or system sleep.

Session health is checked before every job via driver.ensure_session().
"""

import datetime

from apscheduler.schedulers.blocking import BlockingScheduler
from apscheduler.schedulers.background import BackgroundScheduler


class LongRunScheduler:
    def __init__(
        self,
        duration_hours: int,
        interval_hours: float,
        start_immediately: bool,
        plan: list,
        catalog: list,
        reporter,
    ):
        self.duration_hours = duration_hours
        self.interval_hours = interval_hours
        self.start_immediately = start_immediately
        self.plan = plan
        self.catalog = catalog
        self.reporter = reporter

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
        # Log sleep prevention warning at the start
        self.reporter.log_event(
            "scheduler_started",
            {
                "duration_hours": self.duration_hours,
                "start_time": start.isoformat(),
                "end_time": end.isoformat(),
                "warning": "PC must remain powered on and awake; disable sleep/suspend/hibernation",
            },
        )

        sched = BlockingScheduler()

        for item in self.plan:
            at = float(item.get("at_hour", 0))
            when = start + datetime.timedelta(hours=at)
            if when > end:
                continue  # outside the run window

            payload = {
                "symptoms": item.get("symptoms"),
                "other_text": item.get("other_text", ""),
                "activities": item.get("activities") or [],
            }
            self.reporter.log_event(
                "schedule_add",
                {"type": "plan", "at_hour": at, "run_at": when.isoformat()},
            )

            def _make_job(at_h, p):
                def _job():
                    _run_with_health_check(job_callable, driver, at_h, p, self.reporter)

                return _job

            sched.add_job(_make_job(at, payload), "date", run_date=when)

        # Add a sentinel job at `end` to stop the scheduler cleanly.
        sched.add_job(lambda: sched.shutdown(wait=False), "date", run_date=end)
        sched.start()

    # ------------------------------------------------------------------
    # Interval mode — drift-free re-registration
    # ------------------------------------------------------------------

    def _run_interval(self, job_callable, driver, start, end):
        sched = BackgroundScheduler()
        counter = [0]  # mutable ref for closure

        def _schedule_next():
            counter[0] += 1
            offset_hours = counter[0] * self.interval_hours
            next_run = start + datetime.timedelta(hours=offset_hours)
            if next_run >= end:
                return  # no more jobs within the run window

            self.reporter.log_event(
                "schedule_add",
                {
                    "type": "interval",
                    "index": counter[0],
                    "run_at": next_run.isoformat(),
                },
            )

            def _job():
                _run_with_health_check(job_callable, driver, None, None, self.reporter)
                _schedule_next()  # register the next execution after this one finishes

            sched.add_job(_job, "date", run_date=next_run)

        # Log sleep prevention warning at the start
        self.reporter.log_event(
            "scheduler_started",
            {
                "duration_hours": self.duration_hours,
                "interval_hours": self.interval_hours,
                "start_time": start.isoformat(),
                "end_time": end.isoformat(),
                "warning": "PC must remain powered on and awake; disable sleep/suspend/hibernation",
            },
        )

        # Optionally fire the first job immediately (a few seconds in).
        if self.start_immediately:
            first_run = datetime.datetime.now() + datetime.timedelta(seconds=5)
            self.reporter.log_event(
                "schedule_add",
                {"type": "interval_immediate", "run_at": first_run.isoformat()},
            )

            def _first_job():
                _run_with_health_check(job_callable, driver, None, None, self.reporter)
                _schedule_next()

            sched.add_job(_first_job, "date", run_date=first_run)
        else:
            _schedule_next()

        sched.start()

        # Block main thread until the run window closes.
        import time

        while datetime.datetime.now() < end:
            time.sleep(10)

        sched.shutdown(wait=True)


# ------------------------------------------------------------------
# Shared helper
# ------------------------------------------------------------------


def _run_with_health_check(job_callable, driver, at_hour, payload, reporter):
    """
    Ensure session is alive before running the job.
    If session is dead, attempt 3-step recovery before giving up.
    """
    if driver is not None:
        try:
            driver.ensure_session()
        except Exception as e:
            reporter.log_event("session_check_failed", {"error": str(e)})
            # Attempt 3-step recovery
            for recovery_step in [1, 2, 3]:
                try:
                    success = driver.recover_session(step=recovery_step)
                    if success:
                        # Verify recovery
                        driver.ensure_session()
                        reporter.log_event("session_recovered", {"recovery_step": recovery_step})
                        break
                except Exception as recovery_error:
                    reporter.log_event(
                        "recovery_step_error",
                        {"step": recovery_step, "error": str(recovery_error)},
                    )
            else:
                # All recovery steps failed
                reporter.log_event("session_recovery_failed", {"tried_steps": 3})

    job_callable(at_hour=at_hour, payload=payload)
