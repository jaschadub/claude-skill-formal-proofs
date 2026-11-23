#!/bin/sh
# Copyright (c) 2026 Jascha Wanger (jascha.me). MIT license; see LICENSE.
# Check a TLA+ spec with TLC. Needs only Java 11+ and, on first use, the network.
# usage: sh check.sh SPEC.tla [CONFIG.cfg] [extra TLC options]
# Exit code is TLC's: 0 every rule holds, 12 a rule breaks, 11 deadlock, other values are errors.
set -eu
VERSION=1.7.4
SHA256=936a262061c914694dfd669a543be24573c45d5aa0ff20a8b96b23d01e050e88

[ $# -ge 1 ] || { echo "usage: sh check.sh SPEC.tla [CONFIG.cfg] [extra TLC options]" >&2; exit 2; }
absolute() { echo "$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"; }
java=${JAVA:-java}
command -v "$java" >/dev/null || { echo "tla-check needs Java 11 or later on PATH, or JAVA set to a java binary" >&2; exit 127; }

jar=${TLA2TOOLS:-${XDG_CACHE_HOME:-$HOME/.cache}/tla-check/tla2tools-$VERSION.jar}
if [ ! -f "$jar" ]; then
  mkdir -p "$(dirname "$jar")"
  curl -fsSL -o "$jar.part" "https://github.com/tlaplus/tlaplus/releases/download/v$VERSION/tla2tools.jar"
  if command -v sha256sum >/dev/null; then sum=$(sha256sum "$jar.part"); else sum=$(shasum -a 256 "$jar.part"); fi
  [ "${sum%% *}" = "$SHA256" ] || { rm -f "$jar.part"; echo "tla2tools.jar checksum mismatch; nothing was installed" >&2; exit 1; }
  mv "$jar.part" "$jar"
fi
# TLC runs in the folder of the spec, so a path that is relative to this folder must not stay relative.
jar=$(absolute "$jar")
case $java in */*) java=$(absolute "$java") ;; esac

spec=$(absolute "$1"); shift
case ${1:--} in -*) cfg=${spec%.tla}.cfg ;; *) cfg=$(absolute "$1"); shift ;; esac

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cd "$(dirname "$spec")"
# -difftrace: each step of a counterexample shows only the variables that changed.
"$java" -XX:+UseParallelGC "-Djava.io.tmpdir=$work" -cp "$jar" tlc2.TLC -config "$cfg" -metadir "$work" \
  -workers auto -difftrace "$@" "$(basename "$spec")"
