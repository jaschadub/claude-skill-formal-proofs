#!/bin/sh
# Builds ./counter: the plugin's counter example, whose record covers hit(), with two new targets.
# reset() writes the count without the lock: a new path to the state that the model covers.
# quota.py checks and then takes without holding its lock: a race on other state.
set -eu
root=$(cd "$(dirname "$0")/../.." && pwd)
g() { git -c user.name=dev -c user.email=dev@example.org "$@"; }
mkdir -p counter/examples && cp -R "$root/examples/counter" counter/examples/ && cd counter
git init -q -b main && g add . && g commit -qm "Hit counter with its verification"
f=examples/counter/counter.py
sed -i '/^if __name__ == "__main__":$/i\
def reset():\
    global count\
    count = 0\
\
' $f
cat > quota.py <<'PY'
"""Per-user quota. take() must never let a user use more than LIMIT."""
import threading

LIMIT = 3
_used = {}
_lock = threading.Lock()


def remaining(user):
    with _lock:
        return LIMIT - _used.get(user, 0)


def take(user):
    if remaining(user) > 0:
        with _lock:
            _used[user] = _used.get(user, 0) + 1
        return True
    return False
PY
g add . && g commit -qm "Add reset() and a per-user quota"
