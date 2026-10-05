#!/bin/zsh
# bundle.sh -- regenerate wfr/SpectralNDSolve.wl from the paclet sources.
#
# Deterministic and idempotent: unchanged sources => byte-identical bundle.
# It only READS Kernel/; it never edits it.  The guarded runner (rr.sh) is
# used so a hung kernel cannot leak, and so the evidence lands in
# Tests/out/bundle.<stamp>.txt (path also in Tests/out/bundle.lastout).
#
#   ./build/bundle.sh            # rebuild + report
#   cat Tests/out/bundle.lastout # OUT=<evidence file>
set -u
cd "$(dirname "$0")/.." || exit 9
if [ ! -x ./rr.sh ]; then
  echo "bundle.sh: ./rr.sh not found or not executable in $PWD" >&2
  exit 9
fi
exec ./rr.sh 180 build/bundle.wl