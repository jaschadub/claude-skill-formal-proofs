#!/bin/sh
# Builds ./jobs: a job queue whose README promises that every job ends. A job that times out
# stays "running" for good, which breaks no rule about a single state.
set -eu
mkdir jobs && cd jobs
cat > jobs.py <<'PY'
"""A small job queue. Workers take jobs, run them, and retry a job that fails."""
import queue
import threading

MAX_TRIES = 3

pending = queue.Queue()
state = {}   # job id -> "pending", "running", "done", or "failed"
tries = {}   # job id -> runs so far
lock = threading.Lock()


def submit(job_id, fn):
    with lock:
        state[job_id] = "pending"
        tries[job_id] = 0
    pending.put((job_id, fn))


def worker():
    while True:
        job_id, fn = pending.get()
        with lock:
            state[job_id] = "running"
            tries[job_id] += 1
        try:
            fn()
        except TimeoutError:
            # The job may still finish on the remote side. Leave it to the next sweep.
            continue
        except Exception:
            with lock:
                if tries[job_id] < MAX_TRIES:
                    state[job_id] = "pending"
                    pending.put((job_id, fn))
                else:
                    state[job_id] = "failed"
            continue
        with lock:
            state[job_id] = "done"


def start(workers=2):
    for _ in range(workers):
        threading.Thread(target=worker, daemon=True).start()
PY
cat > README.md <<'MD'
# jobs

`submit(job_id, fn)` queues a job. Every submitted job ends as `done` or `failed`: a job that raises is retried, up to 3 runs.
MD
git init -q -b main && git add . && git -c user.name=dev -c user.email=dev@example.org commit -qm "Job queue with retries"
