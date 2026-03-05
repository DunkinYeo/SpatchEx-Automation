import os, json, datetime, threading
from jinja2 import Template

class RunReporter:
    def __init__(self, out_dir: str, run_name: str, hub_url: str = "", tester_name: str = ""):
        self.out_dir = out_dir
        self.run_name = run_name
        self.events_path = os.path.join(out_dir, "events.jsonl")
        self._hub_url = (hub_url or "").rstrip("/")
        self._tester_name = tester_name or run_name

    def log_event(self, event: str, data: dict):
        rec = {
            "ts": datetime.datetime.now().isoformat(timespec="seconds"),
            "event": event,
            "data": data,
        }
        with open(self.events_path, "a", encoding="utf-8") as f:
            f.write(json.dumps(rec, ensure_ascii=False) + "\n")
        if self._hub_url:
            self._forward_to_hub(rec)

    def _forward_to_hub(self, rec: dict):
        payload = {**rec, "tester_name": self._tester_name}
        def _send():
            try:
                import urllib.request
                body = json.dumps(payload, ensure_ascii=False).encode()
                req = urllib.request.Request(
                    f"{self._hub_url}/api/hub/events",
                    data=body,
                    headers={"Content-Type": "application/json"},
                    method="POST",
                )
                urllib.request.urlopen(req, timeout=3)
            except Exception:
                pass  # never block the test on hub failures
        threading.Thread(target=_send, daemon=True).start()

    def render_html_summary(self):
        events = []
        if os.path.exists(self.events_path):
            with open(self.events_path, "r", encoding="utf-8") as f:
                for line in f:
                    try:
                        events.append(json.loads(line))
                    except Exception:
                        pass

        # ── Summary stats ─────────────────────────────────────────────────
        job_results     = [e for e in events if e["event"] == "job_result"]
        injections_ok   = sum(1 for e in job_results if e["data"].get("success"))
        injections_fail = len(job_results) - injections_ok
        run_start_ts    = next((e["ts"] for e in events if e["event"] == "run_start"), "")
        run_end_ts      = next(
            (e["ts"] for e in events if e["event"] in ("run_complete", "run_failed")), ""
        )
        device_info  = next((e["data"] for e in events if e["event"] == "device_info"), {})
        overall_ok   = injections_fail == 0 and any(e["event"] == "run_complete" for e in events)

        FAIL_EVENTS = {
            "job_failed", "inject_symptom_failed", "session_recovery_failed",
            "ui_health_check_failed", "run_failed",
        }
        WARN_EVENTS = {
            "recovery_step_start", "recovery_succeeded", "recovery_ui_still_unhealthy",
            "job_skipped_quiet_hours",
        }
        OK_EVENTS = {
            "inject_symptom_done", "job_result", "measurement_confirmed_running",
            "once_inject_done", "run_complete",
        }

        def row_class(e):
            ev = e["event"]
            if ev in FAIL_EVENTS: return "row-fail"
            if ev in WARN_EVENTS: return "row-warn"
            if ev in OK_EVENTS:   return "row-ok"
            return ""

        tpl = Template(r"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>{{ name }} — Summary</title>
<style>
body{font-family:Arial,sans-serif;margin:24px;background:#fafafa;color:#222}
h2{margin-bottom:4px}
.badge{display:inline-block;padding:3px 10px;border-radius:12px;font-weight:bold;font-size:.85em}
.ok{background:#d4edda;color:#155724}.fail{background:#f8d7da;color:#721c24}
.summary{display:flex;gap:18px;margin:14px 0;flex-wrap:wrap}
.card{background:#fff;border:1px solid #ddd;border-radius:8px;padding:10px 18px;min-width:120px}
.card .val{font-size:2em;font-weight:bold}.card .lbl{font-size:.8em;color:#666}
table{border-collapse:collapse;width:100%;background:#fff;border-radius:8px;overflow:hidden;box-shadow:0 1px 3px rgba(0,0,0,.1)}
td,th{border:1px solid #e0e0e0;padding:6px 10px;font-size:.84em}
th{background:#f0f0f0;font-weight:600}
tr.row-fail td{background:#fff3f3}tr.row-warn td{background:#fffbe6}tr.row-ok td{background:#f3fff6}
pre{margin:0;white-space:pre-wrap;word-break:break-all}
.env{background:#fff;border:1px solid #ddd;border-radius:8px;padding:10px 16px;margin-bottom:14px;font-size:.84em}
.env span{display:inline-block;margin-right:20px}
</style>
</head>
<body>
<h2>{{ name }}&nbsp;
  <span class="badge {{ 'ok' if overall_ok else 'fail' }}">{{ 'PASS' if overall_ok else 'FAIL' }}</span>
</h2>
<div class="env">
  <span><b>Start:</b> {{ run_start_ts }}</span>
  <span><b>End:</b> {{ run_end_ts }}</span>
  <span><b>Output:</b> <code>{{ out_dir }}</code></span>
  {% if device_info %}<span><b>Device:</b>
    {{ device_info.get('manufacturer','') }} {{ device_info.get('model','') }}
    (Android {{ device_info.get('android_version','?') }}) — {{ device_info.get('udid','') }}
  </span>{% endif %}
</div>
<div class="summary">
  <div class="card"><div class="val">{{ total_jobs }}</div><div class="lbl">Total Jobs</div></div>
  <div class="card" style="border-color:#28a745">
    <div class="val" style="color:#28a745">{{ injections_ok }}</div><div class="lbl">Passed</div>
  </div>
  <div class="card" style="border-color:#dc3545">
    <div class="val" style="color:#dc3545">{{ injections_fail }}</div><div class="lbl">Failed</div>
  </div>
</div>
<h3>Event Timeline</h3>
<table>
<tr><th>Time</th><th>Event</th><th>Data</th></tr>
{% for e in events %}
<tr class="{{ row_class(e) }}">
  <td style="white-space:nowrap">{{ e.ts }}</td>
  <td>{{ e.event }}</td>
  <td><pre>{{ e.data | tojson(indent=2, ensure_ascii=False) }}</pre></td>
</tr>
{% endfor %}
</table>
</body></html>""")

        html = tpl.render(
            name=self.run_name,
            out_dir=self.out_dir,
            events=events,
            run_start_ts=run_start_ts,
            run_end_ts=run_end_ts,
            device_info=device_info,
            total_jobs=len(job_results),
            injections_ok=injections_ok,
            injections_fail=injections_fail,
            overall_ok=overall_ok,
            row_class=row_class,
        )
        out = os.path.join(self.out_dir, "summary.html")
        with open(out, "w", encoding="utf-8") as f:
            f.write(html)
