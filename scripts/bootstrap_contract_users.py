"""Create disposable, verified users for the local/CI contract backend only.

Writes tokens to GITHUB_ENV without printing them. Requires the dev OTP
endpoint; never run against production or with real user data.
"""
import json
import os
import secrets
import urllib.request
from urllib.parse import urlsplit

base = os.environ.get("BLISTRA_E2E_URL", "http://127.0.0.1:8080").rstrip("/")
if urlsplit(base).hostname not in ("localhost", "127.0.0.1"):
    raise SystemExit("Contract bootstrap only permits a loopback test backend")


def call(path, body=None, token=None, method=None):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = "Bearer " + token
    request = urllib.request.Request(base + "/api/v1/" + path,
        data=None if body is None else json.dumps(body).encode(), headers=headers,
        method=method or ("GET" if body is None else "POST"))
    with urllib.request.urlopen(request, timeout=30) as response:
        raw = response.read()
        return json.loads(raw) if raw else None


outputs = {"BLISTRA_E2E_URL": base}
for index in range(2):
    username = "contract_" + secrets.token_hex(6)
    account = call("auth/register", {"username": username, "email": username + "@example.test",
        "password": secrets.token_urlsafe(24) + "A1", "termsAccepted": True})
    token = account["token"]
    code = call("auth/dev/otp?purpose=EMAIL_VERIFY", token=token)["code"]
    call("auth/verify/email", {"code": code}, token)
    call("profile", {"displayName": username, "dateOfBirth": "1990-01-01", "country": "IN",
        "timezone": "Asia/Kolkata", "language": "en", "unitSystem": "METRIC"}, token, "PUT")
    call("profile/complete-onboarding", {}, token)
    outputs["BLISTRA_E2E_TOKEN" + ("2" if index else "")] = token
    if index:
        outputs["BLISTRA_E2E_USERNAME2"] = username
with open(os.environ["GITHUB_ENV"], "a", encoding="utf-8") as destination:
    for key, value in outputs.items():
        destination.write(key + "=" + value + "\n")
