import argparse
import datetime
import os
import random

import yaml

from src.android.driver import AndroidDriver
from src.orchestrator.reporting import RunReporter
from src.orchestrator.scheduler import LongRunScheduler
from src.utils.artifacts import ArtifactManager
from src.utils.slack import slack_notify
from src.workflows.measurement_start import ensure_measurement_started
from src.workflows.symptom_inject import inject_symptom_event


def load_cfg(path: str) -> dict:
    with open(path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--config", required=True, help="Path to run.yaml")
    args = ap.parse_args()

    cfg = load_cfg(args.config)
    platform = (cfg.get("platform") or "android").lower()

    run_cfg = cfg.get("run") or {}
    duration_hours = int(run_cfg.get("duration_hours", 24))
    interval_hours = float(run_cfg.get("symptom_interval_hours", 4))
    start_immediately = bool(run_cfg.get("start_immediately", True))

    run_id = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    out_dir = os.path.join("output", run_id)
    os.makedirs(out_dir, exist_ok=True)

    reporter = RunReporter(out_dir=out_dir, run_name=run_cfg.get("name", "run"))
    artifacts = ArtifactManager(out_dir=out_dir)

    reporter.log_event(
        "run_start",
        {
            "platform": platform,
            "duration_hours": duration_hours,
            "interval_hours": interval_hours,
        },
    )

    driver = None
    try:
        if platform != "android":
            raise RuntimeError(
                "Only android is implemented in MVP. Set platform: android"
            )

        a_cfg = cfg.get("android") or {}
        sel = (cfg.get("selectors") or {}).get("android") or {}
        catalog = cfg.get("symptom_catalog") or []

        driver = AndroidDriver(a_cfg, sel, artifacts=artifacts, reporter=reporter)

        # 1) Ensure measurement is running (idempotent)
        ensure_measurement_started(driver)
        reporter.log_event("measurement_started", {})

        # 2) Build the job callable
        def job(at_hour: float | None = None, payload: dict | None = None):
            payload = payload or {}
            symptoms = payload.get("symptoms") or []
            other_text = payload.get("other_text") or ""
            activities = payload.get("activities") or []
            if not symptoms:
                pick = random.choice(catalog) if catalog else "두근거림"
                symptoms = [pick]
            inject_symptom_event(
                driver,
                symptoms=symptoms,
                other_text=other_text,
                activities=activities,
            )

        # 3) Run scheduler (blocks until duration_hours elapses)
        scheduler = LongRunScheduler(
            duration_hours=duration_hours,
            interval_hours=interval_hours,
            start_immediately=start_immediately,
            plan=cfg.get("symptom_plan") or [],
            catalog=catalog,
            reporter=reporter,
        )
        scheduler.run(job, driver=driver)

        reporter.log_event("run_complete", {"status": "ok"})

    except Exception as e:
        reporter.log_event("run_failed", {"error": str(e)})
        raise

    finally:
        if driver:
            driver.close()
        try:
            reporter.render_html_summary()
        except Exception:
            pass
        slack_cfg = cfg.get("slack") or {}
        if slack_cfg.get("enabled") and slack_cfg.get("webhook_url"):
            slack_notify(
                slack_cfg["webhook_url"],
                f"Long-run automation finished: {run_id}",
            )


if __name__ == "__main__":
    main()
