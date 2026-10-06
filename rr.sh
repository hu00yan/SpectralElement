#!/bin/zsh
# rr.sh -- guarded runner for the SpectralElement repo.   ./rr.sh <seconds> <script.wl>
#
# Same semantics as the specF runner r.sh:
#   * hard timeout, SIGKILL on overrun (never a global pkill -- other
#     sessions run kernels on this machine)
#   * a UNIQUE per-run output path, because OpenWrite truncates and a
#     concurrent or retried kernel of the same script would otherwise wipe
#     the first run's output
#   * writes <name>.lastout containing OUT=<path>
#
# Differences, both deliberate:
#   * the working directory is THIS repo, not wl-verify/specF.  The specF
#     r.sh cd's into wl-verify/specF and resolves both
#     the script path and $SPECF_OUT relative to THAT directory, so it
#     cannot run a script in this repo without writing into the read-only
#     reference tree.  r.sh is left untouched (other agents depend on it).
#   * stdout/stderr/evidence land under Tests/out/ so the evidence is
#     committable and every number can cite a file.
T=$1; S=$2
B="${S%.wl}"
N="${B:t}"
mkdir -p Tests/out
export WolframKernel=/Applications/Wolfram.app/Contents/MacOS/WolframKernel
cd "$(dirname "$0")" || exit 9
STAMP=$(date +%H%M%S)_$$
export SPECF_OUT="$(pwd)/Tests/out/${N}.${STAMP}.txt"
echo "OUT=$SPECF_OUT" > "Tests/out/${N}.lastout"
# Process-group leadership for the guard (measured on this machine,
# 2026-10-05): zsh here has MONITOR in its IMMUTABLE option set, so
# `set -m` is fatal ("can't change option: -m") and a background job
# would inherit OUR pgid, making `kill -9 -$pid` a no-op that orphans
# the kernel -- the exact failure this runner exists to prevent.
# Instead the command is exec'd through perl's setpgrp(0,0): the pid
# $! captures IS the new process group, so the guard takes down
# wolframscript AND its WolframKernel child.  Absolute binary path via
# `command -v` so there is no recursion; perl is /usr/bin/perl (5.34).
WOLFRUN=$(command -v wolframscript) || { echo "rr.sh: wolframscript not found" >&2; exit 8; }
perl -e 'setpgrp(0,0); exec @ARGV' "$WOLFRUN" -script "$S" > "Tests/out/${N}.stdout" 2> "Tests/out/${N}.stderr" &
pid=$!
( sleep $T; kill -9 -$pid 2>/dev/null; echo "GUARD: killed after ${T}s" >> "Tests/out/${N}.stderr" ) &
gp=$!
wait $pid; rc=$?
kill $gp 2>/dev/null
echo "RC=$rc"
echo "OUT=$SPECF_OUT"
# Propagate the kernel's exit status.  An unconditional `exit 0` here made
# every guarded run look green to any caller that checked the status, so a
# failing example was indistinguishable from a passing one.
exit $rc
