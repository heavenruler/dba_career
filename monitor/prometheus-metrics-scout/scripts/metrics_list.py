import json
import os
import ssl
import time
import urllib.request


def main() -> None:
    base_url = os.environ.get("BASE_URL", "https://pmm.104.com.tw/prometheus")
    timeout = int(os.environ.get("TIMEOUT", "20"))
    start = time.time()

    ctx = ssl._create_unverified_context()
    url = f"{base_url}/api/v1/label/__name__/values"
    with urllib.request.urlopen(url, context=ctx, timeout=timeout) as r:
        payload = json.loads(r.read().decode("utf-8", errors="replace"))

    names = sorted(payload.get("data", []))
    if not names:
        raise SystemExit("No metric names returned")

    with open("metrics.list", "w", encoding="utf-8") as f:
        for name in names:
            f.write(f"{name}\n")

    elapsed = time.time() - start
    print(f"metric_count {len(names)}")
    print(f"elapsed_seconds {elapsed:.2f}")


if __name__ == "__main__":
    main()
