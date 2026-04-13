import sys
import requests


def check_json(url: str, expected_status: int = 200) -> dict:
    response = requests.get(url, timeout=10)
    if response.status_code != expected_status:
        raise RuntimeError(f"GET {url} failed: {response.status_code} {response.text}")
    return response.json()


def check_pdf(url: str) -> None:
    response = requests.get(url, timeout=20)
    if response.status_code != 200:
        raise RuntimeError(f"GET {url} failed: {response.status_code} {response.text}")
    content_type = response.headers.get("content-type", "")
    if "application/pdf" not in content_type:
        raise RuntimeError(f"Expected PDF, got content-type: {content_type}")
    if not response.content or response.content[:4] != b"%PDF":
        raise RuntimeError("Invalid PDF content")


def main() -> int:
    base_url = sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8000"

    health = check_json(f"{base_url}/health")
    if health.get("status") != "healthy":
        raise RuntimeError(f"Unexpected health response: {health}")

    visits_before = check_json(f"{base_url}/visits")
    if "count" not in visits_before:
        raise RuntimeError(f"Unexpected visits response: {visits_before}")

    response = requests.post(f"{base_url}/visits", timeout=10)
    if response.status_code != 200:
        raise RuntimeError(f"POST /visits failed: {response.status_code} {response.text}")
    visits_after = response.json()
    if "count" not in visits_after:
        raise RuntimeError(f"Unexpected visits response: {visits_after}")

    check_pdf(f"{base_url}/pdf?lang=ca")

    print("All checks passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
