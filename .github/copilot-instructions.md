# Copilot Instructions (S-Patch Long-Run Automation)

You are helping build QA automation for a BLE medical device companion app.
Constraints:
- Long duration (24/48/72h), must be resilient.
- UI-only automation for symptom injection (no deep links).
- Prefer minimal UI interactions: only what's needed to inject symptoms.
Rules:
1) Add retries/timeouts and clear logs.
2) Always capture artifacts on failures.
3) Keep behavior deterministic and config-driven (YAML).
4) Avoid broad refactors; keep patches minimal.
