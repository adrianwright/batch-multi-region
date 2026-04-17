"""
Reproduces the Azure OpenAI multipart boundary error:
    400 - "'content-type' header does not contain required 'boundary' value"

Cause: manually setting `Content-Type: multipart/form-data` without the
required `boundary=...` parameter. The requests library (and OpenAI SDK)
generate the boundary automatically when you use `files=`, but only if
you DON'T override the Content-Type header yourself.

Usage:
    $env:APIM_SUBSCRIPTION_KEY = "<your-apim-key>"
    python reproduce_content_type_error.py
"""

import json
import os
import sys
from io import BytesIO

import requests

# APIM gateway in rg-apim-dev. Routes to Azure OpenAI batch backends.
APIM_HOST = "https://apim-dev-b4812d5c.azure-api.net"
UPLOAD_URL = f"{APIM_HOST}/openai-sticky/files"

# Minimal valid batch JSONL payload
BATCH_JSONL = (
    b'{"custom_id":"req-1","method":"POST",'
    b'"url":"/v1/chat/completions",'
    b'"body":{"model":"gpt-4o-mini",'
    b'"messages":[{"role":"user","content":"hi"}]}}\n'
)


def build_files_payload():
    """Fresh multipart payload (BytesIO must be re-created per request)."""
    return {
        "file": ("batch_input.jsonl", BytesIO(BATCH_JSONL), "application/jsonl"),
        "purpose": (None, "batch"),
    }


def print_response(label, response):
    print(f"\n[{label}] HTTP {response.status_code}")
    print(f"  Backend region: {response.headers.get('X-Backend-Region', 'n/a')}")
    print(f"  apim-request-id: {response.headers.get('apim-request-id', 'n/a')}")
    try:
        body = json.dumps(response.json(), indent=2)
    except ValueError:
        body = response.text
    print(f"  Body:\n{body}")


def send_bad_request(apim_key):
    """Manually set Content-Type without boundary -> 400 boundary error."""
    print("=" * 70)
    print("BAD REQUEST: manually set Content-Type: multipart/form-data")
    print("=" * 70)

    headers = {
        "Ocp-Apim-Subscription-Key": apim_key,
        "Content-Type": "multipart/form-data",  # missing boundary=...
    }

    response = requests.post(
        UPLOAD_URL,
        headers=headers,
        files=build_files_payload(),
        timeout=30,
    )
    print_response("BAD", response)
    return response


def send_good_request(apim_key):
    """Let requests set Content-Type; it includes the boundary automatically."""
    print("\n" + "=" * 70)
    print("GOOD REQUEST: let requests set Content-Type (includes boundary)")
    print("=" * 70)

    headers = {
        "Ocp-Apim-Subscription-Key": apim_key,
        # No Content-Type here — requests generates it with the boundary.
    }

    response = requests.post(
        UPLOAD_URL,
        headers=headers,
        files=build_files_payload(),
        timeout=30,
    )
    print_response("GOOD", response)
    return response


def main():
    apim_key = os.getenv("APIM_SUBSCRIPTION_KEY")
    if not apim_key:
        print("ERROR: Set APIM_SUBSCRIPTION_KEY first:")
        print("  $env:APIM_SUBSCRIPTION_KEY = '<your-apim-key>'")
        sys.exit(1)

    print(f"Target: {UPLOAD_URL}\n")

    send_bad_request(apim_key)
    send_good_request(apim_key)

    print("\n" + "=" * 70)
    print("TAKEAWAY")
    print("=" * 70)
    print(
        "When using `files=` with requests (or the OpenAI SDK), do NOT set\n"
        "Content-Type manually. The library generates it with the required\n"
        "boundary parameter. Overriding the header strips the boundary and\n"
        "triggers: \"'content-type' header does not contain required 'boundary' value\""
    )


if __name__ == "__main__":
    main()
