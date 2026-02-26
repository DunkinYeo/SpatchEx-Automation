import argparse
import datetime
import os
import random
import time
import yaml

from src.android.driver import AndroidDriver
from src.orchestrator.scheduler import LongRunScheduler
from src.orchestrator.reporting import RunReporter
from src.workflows.measurement_start import ensure_measurement_started
from src.workflows.symptom_inject import inject_symptom_event
from src.utils.artifacts import ArtifactManager
from src.utils.slack import slack_notify


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

    reporter.log_event("run_start", {"platform": platform, "duration_hours": duration_hours, "interval_hours": interval_hours})

    try:
        if platform != "android":
            raise RuntimeError("Only android is implemented in MVP. Set platform: android")

        a_cfg = cfg.get("android") or {}
        sel = (cfg.get("selectors") or {}).get("android") or {}

        driver = AndroidDriver(a_cfg, sel, artifacts=artifacts, reporter=reporter)

        # 1) Ensure measurement running (idempotent)
        ensure_measurement_started(driver)
        reporter.log_event("measurement_started", {})

        # 2) Schedule symptom injections
        plan = cfg.get("symptom_plan") or []
        catalog = cfg.get("symptom_catalog") or []

        scheduler = LongRunScheduler(
            duration_hours=duration_hours,
            interval_hours=interval_hours,
            start_immediately=start_immediately,
            plan=plan,
            catalog=catalog,
            reporter=reporter,
        )

        def job(at_hour: float | None = None, payload: dict | None = None):
            # choose symptoms
            payload = payload or {}
            symptoms = payload.get("symptoms") or []
            other_text = payload.get("other_text") or ""
            activities = payload.get("activities") or []
            if not symptoms:
                # random symptom (avoid empty)
                pick = random.choice(catalog) if catalog else "두근거림"
                symptoms = [pick]

            inject_symptom_event(driver, symptoms=symptoms, other_text=other_text, activities=activities)

        scheduler.run(job)

        reporter.log_event("run_complete", {"status": "ok"})
    except Exception as e:
        reporter.log_event("run_failed", {"error": str(e)})
        raise
    finally:
        try:
            reporter.render_html_summary()
        except Exception:
            pass
        try:
            if cfg.get("slack", {}).get("enabled") and cfg.get("slack", {}).get("webhook_url"):
                slack_notify(cfg["slack"]["webhook_url"], f"✅ Long-run automation finished: {run_id}")
        except Exception:
            pass


if __name__ == "__main__":
    main()
