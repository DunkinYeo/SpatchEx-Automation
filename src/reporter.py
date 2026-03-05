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
        # very small summary page
        events = []
        if os.path.exists(self.events_path):
            with open(self.events_path, "r", encoding="utf-8") as f:
                for line in f:
                    try:
                        events.append(json.loads(line))
                    except Exception:
                        pass

        tpl = Template("""<!doctype html>
<html><head><meta charset="utf-8"><title>{{name}} summary</title>
<style>body{font-family:Arial, sans-serif; margin:24px;} table{border-collapse:collapse; width:100%;} td,th{border:1px solid #ddd; padding:8px;} th{background:#f5f5f5;}</style>
</head><body>
<h2>{{name}} - Run Summary</h2>
<p>Artifacts folder: <code>{{out_dir}}</code></p>
<table>
<tr><th>Time</th><th>Event</th><th>Data</th></tr>
{% for e in events %}
<tr><td>{{e.ts}}</td><td>{{e.event}}</td><td><pre style="margin:0; white-space:pre-wrap;">{{e.data | tojson(indent=2, ensure_ascii=False)}}</pre></td></tr>
{% endfor %}
</table>
</body></html>""")

        html = tpl.render(name=self.run_name, out_dir=self.out_dir, events=events)
        out = os.path.join(self.out_dir, "summary.html")
        with open(out, "w", encoding="utf-8") as f:
            f.write(html)
