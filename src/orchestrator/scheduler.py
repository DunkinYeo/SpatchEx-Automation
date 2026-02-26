import time
import datetime
from apscheduler.schedulers.background import BackgroundScheduler

class LongRunScheduler:
    def __init__(self, duration_hours: int, interval_hours: float, start_immediately: bool, plan: list, catalog: list, reporter):
        self.duration_hours = duration_hours
        self.interval_hours = interval_hours
        self.start_immediately = start_immediately
        self.plan = plan
        self.catalog = catalog
        self.reporter = reporter

    def run(self, job_callable):
        start = datetime.datetime.now()
        end = start + datetime.timedelta(hours=self.duration_hours)

        # If a plan exists, schedule exact offsets
        sched = BackgroundScheduler()
        if self.plan:
            for item in self.plan:
                at = float(item.get("at_hour", 0))
                when = start + datetime.timedelta(hours=at)
                payload = {k: item.get(k) for k in ("symptoms","other_text","activities")}
                sched.add_job(job_callable, "date", run_date=when, kwargs={"at_hour": at, "payload": payload})
                self.reporter.log_event("schedule_add", {"type":"plan","at_hour": at, "run_at": when.isoformat(), "payload": payload})
        else:
            # interval schedule
            def wrapper():
                job_callable(at_hour=None, payload=None)
            if self.start_immediately:
                sched.add_job(wrapper, "date", run_date=datetime.datetime.now() + datetime.timedelta(seconds=3))
            sched.add_job(wrapper, "interval", hours=self.interval_hours, next_run_time=datetime.datetime.now() + datetime.timedelta(hours=self.interval_hours))
            self.reporter.log_event("schedule_add", {"type":"interval","hours": self.interval_hours})

        sched.start()

        # Block until end
        while datetime.datetime.now() < end:
            time.sleep(5)

        sched.shutdown(wait=False)
