import json
import os
import ssl
import time
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed


def main() -> None:
    base_url = os.environ.get("BASE_URL", "https://pmm.104.com.tw/prometheus")
    timeout = int(os.environ.get("TIMEOUT", "20"))
    sleep_every = int(os.environ.get("SLEEP_EVERY", "200"))
    sleep_seconds = float(os.environ.get("SLEEP_SECONDS", "0.1"))
    workers = int(os.environ.get("WORKERS", "6"))
    start = time.time()

    ctx = ssl._create_unverified_context()

    with open("metrics.list", "r", encoding="utf-8") as f:
        names = [line.strip() for line in f if line.strip()]

    total = len(names)
    print(f"metrics_total {total}")

    labels_map = {}
    errors = []

    def fetch_labels(metric: str) -> tuple[str, list[str], str | None]:
        query = urllib.parse.urlencode({"query": metric})
        url = f"{base_url}/api/v1/query?{query}"
        try:
            with urllib.request.urlopen(url, context=ctx, timeout=timeout) as r:
                result = json.loads(r.read().decode("utf-8", errors="replace"))
            results = result.get("data", {}).get("result", [])
            if results:
                labels = sorted(
                    [k for k in results[0].get("metric", {}).keys() if k != "__name__"]
                )
            else:
                labels = []
            return metric, labels, None
        except Exception as e:
            return metric, [], f"{e.__class__.__name__}: {e}"

    completed = 0
    with ThreadPoolExecutor(max_workers=workers) as executor:
        futures = [executor.submit(fetch_labels, metric) for metric in names]
        for future in as_completed(futures):
            metric, labels, error = future.result()
            labels_map[metric] = labels
            if error:
                errors.append({"metric": metric, "error": error})

            completed += 1
            if sleep_every > 0 and completed % sleep_every == 0:
                elapsed = time.time() - start
                print(f"progress {completed}/{total} elapsed_seconds {elapsed:.2f}")
                time.sleep(sleep_seconds)

    with open("labels.json", "w", encoding="utf-8") as f:
        json.dump(labels_map, f, ensure_ascii=True, indent=2)
        f.write("\n")

    elapsed = time.time() - start
    print(f"metric_count {len(names)}")
    print(f"error_count {len(errors)}")
    print(f"elapsed_seconds {elapsed:.2f}")


if __name__ == "__main__":
    main()
