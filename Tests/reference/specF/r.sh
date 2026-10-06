#!/bin/zsh
# specF guarded runner:  ./r.sh <seconds> <script.wl>
# SIGKILLs the kernel on overrun.  Gives EVERY run a unique output path
# ($SPECF_OUT) because OpenWrite truncates and a concurrent/retried
# kernel of the same script otherwise wipes the first run's output.
T=$1; S=$2
B="${S%.wl}"
export WolframKernel=/Applications/Wolfram.app/Contents/MacOS/WolframKernel
# Run from THIS script's own directory, so the harness is self-contained and
# works from wherever the repository is checked out.  (It used to cd to an
# absolute path outside the repo, which is what leaked that path.)
cd "${0:A:h}" || exit 9
STAMP=$(date +%H%M%S)_$$
export SPECF_OUT="$PWD/${B}.${STAMP}.txt"
echo "OUT=$SPECF_OUT" > "${B}.lastout"
wolframscript -script "$S" > "${B}.stdout" 2> "${B}.stderr" &
pid=$!
( sleep $T; kill -9 $pid 2>/dev/null; echo "GUARD: killed after ${T}s" >> "${B}.stderr" ) &
gp=$!
wait $pid; rc=$?
kill $gp 2>/dev/null
echo "RC=$rc"
echo "OUT=$SPECF_OUT"
exit 0