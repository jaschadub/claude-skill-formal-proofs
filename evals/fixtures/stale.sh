#!/bin/sh
# Builds ./upstream.git and ./app, a clone of it that is 4 commits behind. Upstream fixes the race.
set -eu
g() { git -c user.name=dev -c user.email=dev@example.org "$@"; }
git init -q --bare -b main upstream.git
g clone -q upstream.git app 2>/dev/null
cd app
cat > counter.py <<'PY'
"""A hit counter that several threads share."""
import threading

count = 0


def hit():
    global count
    seen = count
    count = seen + 1
PY
g add . && g commit -qm "Add the hit counter" && g push -q origin main
cd .. && g clone -q upstream.git work && cd work
echo "# Hit counter" > README.md && g add . && g commit -qm "Add a readme"
sed -i 's/^count = 0$/count = 0\nlock = threading.Lock()/; s/^    seen = count$/    with lock:\n        seen = count/; s/^    count = seen + 1$/        count = seen + 1/' counter.py
g commit -qam "Take a lock around read and write in hit()"
printf '\n\ndef reset():\n    global count\n    with lock:\n        count = 0\n' >> counter.py && g commit -qam "Add reset()"
echo "Run with python3 counter.py." >> README.md && g commit -qam "Say how to run it"
g push -q origin main && cd .. && rm -rf work
