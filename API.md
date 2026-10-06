# API.md — binding contract for `SpectralElement`

**Status: v0.1.0, in construction.** This file is the *contract*, not a
description: everything below marked **CONTRACT** is what other files and
other agents are allowed to rely on. Anything marked **ROADMAP** does not
exist yet and must not be referenced by shipped code.

Owner of this file: Wave 1 / S (skeleton). It changes only when S changes
it. If your implementation cannot satisfy a CONTRACT line, say so loudly
rather than quietly diverging.

---

## 1. What this package is

`SpectralElement`` is a multi-domain **spectral-element method (SEM)** solver
for 2D PDEs on **curved** domains, packaged as a Wolfram paclet.

Two layers, deliberately separated:

| Layer | Purpose | Entry points |
| --- | --- | --- |
| High | Look and feel like `NDSolve` | `SpectralNDSolve`, `SpectralNDSolveValue` |
| Low | Geometry and discretization you can inspect, reuse and test | `CoonsPatch`, `SpectralDomain`, `SpectralDomainData` |

The high layer is a thin shell over the low layer. Anything the solver does
must be reachable, and checkable, through the low layer alone.

---

## 2. Loader and context contract

### 2.1 Paclet layout

```
SpectralElement/
├── PacletInfo.wl               PacletObject[<| ... |>]
├── LICENSE                     MIT
├── README.md
├── API.md                      this file
├── Kernel/
│   ├── init.m                  fallback loader (see 2.4)
│   ├── SpectralElement.wl      the ONLY public entry point
│   ├── AAA.wl                  AAA approximation core          (owner: A)
│   ├── Geometry.wl             CoonsPatch, edge detection      (owner: B/G)
│   ├── Discretization.wl       SpectralDomain, assembly        (owner: B)
│   └── Solve.wl                Newton / linear solve           (owner: D)
├── Tests/                      probes + out/*.txt evidence
├── Examples/
└── docs/
```

`PacletInfo.wl` declares exactly one extension:

```wl
PacletObject[<|
    "Name" -> "SpectralElement",
    "Version" -> "0.1.0",
    "WolframVersion" -> "13.0+",
    ...
    "Extensions" -> {
        {"Kernel", "Root" -> "Kernel", "Context" -> {"SpectralElement`"}}
    }
|>]
```

`"Root" -> "Kernel"` is **required**: `Kernel` is not the default root of a
Kernel extension. With it, the context `SpectralElement`` resolves directly
to `Kernel/SpectralElement.wl`, so the following is the whole install story:

```wl
PacletDirectoryLoad["/path/to/SpectralElement"];
Needs["SpectralElement`"];
```

**CONTRACT.** `PacletDirectoryLoad[repoRoot]; Needs["SpectralElement`"]` must
succeed and must leave `Names["SpectralElement`*"]` containing at least the
eight public symbols listed in §4. Verified by `Tests/loadprobe.wl`
(see §7).

Notes on the paclet metadata:

- `PacletInfo.wl` is **read, not evaluated**. Every field value must be a
  literal. Never put a computed value there.
- The modern 12.1+ form is `PacletObject[<| "Key" -> value |>]` with
  **string** left-hand sides. The old `Paclet[Name -> "..."]` form still
  parses but is discouraged.
- `"License"` is not a built-in field; it is a legal **custom** field and is
  read back with `PacletObject["SpectralElement"]["License"]`.
- v1 declares **no** `Documentation` extension: there is no
  `Documentation/` tree yet. Do not declare one until there is one.

### 2.2 `Kernel/SpectralElement.wl` — exact contents

This file is the loader contract. It consists of `BeginPackage`, public
usage messages, `Begin["`Private`"]`, four `Get`s, `End[]`, `EndPackage[]`
— in that order. **Do not add or remove anything structural.**

```wl
BeginPackage["SpectralElement`"]
(* public usage messages for: CoonsPatch, CoonsPatchQ, SpectralDomain,
   SpectralDomainQ, SpectralNDSolve, SpectralNDSolveValue — write concise
   built-in-style usage strings covering the signatures in API.md *)
Begin["`Private`"]
Get[FileNameJoin[{DirectoryName[$InputFileName], "AAA.wl"}]]
Get[FileNameJoin[{DirectoryName[$InputFileName], "Geometry.wl"}]]
Get[FileNameJoin[{DirectoryName[$InputFileName], "Discretization.wl"}]]
Get[FileNameJoin[{DirectoryName[$InputFileName], "Solve.wl"}]]
End[]
EndPackage[]
```

`SpectralDomainData` and `CoonsPatchMap` also have usage messages there.
Adding one is safe: a `::usage::` in `BeginPackage` creates the symbol in the
public context, which is exactly what the fully-qualified definitions in the
subfiles need.

### 2.3 What that means for the subfiles — read this twice

The four subfiles are `Get`ted **from inside `Begin["`Private`"]`**.
Therefore:

1. **Bare symbols land in `SpectralElement`Private`.**
   `myHelper[x_] := x^2` written in `Geometry.wl` defines
   `SpectralElement`Private`myHelper`. That is the intended place for
   helpers.

2. **Public symbols MUST be written fully qualified.**
   ```wl
   SpectralElement`CoonsPatch[edges_, opts : OptionsPattern[]] := ...   (* correct *)
   CoonsPatch[edges_, opts : OptionsPattern[]] := ...                   (* WRONG *)
   ```
   The second line silently creates a *private* `CoonsPatch` and leaves the
   public symbol undefined. This is the single most likely way for this
   package to ship broken, and it fails silently.

3. **Subfiles MUST NOT use `BeginPackage` / `Begin` / `End`.** They are
   fragments, not packages. A `Begin["`Private`"]` inside a subfile will
   unbalance the loader's own `Begin`/`End` pair.

4. **Load order is load-bearing.** `AAA.wl` is loaded first so that
   `Geometry.wl` can use the AAA core for `Method -> "AAA"`. If you add a
   fifth subfile, add it here and document the ordering constraint.

5. `$InputFileName` is the path of `SpectralElement.wl` at the moment the
   `Get`s execute, so `DirectoryName[$InputFileName]` is the `Kernel/`
   directory. Do not hard-code absolute paths.

### 2.4 `Kernel/init.m`

Per the Wolfram *Paclets* tech note (section "init.m files"), a `Kernel`
extension with a declared `"Context"` needs **no** `init.m`: the file is
simply never read, and the docs call such a file "unnecessary and strongly
discouraged". The committed `init.m` is therefore a *fallback* that only
does something if the `Kernel/` directory is placed on `$Path` by hand. It
is guarded by `If[! ValueQ[SpectralElement`CoonsPatchQ], ...]` and is a
no-op once the package is loaded.

**CONTRACT.** Nothing that `SpectralElement.wl` needs may live in
`init.m`, because `init.m` may never run.

---

## 3. Kernel discipline (every agent, every run)

These are not style preferences. Each one exists because it cost a run.

1. **Run every WL script through the guarded runner**, never bare
   `wolframscript`:
   ```sh
   cd /path/to/SpectralElement
   ./rr.sh 120 Tests/<name>.wl
   ```
   `rr.sh` is the repo-local guarded runner: same semantics as the reference
   implementation's `r.sh` (timeout + `SIGKILL`, unique per-run output path,
   writes `<name>.lastout` containing `OUT=<path>`), but rooted in this repo
   and writing evidence to `Tests/out/`.

   `Tests/reference/specF/r.sh` is the guarded runner for the reference
   implementation. It `cd`s into its own directory and resolves both the
   script path and `$SPECF_OUT` relative to *that* directory, so it is
   self-contained and works from wherever the repository is checked out. Use
   `rr.sh` for this repo's own tests; use `r.sh` only to re-run the reference
   implementation.

2. **`pgrep -fl WolframKernel` after every run.** If your run was killed by
   the guard, the kernel is gone, but confirm it.

3. **Never `pkill`, `killall`, or `kill` a kernel you did not start.** Other
   sessions run kernels on this machine. If you believe you leaked one,
   report the PID from `pgrep` and let the owner decide.

4. **Scratch files stay inside the repo**, under `scratch/<your-tag>/` —
   a plain, non-dot directory. **Never a dot-prefixed directory**: dot dirs
   (`.agent-scratch` and friends) are treated as temporary and may be swept
   by any tool at any time; do not create them. Never `/tmp`, never
   `$TMPDIR`. Durable artifacts move out before delivery: probe sources
   whose evidence is cited → `Tests/probes/`, tooling → `Tools/`. Delete the
   rest when the task is done and say where it was. `scratch/` is
   git-ignored.

5. **The Wolfram Language newline trap.** At top level, a newline after a
   *syntactically complete* expression terminates it. A leading `+` on the
   next line does **not** continue it — it becomes a separate, discarded
   expression. Only an open bracket forces continuation. So:
   ```wl
   (* BROKEN: Lop becomes the first Kronecker product only *)
   Lop = KroneckerProduct[A, B]
       + KroneckerProduct[C, D];
   ```
   ```wl
   (* CORRECT: one line, or inside brackets *)
   Lop = KroneckerProduct[A, B] + KroneckerProduct[C, D];
   Do[..., {i, n}]   (* inside Do[...] the body is bracketed *)
   ```
   This exact bug cost five debug runs in the reference implementation
   (`p11dbg1-5`): `Lop` silently lost its second term and a gate read
   `3.5e4` instead of `1.9e-8`. **Any multi-line sum: one line, or inside
   brackets.**

6. **Every numerical claim needs an evidence file.** A number in `API.md`,
   `README.md`, `docs/AAA-NOTES.md` or a commit message must be traceable
   to a `Tests/out/*.txt` produced by an `rr.sh` run. If you did not run it,
   do not write it. Mark projections as projections.

7. **Treat `Tests/reference/specF/` as read-only.** It is the reference
   implementation — an independent second implementation of the same method,
   used to cross-check this package against Wolfram's built-in FEM. It lives
   in this repository (it used to be an external tree, which is how the
   absolute path of whoever developed it leaked into this repository's
   history). Read it, quote it, and run it to reproduce its numbers; do not
   edit it to make this package look better, and do not restate its results as
   ours. Its run output is deliberately not committed — re-running `r.sh`
   regenerates it.

8. **Do not run `git` commands.** The repo is shared by three parallel
   agents; the integrator commits.

9. **Four more traps, all found the hard way and all reproduced by
   `Tests/loadprobe.wl` against a throwaway control package:**

   - **`Context` is `HoldFirst`.** `Context[x]` where `x` is a *variable*
     reports the context of the variable (`Global``), not of the symbol it
     holds. The working form is `Context /@ listOfSymbols`. This will
     otherwise make you "discover" that your public symbols live in
     `Global``.
   - **A usage message is not a value.** For a symbol carrying only
     `::usage`, `OwnValues` and `DownValues` are both `{}`, and
     `Information[sym]` prints **nothing** under `wolframscript`. Worse,
     `ValueQ[sym]` is `False`, so `ValueQ` is **not** a valid "is the
     package loaded" guard — use `MemberQ[$ContextPath, "Ctx`"]`. Script-side
     proof that a public symbol exists is `SymbolName` plus
     `Names["Ctx`*"]`; read the usage text interactively with `?symbol`.
   - **`PacletObject["/some/path"]` is the paclet-NAME form** (a string is
     a name, not a path) and every property comes back `Missing`. Use
     `PacletObject[File[dir]]` to read a directory paclet's metadata.
   - **A literal backtick in a string needs no escaping, and `` \` `` is
     NOT an escape for it.** `"Ctx`"` is the context; `"Ctx\`"` is
     something else entirely. Writing `` \` `` is how you end up calling
     `ToExpression` on a mangled name and concluding your symbols are in
     `Global``.

10. **A bracket-balance check before you run.** One missing `]` in a probe
    script silently truncated the tail of the output — including the
    verdict line — while the earlier lines looked perfectly healthy. Count
    brackets (skipping `(* comments *)` and strings) or, better, confirm
    your evidence file ends with the expected final line. A truncated run
    is worse than a failed run, because it looks like a pass.

---

## 4. Public API

Eight symbols in the context `SpectralElement``. All usage strings live in
`Kernel/SpectralElement.wl`; the definitions live in the subfiles.

| # | Symbol | Layer | Defined in |
| --- | --- | --- | --- |
| 1 | `CoonsPatch` | geometry | `Geometry.wl` |
| 2 | `CoonsPatchQ` | geometry | `Geometry.wl` |
| 3 | `CoonsPatchMap` | geometry | `Geometry.wl` |
| 4 | `SpectralDomain` | discretization | `Discretization.wl` |
| 5 | `SpectralDomainQ` | discretization | `Discretization.wl` |
| 6 | `SpectralDomainData` | discretization | `Discretization.wl` |
| 7 | `SpectralNDSolve` | solver | `Solve.wl` |
| 8 | `SpectralNDSolveValue` | solver | `Solve.wl` |

### 4.1 `CoonsPatch` — geometry layer

```wl
CoonsPatch[{bottom, top, left, right}, opts]
CoonsPatchQ[expr]
CoonsPatchMap[patch, \[Xi], \[Eta]]
```

**CONTRACT.**

- The first argument is a list of **exactly four** boundary curves, each a
  pure function `t \[Function] {x, y}`.
- `bottom` and `top` are parameterized by `t = \[Xi]` with `t` running over
  `\[Minus]1 <= t <= 1`, and lie on `\[Eta] = \[Minus]1` and `\[Eta] = 1`.
- `left` and `right` are parameterized by `t = \[Eta]` with `t` running over
  `\[Minus]1 <= t <= 1`, and lie on `\[Xi] = \[Minus]1` and `\[Xi] = 1`.
- Order of the list is `{bottom, top, left, right}` — bottom first, and the
  two `\[Xi]`-edges before the two `\[Eta]`-edges.
- **Corner closure is checked**, exactly as `mkMap4` in the reference does:
  the four corner values must agree to within `1*^-12` (max over the four
  pairwise differences of the four corner points). Otherwise
  `CoonsPatch::corners` is issued and the patch is rejected.
- `Method -> "Analytic"` (default) evaluates the four curves exactly.
- `Method -> "AAA"` fits each sampled curve with the AAA core in `AAA.wl`.
  **The branch is wired (wave 2, verified: `Tests/aaageom.wl` 68/68,
  `Tests/geoprobe.wl` G-B1d).** Each edge is sampled on an extended
  interval `[-1-d, 1+d]` (`d = 2.5 1.*^-4`), both coordinate functions are
  fit by the AAA rational core, and a dense finiteness probe rejects any
  fit that misbehaves before the corner/tangent checks run. The sample
  count is the `AAASamples -> 65` option on `CoonsPatch` (sanitised: any
  non-numeric or `< 4` value falls back to 65 — a typo is ignored, not
  reported). Any failure in the AAA path issues `CoonsPatch::method` and
  returns `$Failed` — there is **no silent fallback to `"Analytic"`**
  (negative controls in aaageom G6 and geoprobe G-B1d). Verified A/B:
  on smooth boundaries the AAA patch is numerically indistinguishable
  from Analytic (accuracy delta 0–0.2 %, round-off level) at ~510× the
  per-patch construction cost — the right trade only when the boundary
  arrives as data rather than as a callable.
- Returns a `CoonsPatch` object exposing the transfinite map. The reference
  map, reproduced exactly, is
  ```wl
  sm[\[Xi]_, \[Eta]_] := Module[{a0 = (1 - \[Xi])/2, a1 = (1 + \[Xi])/2,
      b0 = (1 - \[Eta])/2, b1 = (1 + \[Eta])/2},
    b0 bottom[\[Xi]] + b1 top[\[Xi]] + a0 left[\[Eta]] + a1 right[\[Eta]]
     - (a0 b0 V1 + a1 b0 V2 + a0 b1 V3 + a1 b1 V4)]
  ```
  where `V1 = bottom[\[Minus]1]`, `V2 = bottom[1]`, `V3 = top[\[Minus]1]`,
  `V4 = top[1]` are the four corners, in `(xi, eta)` order
  `(-1,-1), (1,-1), (-1,1), (1,1)` — so the bilinear weights
  `a0 b0`, `a1 b0`, `a0 b1`, `a1 b1` above pick up `V1..V4` in that
  order. (`Kernel/Geometry.wl` `seCorners` / `seTransfinite` is the
  authority.) It is exposed as
  `SpectralElement`CoonsPatchMap[patch, \[Xi], \[Eta]]`, which **is public**
  and whose usage message lives in `Kernel/SpectralElement.wl` (definition
  owner: B).
- `CoonsPatchQ[expr]` is `True` for a valid patch, `False` otherwise.
  Check the tag, not the field pattern alone.
- **`Format`** must give a built-in-style short form, e.g.
  `CoonsPatch[2 patches]` / `CoonsPatchObject[1 patch]`, with a
  `TraditionalForm` variant. Owner: B. Do **not** put `Format` in
  `SpectralElement.wl` — the loader file carries no definitions.

**Trap, verified in the reference (`p11.wl` lines 6–9, 114, and `p11m4`):**
the transfinite map has `J = 0` at the four patch corners when two adjacent
boundary curves share a tangent there. A transfinite patch therefore
requires the patch vertices to be **true corners of the domain**. A smooth
annulus edge sampled as a single patch (`starA2` in the reference) gives
`J`corner `~ -2e-11` and must be **rejected**. This is not a numerical
tolerance question; it is a modelling requirement.

### 4.2 `SpectralDomain` — discretization layer

```wl
SpectralDomain[patches_List, n_Integer, opts]
SpectralDomain[region, n_Integer, opts]
SpectralDomainQ[expr]
SpectralDomainData[disc, "key"]
```

**CONTRACT — patch-list form.**

- `patches` is a non-empty list of `CoonsPatch` objects; **all of them use
  the same degree `n`** (v1 restriction, §5).
- Every patch is discretized on the degree-`n` Chebyshev–Gauss–Lobatto
  grid in each direction, `n+1` nodes per direction, laid out exactly as
  the reference: `xg = yg = cgl[\[Minus]1., 1., n+1]` with
  `cgl[a_, b_, nn_] := Table[(a+b)/2 - (b-a)/2 Cos[k Pi/(nn-1)],
  {k, 0, nn-1}]`, and node vector `nodeVec[m_] := Flatten[Transpose[m]]`
  (**`\[Xi]` is the fast index**; the `\[Xi]`-operator is the *second*
  Kronecker argument). Getting this backwards is a silent, catastrophic
  error.
- **Shared-edge detection is by sampling, not by bookkeeping.** For each
  candidate pair of edges from different patches, compare the endpoints and
  the interior Chebyshev nodes of the two traces; they match when every
  comparison is within `"InterfaceTolerance"` (default `1*^-10`). Two edges
  that match form one interface.
- **Interface unknowns are shared (C0 continuity).** Both patches read and
  write the *same* vector of interface values, so the trace is continuous
  pointwise with no cross-grid interpolation. In the reference this is the
  `rules1`/`rules2` selection block: each patch gets an `M` selection
  matrix mapping the global unknown vector into its local node vector, with
  interior nodes getting their own slot and interface nodes pointing at one
  shared slot.
- **Normal-flux continuity rows are added exactly as section E2 of `p11.wl`
  does.** For an interface arc that is an `\[Eta]`-edge on both sides (the
  reference's radial split), the normal derivative along `grad(\[Eta])` is
  assembled from the four metric coefficients `a = y_[\[Eta]]/J`,
  `b = -y_[\[Xi]]/J`, `c = -x_[\[Eta]]/J`, `d = x_[\[Xi]]/J` as
  ```wl
  d/dn = [(a b + c d) u_[\[Xi]] + (b^2 + d^2) u_[\[Eta]]] / Sqrt[b^2 + d^2]
  ```
  (flat limit `\[Rule] u_y`). One row per interior interface node:
  `NDopA.M1 - NDopB.M2`, i.e. the left trace minus the right trace, so the
  orientation of the two patches must be chosen so that `grad(\[Eta])` points
  the *same* way on both sides (`J > 0` on both).
- The returned object is a `SpectralDiscretization` carrying, at minimum:
  the per-patch node coordinates, the Chebyshev differentiation matrices,
  the assembled Laplacian/operator blocks, the selection matrices, the row
  classification (`"InteriorRows"`, `"BoundaryRows"`, `"FluxRows"`), and the
  total unknown count.

**CONTRACT — region-shorthand form.**

`SpectralDomain[region, n, opts]` auto-builds the patches from:

| Region | Supported in v1 | Notes |
| --- | --- | --- |
| `Rectangle[{x1, y1}, {x2, y2}]` | yes | one patch, straight edges |
| `Annulus[{r1, r2}, {\[Theta]1, \[Theta]2}]` | yes | **requires `r1 > 0`**; splits radially into ceil/floor patches according to `opts` |
| `Disk[...]` | **no** | message + roadmap, see below |
| `Polygon[...]` | **no** | roadmap |
| anything else | no | `SpectralDomain::nreg` |

**Why not `Disk` in v1.** The transfinite map on a disk degenerates: with a
polar parameterization the reference corner `r = 0` collapses every
`\[Xi] = \[Eta]` combination onto the same physical point, so the Jacobian
`J = r d\[Theta]/dr` is exactly `0` there and the map is not invertible. The
metric coefficients `1/J` are singular, and every operator built from them is
infinite. An `Annulus` with `r1 > 0` has no such point, which is exactly why
it is the supported shape. Supporting a disk requires either a
centre-point singularity treatment (a pole condition replacing the PDE rows
there) or a non-polar transfinite map with a non-degenerate centre — both are
real work, so `Disk` is **ROADMAP**, not a v1 bug. `Disk` must issue a
message (`SpectralDomain::nreg`) naming the roadmap, never silently produce a
wrong Jacobian.

**CONTRACT — `SpectralDomainData`.**

```wl
SpectralDomainData[disc, "key"]
```

Supported keys: `"Nodes"`, `"PatchCount"`, `"Degree"`, `"UnknownCount"`,
`"InterfacePairs"`, `"InteriorRows"`, `"BoundaryRows"`, `"FluxRows"`,
`"PatchMap"`, `"Jacobian"`, plus the coordinate views `"X"`, `"Y"` and
`"Coordinates"` (per-patch `{nn, nn}` list of `{x, y}` pairs, consistent with
`"X"`/`"Y"` to 0.; served by the accessor, so `Keys[disc]` does not list it).
The full set is enumerated in `Kernel/Discretization.wl` (`seDataKeys`).
An unknown key gives a message; it does not
return `$Failed` silently.

### 4.3 `SpectralNDSolve` / `SpectralNDSolveValue` — solver layer

```wl
SpectralNDSolve[eq, u, {x, y} \[Element] \[CapitalOmega], n, opts]
SpectralNDSolveValue[eq, u, {x, y} \[Element] \[CapitalOmega], n, opts]
```

**CONTRACT.**

- Return shape mimics `NDSolve`: `SpectralNDSolve` returns
  `{{u -> Function[...]{...}}}`, i.e. a list containing the rule list.
  `SpectralNDSolveValue` returns the function itself.
- `\[CapitalOmega]` may be a `CoonsPatch` list, an already-built
  `SpectralDiscretization` (so the user can inspect/optimise it and reuse
  it), or a region shorthand.
- `eq` is an equation (or a list containing one equation plus conditions) in
  the form `lhs == rhs` with `u` an `InterpolatingFunction`-valued
  application, e.g. `Laplacian[u[x, y], {x, y}] == f[x, y]`.
- **Dirichlet data only in v1.** `DirichletCondition[...]` terms are
  honoured, with the region given as a predicate (as in `NDSolve`). If `eq`
  contains **no** `DirichletCondition`, homogeneous Dirichlet data (`u == 0`)
  is imposed on the entire exterior boundary.
- **Linear** problems are assembled and solved directly (`LinearSolve`).
  **Nonlinear** problems go through Newton's method; `Method -> "Newton"` is
  the default *when the equations are nonlinear*, and the iteration history
  must be recorded so quadratic convergence can be asserted by tests
  (`dels` in the reference: each step roughly squares the previous one).
  A reference sequence from `p11.191455_3044.txt`:
  `{1.157, 0.0520, 2.78e-4, 7.41e-9, 1.90e-13, 8.77e-14}`.
- Newton must stop on a residual/step tolerance, must be capped at a fixed
  iteration count, and on failure must issue `SpectralNDSolve::nlnum`
  carrying the last residual and iteration count. A non-numeric result from
  `LinearSolve` must be caught, not propagated.
- Operator-sign convention, pinned by the reference: the discretized
  operator is `+Laplacian`. A PDE written as `-Laplacian[u] + u^3 == f`
  therefore assembles as `-Lop.U + U^3`. Do not "fix" this by flipping a
  sign somewhere; get it right once, here, and test it.

### 4.4 Messages

**CONTRACT.** These message names must exist and must be issued from the
owning file. A message name that does not exist raises a `Message::name`
warning at the call site — that is a test failure, not a cosmetic issue.

| Message | Issued by | Meaning |
| --- | --- | --- |
| `CoonsPatch::corners` | `Geometry.wl` | corner closure exceeded `1*^-12` |
| `CoonsPatch::method` | `Geometry.wl` | unknown/unwired `Method` value |
| `SpectralDomain::nreg` | `Discretization.wl` | unsupported region (e.g. `Disk`, `r1 == 0`) |
| `SpectralDomain::iface` | `Discretization.wl` | edges matched within tolerance but orientations disagree, or an interface was matched twice |
| `SpectralNDSolve::nlnum` | `Solve.wl` | Newton failed to converge |
| `SpectralNDSolve::ncond` | `Solve.wl` | no boundary condition and default not applicable |

### 4.5 Verified reference numbers (do not restate as our own)

These come from the **reference implementation**,
`Tests/reference/specF/p11.wl`. Run it to reproduce them:

```sh
cd Tests/reference/specF && ./r.sh 300 p11.wl
```

Its output is not committed; the numbers below are the recorded results of
that run. They establish that the method works; they are **not** yet results
of this package. When the package reproduces them, cite the package's own
`Tests/out/*.txt`.

- PDE `-Laplacian[u] + u^3 = f` with manufactured solution
  `uex = Sin[2x+1] Cos[3y-1] + xy/5` on a **pincushion** domain (single
  patch, four quadratic concave arcs, `gamma = 0.6`): nodal error at the
  interior nodes `1.6e-12`, `4.0e-15`, `8.5e-15` for `n = 16, 24, 32`.
- **Half-annulus** `r \[Element] [1,2]`, `\[Theta] \[Element] [0, \[Pi]]`,
  split radially at `r = 1.5` into two patches: error `3.7e-4`, `2.2e-7`,
  `7.9e-11` (patch A) and `7.8e-4`, `1.3e-6`, `7.8e-10` (patch B) for
  `n = 16, 24, 32`. That is spectral/geometric convergence, and patch B is
  consistently ~10x worse because it covers the larger radius.
- Per-block residuals at convergence (`G6`): PDE blocks `~1e-10`, flux block
  `~1e-12`. `G7`: the flux row applied to the **exact** grid function of
  `uex` gives `~1e-13`, i.e. the curved-interface operator is consistent, not
  merely self-consistent at the computed solution.
- Built-in FEM (`ToElementMesh` + `NDSolve` on the same half-annulus)
  evaluated at the *same* points: `8.4e-3`, `9.1e-4`, `1.5e-4`, `1.8e-5` for
  four refinement levels — convergence rates `{3.21, 2.63, 3.03}` versus
  `3` for the spectral method, but it needs a fourth level and 11688
  elements to reach `1.8e-5`. This is the comparison the benchmarks section
  will reproduce.

---

## 5. v1 constraints (say no to everything else)

1. **One `n` for every patch.** No per-patch grading, no hp refinement.
2. **Dirichlet conditions only.** No Neumann, Robin, periodic, or interior
   constraints.
3. **No `Disk`.** Annulus with `r1 > 0` instead (§4.2).
4. **No automatic polygon decomposition.** `Polygon` inputs are not
   automatically split into transfinite patches.
5. **`Method -> "AAA"` is wired (wave 2 done)** — it runs the AAA fit;
   failures issue `CoonsPatch::method` and never fall back silently to
   `"Analytic"`.
6. **2D only**, and only the second-order form `-Laplacian[u] + f(u) == g`
   plus whatever the reference operator assembly already covers. No
   time-dependent problems, no eigenvalue problems, no adjoint.
7. **No automatic `Loading -> "Automatic"`**. Keep `Manual`; the solver
   decides when to build the discretization, not the paclet system.

### ROADMAP (not v1 — do not code against these)

- `Disk` via a pole/centre treatment, and `Polygon` with automatic
  transfinite decomposition (corner detection, edge splitting).
- Per-patch `n` and `hp`-adaptivity.
- Neumann / Robin / periodic boundary conditions; natural BC rows.
- AAA-fitted curved boundaries (`Method -> "AAA"`), the headline feature.
- Time-dependent and eigenvalue problems; `Method -> "NewtonLineSearch"`,
  `"NewtonTrustRegion"`.
- A `Documentation/` extension with WL notebooks (once they exist).
- Packed `.paclet` release + Function Repository submission.

---

## 6. Waves and ownership

Three waves, three parallel agents per wave. **You own only the files in
your row. Create-if-missing, never overwrite another agent's file.**

### Wave 1 (running now)

| Agent | Owns | Also writes |
| --- | --- | --- |
| **S (skeleton)** | `PacletInfo.wl`, `LICENSE`, `.gitignore`, `Kernel/init.m`, `Kernel/SpectralElement.wl`, `API.md`, `README.md` | `Tests/loadprobe.wl`, `Tests/out/` |
| **A (AAA core)** | `Kernel/AAA.wl` | `Tests/aaaprobe.wl`, `docs/AAA-NOTES.md` |
| **B (Geometry)** | `Kernel/Geometry.wl`, `Kernel/Discretization.wl` | `Tests/geoprobe.wl` |

### Wave 2

| Agent | Owns | Also writes |
| --- | --- | --- |
| **D (Solve)** | `Kernel/Solve.wl` | solve + benchmark tests, `Tests/out/bench-*.txt` |
| **G (AAA wiring)** | wiring of `Method -> "AAA"` into `CoonsPatch` | `Tests/aaageom.wl` |

### Wave 3

| Agent | Owns |
| --- | --- |
| **E (Docs/Release)** | `README.md` rewrite, `Examples/`, Wolfram Function Repository submission |

**Integration order.** Wave 2/3 agents start only after Wave 1 has run
`Tests/loadprobe.wl` green, because everything downstream codes against the
§2 loader contract. If `loadprobe.wl` fails, the failure is S's to fix.

---

## 7. Evidence index

| File | What it proves |
| --- | --- |
| `Tests/out/loadprobe.<stamp>.txt` | `PacletDirectoryLoad` + `Needs` works; the eight public symbols resolve in `SpectralElement`` with usage messages |
| `Tests/out/aaaprobe.<stamp>.txt` | AAA approximation accuracy (owner A) |
| `Tests/out/geoprobe.<stamp>.txt` | Coons map, corner closure, `J > 0`, shared-edge detection (owner B) |
| `Tests/out/bench-*.txt` | error-vs-`n` and error-vs-FEM (owner D) |

`loadprobe` also reads this run's `stdout` back and echoes every message
raised during the load, with its file and line. That makes it a cheap way
for the integrator to see the state of the other subfiles without running
their probes: a `Syntax::sntx` naming `Kernel/AAA.wl` line 323 is agent A's
problem, not the loader's, and does not affect the `VERDICT`.

Every claim in this file, in `README.md`, and in `docs/AAA-NOTES.md` must
name one of these. Numbers without an evidence file are not allowed.
