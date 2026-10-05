# Packaging & distribution — status

Two publication channels, both live and green. Read-only audit at the end;
`PacletInfo.wl` was **not** edited.

## What exists

| Path | What it is |
| --- | --- |
| `build/bundle.wl` | Bundler: inlines the four `Get`ed sources into one file |
| `build/bundle.sh` | `./build/bundle.sh` — rebuild the bundle through the guarded runner |
| `build/release.sh` | Builds the distributable `.paclet` **from a staging copy** |
| `build/release_verify.wl` | Installs the built archive and proves it loads (run by release.sh) |
| `wfr/SpectralNDSolve.wl` | **Generated** single-file package for the Function Repository |
| `wfr/SpectralNDSolve.md` | Function Repository submission document |
| `Tests/installprobe.wl` | Paclet-channel probe: `PacletInstall` → `Needs` → smoke → uninstall |

## Channel (a): the paclet

Two artefacts come out of this channel: a `.paclet` archive for users, and
an install probe that gates it.

### The release archive

```sh
./build/release.sh        # -> build/SpectralElement-0.1.0.paclet
```

Prints **`RELEASE-OK`** only if all three of these hold:

1. the staging copy contains only `PacletInfo.wl`, `LICENSE`, `README.md`,
   `API.md` and `Kernel/`;
2. the archive contains none of `Tests/`, `build/`, `wfr/`,
   `scratch/`, `.git/`, `docs/`, `Examples/`, `rr.sh`, `r.sh`;
3. **the archive that was just built installs, loads, and uninstalls
   cleanly** — 8 public symbols, `FindFile` inside the install directory,
   and both the geometry and discretization layers actually run.

It writes into `scratch/release-stage/` (never `/tmp`) and removes
it afterwards, so a stale file cannot leak into a later release. The archive
itself lands in `build/`, which is itself excluded from the paclet.

As built on 2026-10-05: **12 archive entries**, **10 staged files**,
**70,412 bytes**, `forbidden entries in the archive: NONE`, and the
end-to-end install self-verify reports `SYMBOLS 8`,
`AFTER-UNINSTALL-FOUND 0`, `INSTALL-DIR-GONE True`. A machine-readable
summary is written to `build/release.lastout`; the full log is in
`Tests/out/release_P_FINAL.log`.

### The install probe

```sh
./rr.sh 300 Tests/installprobe.wl
```

Latest evidence: `Tests/out/installprobe.<stamp>.txt` (path in
`Tests/out/installprobe.lastout`). Prints **`INSTALLPROBE-ALL-PASS`**
when all 56 named gates pass, and a per-item FAIL list otherwise. The last
line of the evidence file is the tally, `TALLY 56/56 PASS`, so the verdict
can be read off the end of the file without parsing anything above it.

Final run: `Tests/out/installprobe_P_FINAL.txt` — **56/56 PASS**.

The probe really installs: it builds a `.paclet` archive, `PacletInstall`s
it, checks that `FindFile` resolves **inside the installed copy** (not the
checkout, so the install path is genuinely under test), exercises the
geometry and discretization layers, then uninstalls and proves the
install directory is gone from `$UserBasePacletsDirectory`. It leaves
nothing on this machine.

## Channel (b): the single-file bundle

```sh
./build/bundle.sh          # or: ./rr.sh 180 build/bundle.wl
```

Evidence: `Tests/out/bundle.<stamp>.txt`; prints **`BUNDLE-OK`**.

As built on 2026-10-05: **151,810 bytes**, SHA-256
`733af4ac06369673f869ec6708bdb43af4286917e9fdf09ed29f8d93b5114f37`
(check with `shasum -a 256 wfr/SpectralNDSolve.wl`), and idempotent — built
twice, same hash and byte-identical evidence.

Properties the bundler asserts every run, and fails loudly without:

- the bundle parses (`SyntaxQ`), and so does **each inlined block
  separately** — a broken source file is named, not swallowed;
- no `$InputFileName`, no `Get[`, no `FileNameJoin[` survives;
- the file on disk is byte-identical to the text that was built (written
  with `Export`, then read back and compared);
- no timestamp anywhere, so an unchanged source tree gives a
  byte-identical bundle (verified by building twice and diffing).

Each inlined block carries the SHA-256 of its source, so every byte of the
shipped file traces back to a repository file.

## Paclet-readiness audit

Evidence: `Tests/out/q11probe.*.txt`, `Tests/out/q12probe.*.txt`.

**Ready**

- [x] `Name`, `Version`, `Description`, `Keywords`, `Extensions` present
      and read back correctly
- [x] `Extensions` declares exactly the Kernel extension with
      `"Root" -> "Kernel"` and `"Context" -> {"SpectralElement`"}`
- [x] `PacletInstall` of a `.paclet` archive works; `Needs` returns `Null`
      and raises **no** message; the eight public symbols resolve
- [x] `LICENSE` present (MIT, 1085 bytes)
- [x] `README.md` has an `## Install` section, documenting **both** routes
      (`PacletDirectoryLoad` for a checkout, `PacletInstall` of the built
      archive for a release) plus the bundle regeneration command

**Resolved by editing `PacletInfo.wl`** (it is now this task's file)

- [x] `Category` — **ambiguous, both spellings carried.** See the note
      below; this is the one audit item that could not be settled offline.
- [x] `WolframVersion` stays free text `"13.0+"`. The audit speculated a
      structured `{min, max}` form; that speculation was **wrong**. A census
      of the paclets Wolfram ships under
      `~/Library/Wolfram/Paclets/Repository` shows the field is always a
      string, with values in use `"14.3.0"`, `"14.3"`, `"14.3+"`, `"14.2+"`,
      `"14.1+"`. So the existing form was already correct. The
      PacletInfo documentation page shipped on this machine
      (`/Library/Wolfram/Documentation/14.3/en-us/Documentation/English/Paclets/PacletInfo.wl`)
      declares no version-range structure at all.
      Evidence: `Tests/out/q16probe.*.txt`.
- [x] `Keywords` gained `"Chebyshev"` and `"NDSolve"`, which the
      documentation actually uses and which were missing.
- [x] `Creator`, `PublisherID`, `URL` are now the literal string
      `"TODO-USER"` with a header block saying they must be filled before
      submission. `PublisherID` and `Creator` (which may be a *list*) are
      real fields used by shipped paclets; `URL` previously pointed at a
      GitHub organisation that does not exist.

**Left as `TODO-USER` — needs the submitting user, deliberately not invented**

- [ ] `Creator` — the real, attributable author name(s).
- [ ] `PublisherID` — the submitting user's publisher identifier; shipped
      first-party paclets use `"Wolfram"`.
- [ ] `URL` — the real repository URL.

Search `PacletInfo.wl` for `TODO-USER` to find them.

**The `Category` / `Categories` ambiguity — unresolved, and why**

The audit asked for `Category` to become the plural form "per the Paclet
Repository schema". Two pieces of offline evidence say that request rests on
a conflation, and renaming blind would have been the wrong call:

- No paclet shipped by Wolfram on this machine uses `Category`,
  `Categories` or `Tags` at all. There is no precedent to copy.
- The plural `Categories` belongs to the **Function Repository resource**
  schema (the YAML frontmatter in `wfr/SpectralNDSolve.md`), which is a
  different schema from `PacletInfo`. The two must not be conflated.
- The PacletInfo documentation page on this machine declares no category
  field whatsoever.

A probe (`Tests/out/q16probe.*.txt`) established that the paclet reader keeps
**every** field verbatim — it does not validate names — so carrying both
spellings costs nothing and loses nothing. `PacletInfo.wl` therefore carries
both `Category` and `Categories` with the same value, plus a comment saying to
confirm at submission time and delete whichever the Repository does not use.
**This still needs a decision at submission time.**

**Build exclusion — confirmed there is no mechanism, and worked around**

A paclet ships exactly what is on disk at build time. Measured: a naive
`CreateArchive` from the working tree captures everything, because
`CreateArchive` does **not** respect `.gitignore`. `Options[PacletObject]`
and `Options[PacletDirectoryLoad]` are both empty — there is no exclusion
knob in the paclet system to do this declaratively.

The working tree held:

- `Kernel/` — 96 K, 6 files — **ships**
- `Tests/` — 114 M, 437 files — **must not ship** (mostly evidence `.txt`)
- `build/` — 20 K — **must not ship**
- `wfr/` — 104 K — **must not ship** (separate WFR channel)
- `scratch/` — dev scratch (agent P's staging tree, agent D's) — **must not
  ship**; git-ignored, but the archiver does not care
- `.git/` — **must not ship**
- `docs/`, `Examples/` — both empty

**Resolved:** `build/release.sh` stages a clean copy (rebuilt from scratch
every run, under `scratch/`, never `/tmp`) containing only
`PacletInfo.wl`, `LICENSE`, `README.md`, `API.md` and `Kernel/`, verifies it
is clean, archives that, then verifies the **archive** rather than the
staging tree. The staged tree is 10 files / 50 KB against the working
tree's 114 MB.

## Round 3 — both channels are green

All three packaging gates pass against the current tree. Nothing below is
hedged; every number is in `Tests/out/`.

| Gate | Result | Evidence |
| --- | --- | --- |
| `./rr.sh 180 build/bundle.wl` | **`BUNDLE-OK`**, idempotent (two runs, same SHA-256) | `Tests/out/bundle_P_R4_run1.txt`, `…run2.txt` |
| `./build/release.sh` | **`RELEASE-OK`**, 12 entries, forbidden=`NONE`, install self-verify 8 symbols / 0 found after uninstall | `Tests/out/release_P_R4_FINAL.log`, `build/release.lastout` |
| `./rr.sh 600 Tests/installprobe.wl` | **`INSTALLPROBE-ALL-PASS`**, `TALLY 58/58 PASS` | `Tests/out/installprobe_P_R4_FINAL.txt` |
| `./rr.sh 300 Tests/probes/p_docverify.wl` | **`DOCVERIFY-ALL-PASS`**, 62/62 doc examples evaluate | `Tests/out/docverify_P_R4_FINAL.txt` |

What changed in round 3, all inside the packaging surface (`build/`,
`wfr/`, `Tests/installprobe.wl`):

- **Dot-directory purge.** Every `.agent-scratch` path in my files is gone;
  staging and probe scratch now live under `scratch/`. See the list of
  `file:line` changes at the end of this section.
- **`build/release.sh`** now writes `build/release.lastout`, which its own
  header had been promising and it had never written.
- **`Tests/installprobe.wl`** — the stub-state gate
  (`"the solver layer is a stub"`) was **deleted**, because asserting it
  would have turned a working solver red. It is replaced by eleven
  behaviour gates through the two public entry points. Three defects in
  the probe itself were found and fixed while doing that, and each is
  documented at the point of use in the file:
  - the verdict `If` had **five** arguments, so it raised `If::argb` and
    wrote **no verdict line at all** — `INSTALLPROBE-ALL-PASS` had never
    been printed, in any run, including ones reporting 45/45 green;
  - `FileSize[p, "Kilobytes"]` is not a valid call (WL 14.3), and
    `NumericQ[Quantity[…]]` is `False`, so the "not a stub" gate read a
    39 KB file as "not a number";
  - the probe is now **self-cleaning**: it uninstalls any pre-existing
    `SpectralElement` before installing, because it installs into a
    user-global directory and a killed earlier run had left one there
    (`PacletInstall::samevers`), which would have kept the probe red
    forever.
- **`wfr/SpectralNDSolve.md`** — all seven `PENDING` markers resolved, so
  the document now has **zero**. Every example and every `VerificationTest`
  expression in it is evaluated by a probe: **62/62**, evidence
  `Tests/out/docverify_P_R4_FINAL.txt`.

## Round 4 — the no-`DirichletCondition` path is green

Agent D fixed the hang reported in round 3. Nothing about it was a
packaging problem, so no gate had to be relaxed; the gate that was
deliberately *absent* in round 3 (asserting a defect) is now the gate that
is deliberately *present* (asserting the fix), plus a negative control for
the new refusal path.

| Change | Where | Measured |
| --- | --- | --- |
| round-3 "NOT TESTED HERE, REPORTED, NOT GATED" notice replaced by a pointer to section 8b | `Tests/installprobe.wl:411-418` | — |
| new gate: no-DC solve returns, is fast, is numeric, `u == 0` exactly on the boundary | `Tests/installprobe.wl:646-688` | `0.016 s`, boundary `0.`, interior `2.886579864025407·10^-15` |
| new gate: non-numeric Dirichlet data → `$Failed` naming `SpectralNDSolve::nlift` | `Tests/installprobe.wl:691-722` | `$Failed` in `0.012 s`, "27 non-numeric boundary node value(s)" |
| `SpectralNDSolve::nlift` added to the section-9 reported message names (no gate cost) | `Tests/installprobe.wl:742` | `saw[...nlift] -> True` |
| tally 56 → **58** | — | `TALLY 58/58 PASS` |

Three traps this round cost real runs, all documented at the point of use:

- `FunctionQ` is `Developer\`FunctionQ`. An undefined `FunctionQ[...]`
  makes `And` return that expression, and `If[<not True/False>, …]` then
  leaves its branches unevaluated — so the gate read an unevaluated
  `If[…]` as its answer. Same trap as round 3, reintroduced by me.
- `Quiet` suppresses **both** the printed tag and the `$MessageList`
  append, so a `Quiet`-wrapped call leaves no recoverable trace of the
  message it raised. Both routes (list and stdout) die together.
- `&` is a Syntax::sntx at the top level of an argument list.
  `Apply[fn, pts, {1}]` has no slots and cannot be got wrong; note it
  *spreads a pair into two arguments*, so a helper written with one
  parameter is silently handed `(a, b)`.

The gate's closed form is `u = (1 - x^2)(1 - y^2)`, chosen because it
vanishes on **every edge of the square**. A first attempt used
`-Laplacian[u] == 1` against `(1 - x^2 - y^2)/4`, which vanishes on the
circle, not on the square, and therefore failed. The solver was right: for
`-Laplacian[u] == 1` with `u == 0` on the 2x2 square it returns
`0.2946854143698992` at the centre, and the known torsion constant is
`0.29468541…`. A gate on a wrong closed form would have reported a defect
that does not exist.

Not changed, by decision:

- `PacletInfo.wl`. `Creator` / `PublisherID` / `URL` stay `"TODO-USER"` —
  they are the submitter's to fill in.
- No `Kernel/*.wl`. No `README.md`, no `Examples/`, no `docs/`.

## Round 2 — what changed, and what did not

Applied (all of it mine; no other agent's file was touched):

- `build/release.sh` + `build/release_verify.wl` — staging-copy packaging
  with end-to-end install proof, replacing the audit's "there is no
  mechanism" finding with an actual working route.
- `PacletInfo.wl` — `WolframVersion` kept as free text **with evidence**;
  `Creator` / `PublisherID` / `URL` set to `"TODO-USER"`; `Category` and
  `Categories` both carried; `Keywords` completed.
- `README.md` — the `## Install` section only. Nothing outside it was
  touched.
- `build/README-packaging.md` — this file.

Deliberately **not** changed in round 2:

- Every `PENDING` marker in `wfr/SpectralNDSolve.md`. At the time
  `Kernel/Solve.wl` was a stub and `SpectralNDSolve` had no `DownValues`;
  the solver was in flight with another agent, and no hedge was added
  anywhere. *(Superseded in round 3: the solver landed and the markers are
  resolved.)*
- No `Kernel/*.wl`, no `Tests/geoprobe.wl`, no `Tests/aaaprobe.wl`.
- No git command was run.

The round-2 `CURRENT STATE: BLOCKED` section below is kept verbatim as a
record. Its finding — `Syntax::sntue` in `Kernel/Solve.wl`, lines 142-146 of
`seDirLiftFn`, a `;` at the top level of `Do`'s argument list — was in
agent D's file and was **not** touched from here. Agent D fixed it; the
file is now 39,048 bytes and parses.

## Blockers before either channel ships

- [x] ~~**`SpectralNDSolve` and `SpectralNDSolveValue` have no
      definition.**~~ **Resolved in round 3.** `Kernel/Solve.wl` is 39,048
      bytes, both symbols have `DownValues`, and the install probe gates
      the solver's behaviour directly: 11 solver gates inside 56/56.
- [ ] **A solve with NO `DirichletCondition` does not return.** This is the
      one open blocker, and it is in `Kernel/`, not in the packaging.
      The homogeneous-Dirichlet fallback that API.md 4.3 specifies is
      documented but not working: with identically-zero Dirichlet data the
      lift constant is left non-numeric, so `LinearSolve` does not
      terminate. Measured on 2026-10-05 — a 900 s guard fired while the
      call was still inside `LinearSolve`
      (`Tests/out/installprobe.104951_54302.txt`) — and attributed step by
      step in `Tests/out/lsprobe.*` and `Tests/out/solvebisect.*`:
      `A0` is a numeric 49×49 `SparseArray` and
      `LinearSolve[A0, ConstantArray[0., 49]]` returns immediately, but
      `VectorQ[Flatten[rhs - liftConstant], NumericQ]` is `False`. The
      non-numeric part is `Kernel/Discretization.wl` L491-492 evaluating
      `N[0[x, y]]`, the *precision-tagged* zero `0.[x, y]` whose head is
      not `Real`. **Owner: agent D.** It is documented in the WFR document's
      `## Known Limitations` rather than hidden, and every example in that
      document supplies its own `DirichletCondition`, which is the path
      that is green.
- [ ] **WFR style guide: "There should only be one symbol (the function
      name) that users interface with."** The bundle exposes eight public
      symbols. `SpectralNDSolve` is the intended entry point and the other
      seven are the inspectable geometry/discretization layer, which
      `SpectralNDSolve` itself needs — it accepts a `SpectralDiscretization`
      directly and consumes it as-is, which is only possible because
      `SpectralDomain` is public. If a single-symbol submission is
      preferred, the lower seven can be made private without touching the
      method — the `Submission Notes` section says so.

## Reproducing every number quoted above

Every example and every `VerificationTest` expression in
`wfr/SpectralNDSolve.md` is re-run against the current tree by
`Tests/probes/p_docverify.wl`, evidence **`Tests/out/docverify_P_R4_FINAL.txt`:
55/55 pass, `DOCVERIFY-ALL-PASS`.** An earlier probe
(`Tests/out/q8probe.<stamp>.txt`) covered 16 of them against the
geometry-only bundle, back when `Kernel/Solve.wl` was a stub.

WL traps this work had to get past are documented at the point of use in
`build/bundle.wl` and `Tests/installprobe.wl`, each citing the evidence
file that pins it. The ones that cost real runs:

| Trap | Where pinned |
| --- | --- |
| `Put` returns `Null` and writes **nothing** under `wolframscript` | `Tests/out/w9probe.*.txt` |
| `StringJoin[list, "\n"]` appends `"\n"` instead of separating — use `StringRiffle` | `Tests/out/w10probe.*.txt` |
| `Import[…, "String"]` decodes bytes as Latin-1; one em dash became three characters. Use `"Text"` | `Tests/out/w11probe.*.txt` |
| `AppendTo[list, sublist]` nests, it does not splice | `Tests/out/w9probe.*.txt` §4 |
| `If[cond, a; b]` is a syntax error — a `;` at the top level of an argument list terminates the expression | `Tests/out/w6probe.*.txt` |
| `=/=` is **not** a WL operator; the spellings are `!=` and `=!=` | `Tests/out/w7probe.*.txt` |
| `Check[expr, "…"]` only detects a message when written **inline**; through a function argument it cannot | `Tests/out/q5probe.*.txt` |
| `VerificationTest` returns a `TestObject`, not `True`; the verdict is its `"Outcome"` key | `Tests/out/q10probe.*.txt` |
| `Count[list, f]` is 0 even when all match — `Count` wants a pattern, not a function | `Tests/out/q8probe.*.txt` |
| a bare `$` in a string *pattern* is the end-of-string anchor, so `StringFreeQ[t, "$InputFileName"]` gives a false negative | `Tests/out/q8probe.*.txt` |
## Round 3 — every edit, `file:line`

Dot-directory purge, `.agent-scratch` → non-dot:

| `file:line` | what changed |
| --- | --- |
| `build/release.sh:13` | the measured tree-size comment |
| `build/release.sh:35` | the "does not ship" list |
| `build/release.sh:56-61` | `SCRATCH="$ROOT/scratch"`, plus a note that API.md rule 4 forbids dot dirs |
| `build/release.sh:107` | `FORBIDDEN` list now contains `scratch` |
| `build/wlbal.py:15` | comment |
| `build/README-packaging.md` | four prose references (this file) |

Other round-3 edits:

| `file:line` | what changed |
| --- | --- |
| `build/release.sh:44-56` | header: `release.lastout` described as the summary it now is |
| `build/release.sh:212-224` | writes `build/release.lastout` and announces it |
| `Tests/installprobe.wl:42-48` | header: the stub claim replaced by the behaviour claim |
| `Tests/installprobe.wl:126-129` | scratch moved to `scratch/P/`, created if absent |
| `Tests/installprobe.wl:146-171` | new section 0 pre-clean, plus the `samevers` post-mortem |
| `Tests/installprobe.wl:176-182` | the archive-existed gate now gates on the archive, not the directory |
| `Tests/installprobe.wl:396-402` | the not-gated notice naming the zero-Dirichlet hang |
| `Tests/installprobe.wl:405-420` | `FileSize` → `QuantityMagnitude`, with both failures documented |
| `Tests/installprobe.wl:422-560` | section 8 rewritten: stub gate deleted, 11 behaviour gates added |
| `Tests/installprobe.wl:686-700` | the five-argument `If` fixed; unconditional FAIL list; `TALLY x/x PASS` as the last line |
| `wfr/SpectralNDSolve.md` | whole document rewritten: 7 `PENDING` → 0, plus new `## Performance` and `## Known Limitations` sections |
| `build/README-packaging.md` | this file: install facts, round-3 section, blockers, this list |

Probe sources whose evidence is cited moved out of `scratch/` and into
`Tests/probes/` (API.md rule 4), because they are re-runnable artifacts
rather than temporary scratch:

| probe | evidence it produced |
| --- | --- |
| `Tests/probes/p_docverify.wl` | `Tests/out/docverify_P_R4_FINAL.txt` — 62/62 |
| `Tests/probes/p_lsprobe.wl` | `Tests/out/lsprobe.stdout` — attributes the zero-Dirichlet hang |
| `Tests/probes/p_solvebisect.wl` | `Tests/out/solvebisect.stdout` — narrows it to `LinearSolve` |

Four more diagnostics (`loadcheck`, `solvetime`, `instprobe`, and the
intermediate `section8.txt`) were used only to find their way to the answer
above and were **deleted**; `Tests/out/loadprobe.*`, `…solvetime.*`,
`…instprobe.*` keep their captured output. `scratch/P/` is empty and is
re-created by `Tests/installprobe.wl` on each run.

### Round 4 file:line index

| `file:line` | change |
| --- | --- |
| `Tests/installprobe.wl:411-418` | stale "no-DC hangs / not gated" notice replaced |
| `Tests/installprobe.wl:646-688` | new section 8b: the no-DC gate |
| `Tests/installprobe.wl:691-722` | new section 8c: the `::nlift` negative control |
| `Tests/installprobe.wl:742` | `SpectralNDSolve::nlift` added to the reported names |
| `Tests/installprobe.wl:820-823` | the two new entries in the gate table (56 → 58) |
| `wfr/SpectralNDSolve.md:36-44` | bundle size + the two changed source SHA-256 rows |
| `wfr/SpectralNDSolve.md:57` | bundle SHA-256 |
| `wfr/SpectralNDSolve.md:59-68` | Definition warning → positive statement |
| `wfr/SpectralNDSolve.md:290-343` | new "Solving with no boundary condition" section |
| `wfr/SpectralNDSolve.md:643-674` | new `## Tests` gate block for the same |
| `wfr/SpectralNDSolve.md:~690` | Known Limitations: the hang bullet → the refusal contract |
| `wfr/SpectralNDSolve.md:~830` | Submission Notes: blocker bullet → "real and gated" |
| `wfr/SpectralNDSolve.md:539,641,829` | evidence filenames and tally updated to round 4 |
| `Tests/probes/p_docverify.wl:53` | `$InputFileName` depth fixed (2 → 3 `DirectoryName`s) |
| `Tests/probes/p_docverify.wl:57-66` | new hard abort gate: refuse to run if the package did not load |
| `Tests/probes/p_docverify.wl:~160` | round-4 doc section (7 checks) added |
| `build/README-packaging.md` | this file: round-4 section, gate table, this index |

`PENDING` count in `wfr/SpectralNDSolve.md`: **0**, unchanged.

Scratch used this round and **deleted** afterwards: `scratch/P/P_nodc.wl`,
`P_poly.wl`, `P_dv.wl`. Nothing was left in `scratch/P/`.
