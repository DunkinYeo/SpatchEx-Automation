import requests

def slack_notify(webhook_url: str, text: str):
    try:
        requests.post(webhook_url, json={"text": text}, timeout=10)
    except Exception:
        pass
