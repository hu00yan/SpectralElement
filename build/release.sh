#!/bin/zsh
# ---------------------------------------------------------------------------
# build/release.sh -- build the distributable .paclet ARCHIVE.
#
# WHY THIS EXISTS.  A paclet ships EXACTLY what is on disk at build time.
# There is no PacletInfo field, and no option on PacletObject or
# PacletDirectoryLoad, that excludes anything -- both Options lists are
# empty -- and CreateArchive does NOT respect .gitignore.  A naive
#     CreateArchive[{repoRoot}, "SpectralElement.paclet"]
# therefore packs the entire working tree.  Measured on this checkout:
#
#     Tests/            114 M   437 files   evidence .txt, probes
#     scratch/                5 M dev scratch, git-IGNORED but still packed
#     build/            20 K    the bundler itself
#     wfr/              104 K   the Function Repository artifact
#     .git/                       history
#
# So this script stages a CLEAN COPY first, containing only what belongs
# in a release, and archives that.  The staging copy is built fresh in a
# temp directory on every run and removed afterwards, so a stale file left
# by an earlier run can never leak into a release.
#
# What ships:
#     PacletInfo.wl      metadata
#     LICENSE            must travel with the package (MIT)
#     README.md          install instructions
#     API.md             the binding contract the code is written against
#     Kernel/            the code -- init.m, the loader, the four subfiles
#
# What does NOT ship, and why:
#     Tests/        dev-only; 114 M of captured evidence, plus the probes
#     build/        dev-only; this script and the WFR bundler
#     wfr/          a SEPARATE distribution channel (Function Repository);
#                   shipping it inside the paclet duplicates 85 KB of code
#     scratch/        dev scratch, and .git-ignored, which CreateArchive
#                   would ignore anyway if CreateArchive respected it
#     .git/         repository history
#     docs/, Examples/   empty
#     rr.sh, r.sh, .gitignore   development conveniences
#
# Usage:
#     ./build/release.sh                 # build + verify + report
#     ./build/release.sh keep            # also keep the staging tree
#     cat build/release.lastout           # the machine-readable summary
#
# Exit status is 0 only if the archive was built AND verified to contain
# nothing it should not.
#
# WHAT release.lastout IS, precisely, because the Usage block above used to
# promise an "evidence log" this script never wrote: it is a SUMMARY of the
# numbers this run produced, one `key: value` per line, written LAST, so the
# file's existence means the script ran to completion.  The full
# human-readable log is the run's stdout -- capture it yourself if you want
# it committed.
# ---------------------------------------------------------------------------
set -u
cd "$(dirname "$0")/.." || exit 9
ROOT="$(pwd)"
KEEP=0
[ "${1:-}" = "keep" ] && KEEP=1

NAME="SpectralElement"
# The staging copy goes INSIDE the repo, under scratch/, never in
# /tmp or $TMPDIR.  Rebuild it from scratch every run so a stale file
# from a previous run cannot leak into a release.  API.md rule 4: scratch
# is a plain non-dot directory; a dot-prefixed one may be swept by any
# tool at any time.
SCRATCH="$ROOT/scratch"
STAGE="$SCRATCH/release-stage"
rm -rf "$STAGE"
mkdir -p "$STAGE" || exit 1
STAGE_PKG="$STAGE/$NAME"
# The archive is written into build/, which is itself excluded from the
# paclet -- so a release artifact can never end up inside the next one.
ARCHIVE="$ROOT/build/$NAME-0.1.0.paclet"

cleanup() {
  if [ "$KEEP" = "1" ]; then
    echo "release.sh: staging tree KEPT at $STAGE_PKG"
  else
    rm -rf "$STAGE"
  fi
}
trap cleanup EXIT INT TERM

echo "release.sh: staging a clean copy into $STAGE_PKG"

# --- 1. stage -----------------------------------------------------------------
mkdir -p "$STAGE_PKG" || exit 1

# PacletInfo.wl must keep its .wl extension: the paclet reader looks for
# exactly that filename.
cp -p "$ROOT/PacletInfo.wl" "$STAGE_PKG/PacletInfo.wl" || exit 1
cp -p "$ROOT/LICENSE"     "$STAGE_PKG/LICENSE"     || exit 1
cp -p "$ROOT/README.md"   "$STAGE_PKG/README.md"   || exit 1
cp -p "$ROOT/API.md"      "$STAGE_PKG/API.md"      || exit 1

# Kernel/ is copied wholesale and recursively, preserving the tree.
( cd "$ROOT" && tar cf - Kernel ) | ( cd "$STAGE_PKG" && tar xf - ) || exit 1

# --- 2. the staged tree must look right BEFORE archiving ----------------------
echo "release.sh: staged tree:"
( cd "$STAGE_PKG" && find . -type f | sort | sed 's|^\./|          |' )

STAGED_COUNT=$( cd "$STAGE_PKG" && find . -type f | wc -l | tr -d ' ' )
echo "release.sh: staged file count = $STAGED_COUNT"

# Anything at all that must not ship, checked against the staged tree.
FORBIDDEN="Tests build wfr scratch .git docs Examples"
BAD=""
for d in $FORBIDDEN; do
  [ -e "$STAGE_PKG/$d" ] && BAD="$BAD $d"
done
# Top-level dev scripts that would otherwise slip through a broad glob.
for f in rr.sh r.sh .gitignore; do
  [ -e "$STAGE_PKG/$f" ] && BAD="$BAD $f"
done

if [ -n "$BAD" ]; then
  echo "release.sh: FAIL -- forbidden entries present in the staging copy:$BAD" >&2
  exit 2
fi
echo "release.sh: staging copy is clean (none of:$FORBIDDEN)"

# --- 3. archive ---------------------------------------------------------------
rm -f "$ARCHIVE"
# No archiver-side exclusion is needed: the staging copy is clean by
# construction and is VERIFIED clean before the archive is made.  Adding
# patterns here would only create a second, untested code path.

WL=/Applications/Wolfram.app/Contents/MacOS/WolframScript
if [ ! -x "$WL" ]; then
  echo "release.sh: cannot find WolframScript at $WL" >&2
  exit 3
fi

# The archive is built by a two-line kernel invocation; the verifier is a
# permanent, reviewable file (build/release_verify.wl) rather than a
# heredoc, so what runs is visible in the repository.
print -r -- \
  'Put-free archive build: see ARC-EXISTS below' >/dev/null
cat > "$STAGE/mkarc.wl" <<'MKEOF'
If[FileExistsQ[arc], DeleteFile[arc]];
Quiet[Check[CreateArchive[{staged}, arc], Print]];
Print["ARC-EXISTS ", FileExistsQ[arc]];
Print["ARC-BYTES ", Quiet[Check[FileSize[arc], -1]]];
Quit[];
MKEOF

# Inject the two paths as definitions ahead of the body above, so the
# script body stays free of shell quoting entirely.
mkbody=$(cat "$STAGE/mkarc.wl")
printf 'staged = "%s";\narc = "%s";\n%s\n' "$STAGE_PKG" "$ARCHIVE" "$mkbody" > "$STAGE/mkarc.wl"

"$WL" -script "$STAGE/mkarc.wl" || exit 4
echo "release.sh: wrote $ARCHIVE"

# --- 4. verify the ARCHIVE, not just the staging tree ------------------------
# Listing the archive's entries is the check that matters: it proves what a
# user would actually receive.
echo "release.sh: archive contents:"
ARCHIVE_LIST="$(unzip -Z1 "$ARCHIVE" 2>/dev/null)"
echo "$ARCHIVE_LIST" | sort | sed 's/^/          /'

LEAKED=""
for d in $FORBIDDEN; do
  case "$ARCHIVE_LIST" in
    *"$d/"*|*"$d"*) LEAKED="$LEAKED $d" ;;
  esac
done
for f in rr.sh r.sh; do
  case "$ARCHIVE_LIST" in *"$f"*) LEAKED="$LEAKED $f" ;; esac
done

echo
echo "release.sh: ================ VERDICT ================"
if [ -n "$LEAKED" ]; then
  echo "release.sh: RELEASE-FAIL -- the archive contains:$LEAKED"
  exit 5
fi
if [ ! -f "$ARCHIVE" ]; then
  echo "release.sh: RELEASE-FAIL -- no archive was produced"
  exit 6
fi
echo "release.sh: forbidden entries in the archive: NONE"

# --- 5. end-to-end proof: install the ARCHIVE we just built ------------------
# Listing the entries shows what is inside; installing it shows it WORKS.
echo
echo "release.sh: --- end-to-end: installing the built archive ---"
SPECTRAL_RELEASE_ARCHIVE="$ARCHIVE" SPECTRAL_RELEASE_NAME="$NAME" \
  "$WL" -script "$ROOT/build/release_verify.wl" > "$STAGE/verify.out" 2>&1
VERIFY_OUT="$(cat "$STAGE/verify.out")"
echo "$VERIFY_OUT" | sed 's/^/          /'

# Decide from the verifier's stdout with plain grep rather than a shell
# `case` on a multi-line pattern list.
INSTALL_FAIL=0
if echo "$VERIFY_OUT" | grep -qE 'INSTALL-FAILED|NEEDS-RAISED|PATCH-OK False|DISC-OK False|INSTALL-DIR-GONE False'; then
  INSTALL_FAIL=1
fi
SYMS=$(echo "$VERIFY_OUT" | sed -n 's/^SYMBOLS \([0-9][0-9]*\).*/\1/p')
AFTER=$(echo "$VERIFY_OUT" | sed -n 's/^AFTER-UNINSTALL-FOUND \([0-9][0-9]*\).*/\1/p')
UC=$(echo "$VERIFY_OUT" | sed -n 's/^UNKNOWN-COUNT //p')
echo "release.sh: parsed from the verifier: SYMBOLS=$SYMS  AFTER-UNINSTALL-FOUND=$AFTER  UNKNOWN-COUNT=$UC"
[ "$SYMS" = "8" ] || INSTALL_FAIL=1
[ "$AFTER" = "0" ] || INSTALL_FAIL=1

echo
if [ "$INSTALL_FAIL" != "0" ]; then
  echo "release.sh: RELEASE-FAIL -- the built archive did not install and load cleanly"
  exit 7
fi
echo "release.sh: the built archive installs, loads, and uninstalls cleanly"
ARC_BYTES=$(cd "$(dirname "$ARCHIVE")" && wc -c < "$NAME-0.1.0.paclet" | tr -d ' ')
{
  echo "archive: $ARCHIVE"
  echo "archive-bytes: $ARC_BYTES"
  echo "archive-entries: $(echo "$ARCHIVE_LIST" | grep -c . )"
  echo "staged-files: $STAGED_COUNT"
  echo "forbidden-in-archive: NONE"
  echo "symbols-after-install: $SYMS"
  echo "found-after-uninstall: $AFTER"
  echo "verdict: RELEASE-OK"
  echo "staging-kept: $( [ "$KEEP" = "1" ] && echo yes || echo no )"
} > "$ROOT/build/release.lastout"
echo "release.sh: summary written to build/release.lastout"
echo "release.sh: RELEASE-OK  ->  $ARCHIVE"
echo "release.sh: =============================================="