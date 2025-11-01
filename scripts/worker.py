import time, os, json, hashlib
from google.cloud import pubsub_v1, storage

PROJECT = os.environ.get("GCP_PROJECT") or os.environ.get("PROJECT_ID") or ""
SUB_NAME = os.environ.get("SUBSCRIPTION")  # full subscription path expected
BUCKET = os.environ.get("RESULTS_BUCKET")
REGION = os.environ.get("WORKER_REGION")  # expected short region name like europe-west3

def _detect_region():
    # Try metadata server if WORKER_REGION not provided
    if REGION:
        return REGION
    # GCE metadata endpoint for zone returns projects/<num>/zones/<zone>
    try:
        import urllib.request
        req = urllib.request.Request(
            "http://metadata.google.internal/computeMetadata/v1/instance/zone",
            headers={"Metadata-Flavor": "Google"},
        )
        with urllib.request.urlopen(req, timeout=1) as resp:
            zone_path = resp.read().decode().strip().split('/')[-1]
            return '-'.join(zone_path.split('-')[:-1])
    except Exception:
        pass
    return "unknown-region"

REGION = _detect_region()

# Stress configuration via env vars
STRESS_SECONDS = int(os.environ.get("STRESS_SECONDS", "10"))
STRESS_MODE = os.environ.get("STRESS_MODE", "busy")  # busy|hash|sleep


def cpu_burn(seconds: int, mode: str):
    """Generate CPU load for autoscaling tests.
    mode = busy: tight integer arithmetic loop
           hash: repeated sha256 hashing
           sleep: fall back to time.sleep (no CPU load)
    """
    if mode == "sleep":
        time.sleep(seconds)
        return
    end = time.time() + seconds
    if mode == "hash":
        i = 0
        while time.time() < end:
            hashlib.sha256(str(i).encode()).digest()
            i += 1
        return
    # default busy loop
    x = 0
    while time.time() < end:
        x = (x * 13 + 7) % 1000003


def process_and_save(msg_json: str):
    task = json.loads(msg_json)
    task_id = str(task.get("task_id", "no-id"))
    n = int(task.get("input", 0))
    # simulate work with configurable CPU stress (replaces simple sleep)
    cpu_burn(STRESS_SECONDS, STRESS_MODE)
    result = n * 2
    client = storage.Client()
    bucket = client.bucket(BUCKET)
    blob = bucket.blob(f"results/{REGION}/{task_id}.txt")
    blob.upload_from_string(str(result))
    print(f"Saved result for {task_id}: {result}")


def main():
    if not SUB_NAME or not BUCKET:
        raise SystemExit("Missing SUBSCRIPTION or RESULTS_BUCKET environment variables")
    subscriber = pubsub_v1.SubscriberClient()

    def callback(message):
        print("Got message:", message.message_id)
        try:
            process_and_save(message.data.decode("utf-8"))
            message.ack()
        except Exception as e:
            print("Error processing message:", e)
            # message will be redelivered

    # Basic subscribe; increase throughput by allowing parallel callbacks via thread settings if available
    flow_control = pubsub_v1.types.FlowControl(max_messages=10)
    streaming_pull_future = subscriber.subscribe(
        SUB_NAME, callback=callback, flow_control=flow_control
    )
    print(
        f"Worker started, subscription={SUB_NAME}, stress={STRESS_MODE}:{STRESS_SECONDS}s"
    )
    try:
        streaming_pull_future.result()
    except Exception as e:
        streaming_pull_future.cancel()
        print("Shutting down:", e)


if __name__ == "__main__":
    main()
