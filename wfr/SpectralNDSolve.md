---
Template: FunctionResource
Name: SpectralNDSolve
ContributedBy: [YOUR NAME -- EDIT THIS: the submitter must fill in their own name here]
Description: Solve a linear or semilinear elliptic PDE on a tensor-product spectral-element patch or a multi-patch curved domain, with Chebyshev collocation and Newton's method
Version: 0.1.0
Categories: [Symbolic & Numeric Computation, Geometry]
Keywords: [partial differential equations, spectral method, spectral element method, Chebyshev, collocation, transfinite interpolation, Newton method, NDSolve]
SeeAlso: [NDSolve, NDSolveValue, ElementMesh, ToElementMesh, BoundaryDiscretizeRegion, FiniteElementMethod]
Links: [https://github.com/spectralelement/SpectralElement]
EntrySymbol: SpectralNDSolve
Context: SpectralElement`
License: MIT
---

## Definition

`SpectralNDSolve` is the solver entry point of the `SpectralElement`
package. It solves a second-order PDE — linear or semilinear — on a curved
quadrilateral patch, or on a multi-patch domain, by a **multi-domain
spectral-element method**: each patch is a transfinite (Coons)
interpolation of four boundary curves, is discretized on a
Chebyshev–Gauss–Lobatto grid, and patches that share a geometric edge share
one unknown per physical node, with an explicit normal-flux continuity row
per shared node. Linear systems go straight to `LinearSolve`; anything
with a nonlinear term in `u` goes to Newton's method, and the iteration
history is recorded so quadratic convergence is assertable by a test.

The implementation is the file **`wfr/SpectralNDSolve.wl` in this
submission, inlined in full below**. It is a *generated* file, not a
hand-written one: `build/bundle.wl` reads the package loader
`Kernel/SpectralElement.wl` and replaces each of its four
`Get[FileNameJoin[...]]` statements with the verbatim text of the file it
names. The inlined blocks are delimited by comments naming the source file
and its SHA-256, so every byte of the implementation is traceable. As
built, the bundle is **151,810 characters (151.8 KB)**, and the four
inlined sources hash to

| source | bytes | SHA-256 (`shasum -a 256`) |
| --- | --- | --- |
| `Kernel/AAA.wl` | 30,315 | `bbdfecd3e451c836870a1b66838af198e30e5d84b391d3b8e5fcc44d16494cd7` |
| `Kernel/Geometry.wl` | 27,169 | `4b4435fc7f530164cb7267d42416df3e39d4493067569456db5241d7ed17f066` |
| `Kernel/Discretization.wl` | 45,024 | `2fe71d6926db6e437fbc563c8a6f69ed41fafc7ab703b6010bccaf83bf331f6f` |
| `Kernel/Solve.wl` | 40,932 | `aca403e21e251ac8fdcdf08d884b24efd71b42cae9104a5bd24beae8357210ed` |

The in-file markers carry the same four digests in Wolfram's decimal
integer form, which is why the numbers printed there look unlike these.
Both spellings are the same 256-bit SHA-256 value; the hex form is the one
`shasum -a 256` prints, and it is the form to check against.

**GENERATED FILE — DO NOT EDIT.** Regenerate with `./build/bundle.sh`.

Two properties of the bundled file are load-bearing for the Function
Repository, and both are asserted by the build on every run:

- **Self-contained.** There is no `$InputFileName`, no `Get` and no
  `FileNameJoin` anywhere in it, so it loads as a single unit with no
  external code source, as the repository requires. The build counts all
  four and fails if any is non-zero.
- **Deterministic.** The build contains no timestamp, so an unchanged
  source tree always produces a byte-identical bundle. Verified by
  building twice: same SHA-256
  (`733af4ac06369673f869ec6708bdb43af4286917e9fdf09ed29f8d93b5114f37`, check
  with `shasum -a 256 wfr/SpectralNDSolve.wl`) and byte-identical evidence.

> **No boundary data? That case is supported.** When the equation list
> contains no `DirichletCondition`, homogeneous Dirichlet data (`u == 0`) is
> imposed on the whole exterior boundary, and that path is tested like any
> other: it returns in `0.016 s`, `u` is `0` *exactly* at the boundary, and
> the interior reproduces a closed-form solution to `2.9·10^-15`. Dirichlet
> data that cannot be evaluated to numbers are then **refused by name** with
> `SpectralNDSolve::nlift` rather than silently zeroed. See
> [Solving with no boundary condition](#solving-with-no-boundary-condition).

## Usage

```
SpectralNDSolve[eq, u, {x, y} ∈ Ω, n, opts]
SpectralNDSolveValue[eq, u, {x, y} ∈ Ω, n, opts]
```

- `eq` — a single equation, or a list of equations, in which `u` appears as
  an application to the independent variables; for example
  `Laplacian[u[x, y], {x, y}] == f[x, y]`. The Laplacian term is recognized
  in either sign, because `Laplacian` does not keep its head — the kernel
  rewrites it to `Derivative[0, 2][u][x, y] + Derivative[2, 0][u][x, y]`
  and the parser matches on those pure-derivative terms. `DirichletCondition`
  terms in the same list are honoured; each contributes one boundary
  predicate plus a value.
- `u` — the dependent-function symbol.
- `{x, y} ∈ Ω` — the independent variables and the domain. `Ω` may be
  - a list of `CoonsPatch` objects,
  - an already-built `SpectralDiscretization`, which is **consumed as-is**
    and never rebuilt, or
  - a region shorthand: `Rectangle[{x1, y1}, {x2, y2}]` or
    `Annulus[{r1, r2}, {θ1, θ2}]` with `r1 > 0`.
- `n` — the polynomial degree of every patch, an integer `>= 2`. Version 1
  uses one `n` for the whole domain; there is no per-patch grading.
- `opts` — options, as listed under [Details & Options](#details-and-options).

`SpectralNDSolve` returns the solution in the same shape as `NDSolve`: a
list containing a single list of rules,

```
SpectralNDSolve[…]
```

is `{{u -> Function[…][…]}}`.

`SpectralNDSolveValue` takes the same arguments and options and gives the
solution as a pure function, with no rule wrapper:

```
SpectralNDSolveValue[…]
```

## Basic Examples

Every output quoted below was copied from a captured run rather than
written from memory. The evidence files are named in place.

### A transfinite patch from four boundary curves:

The four edges are pure functions of one parameter. `bottom` and `top` run
along `η = -1` and `η = +1`, parametrized by `ξ`; `left` and `right` run
along `ξ = -1` and `ξ = +1`, parametrized by `η`. The patch vertices must
be **true corners** of the domain.

```
edges = {Function[t, {2 t, -1}],      (* bottom, t = \[Xi] *)
         Function[t, {2 t, 1}],       (* top,    t = \[Xi] *)
         Function[t, {-2, t}],        (* left,   t = \[Eta] *)
         Function[t, {2, t}]};        (* right,  t = \[Eta] *)

patch = CoonsPatch[edges]
```

> `CoonsPatch` returns an association carrying the transfinite map, the
> four corners, the corner closure, the corner tangents and the map's
> `"Method"` tag. For these four straight edges the corner closure is `0.`
> exactly.

The map evaluated at a point of the reference square:

```
CoonsPatchMap[patch, 0.3, -0.5]
```

> `{0.5999999999999999, -0.5}` — the exact answer is `{0.6, -0.5}`; the
> last-bit difference is floating-point arithmetic, not an error.

And at a corner, which must reproduce the vertex exactly:

```
CoonsPatchMap[patch, -1., -1.]
```

> `{-2., -1.}` — the bottom-left vertex, i.e. the map is continuous and
> closed at the corners.

### Discretizing a patch, and reading the assembly back:

```
disc = SpectralDomain[{patch}, 8]
```

> A `SpectralDiscretization`.

```
SpectralDomainData[disc, "PatchCount"]
```

> `1`

```
SpectralDomainData[disc, "Degree"]
```

> `8`

```
SpectralDomainData[disc, "UnknownCount"]
```

> `49`, which is `(n - 1)^2` for a single patch: every boundary node is
> lifted away, leaving a square `(n-1)×(n-1)` interior system.

```
SpectralDomainData[disc, "RowCount"]
```

> `49` — equal to `UnknownCount`, so the assembled system is square.

```
SpectralDomainData[disc, "Nodes"]
```

> The `n+1 = 9` Chebyshev–Gauss–Lobatto nodes per direction.

```
SpectralDomainData[disc, "InterfacePairs"]
```

> `0` — a one-patch domain has no second patch to share an edge with.

```
SpectralDomainData[disc, "MinJacobian"]
```

> `{1.9999999999999882}` — one entry per patch. The analytic value is `2`
> (`dx/dξ = 2`, `dy/dη = 1`), and the relative deviation is `5.9·10^-15`,
> which is the accuracy of the Chebyshev differentiation matrix.

### Solving a linear Poisson problem

The manufactured pair used throughout the tests. `uexz` is an *exact*
solution of `-Laplacian[u] == fLin`, so the difference between the returned
interpolant and `uexz` is a genuine numerical error and nothing else.

```
uexz[x_, y_] := Sin[2 x + 1] Cos[3 y - 1] + x y/5;
fLin = -Laplacian[uexz[x, y], {x, y}];
rect = Rectangle[{-1.5, -1.2}, {1.8, 1.3}];
bd = Abs[x + 1.5] < 1.*^-8 || Abs[x - 1.8] < 1.*^-8 || Abs[y + 1.2] < 1.*^-8 || Abs[y - 1.3] < 1.*^-8;

sol = SpectralNDSolve[{-Laplacian[u[x, y], {x, y}] == fLin,
       DirichletCondition[u[x, y] == uexz[x, y], bd]}, u,
     {x, y} \[Element] rect, 16]
```

> `{{u -> Function[{qx, qy}, …]}}` — the `NDSolve` shape. The wall time at
> degree 16 is `0.113 s` and the residual of the assembled system at the
> computed solution is `2.16·10^-12`.

```
uf = sol[[1, 1, 2]];
{uf[-0.5, 0.3], N[uexz[-0.5, 0.3]]}
```

> `{-0.02999999999604433, -0.03}`

```
points = {{-0.5, 0.3}, {0.1, 0.2}, {-0.4, 0.6}, {0.9, -0.7}, {0.6, 0.8}};
Max[Abs[uf[#[[1]], #[[2]]]] - uexz[#[[1]], #[[2]]]]] & /@ points
```

> `2.7444280181754266·10^-10` — the largest error over those five interior
> points at degree 16, consistent with the spectral convergence study
> below, which reaches `4.4654946407263196·10^-11` measured at *every*
> node. The trailing `&` is load-bearing: `expr /@ listOfPairs` threads
> the list into `expr`'s *pattern variables*, so the interpolant is asked
> for `uf[{-0.5, 0.3}, {0.1, 0.2}, ...]` and answers `Indeterminate`.
> `expr //@ points` has the same fault. Wrap in a pure function of one
> argument.

### A nonlinear problem: `-Laplacian[u] + u^3 == f`

The same manufactured solution, with `uexz^3` added to the right-hand side,
forces the Newton path.

```
fNl = -Laplacian[uexz[x, y], {x, y}] + uexz[x, y]^3;

solNl = SpectralNDSolve[{-Laplacian[u[x, y], {x, y}] + u[x, y]^3 == fNl,
        DirichletCondition[u[x, y] == uexz[x, y], bd]}, u,
      {x, y} \[Element] rect, 16]
```

> `{{u -> Function[{qx, qy}, …]}}` again, this time from Newton's method.
> Wall time `0.112 s`, five Newton iterations, max nodal error
> `4.455436020123216·10^-11`.

The Newton step history for that solve is the evidence that the
convergence is quadratic rather than merely fast — each step roughly
doubles the number of correct digits, which is the `p11`-style signature:

| step | ‖Δu‖ | digits gained |
| --- | --- | --- |
| 1 | `1.3901856145602998` | — |
| 2 | `0.05936846235455953` | `1.370` |
| 3 | `0.0007124357869786121` | `1.921` |
| 4 | `1.1716958224295765·10^-7` | `3.784` |
| 5 | `4.053547543959682·10^-15` | `7.461` |

`SpectralNDSolveValue` gives the same answer without the rule wrapper:

```
SpectralNDSolveValue[{-Laplacian[u[x, y], {x, y}] == fLin,
    DirichletCondition[u[x, y] == uexz[x, y], bd]}, u,
  {x, y} \[Element] rect, 16]
```

> A pure `Function[{qx, qy}, …]`, so the solution is used directly as
> `f[a, b]`.

### Solving with no boundary condition

If the equation list contains no `DirichletCondition`, `u == 0` is imposed
on the whole exterior boundary. To make that path checkable the example
below uses a manufactured solution that *vanishes* on every edge of the
square, so the closed form is consistent with the default data:

```
poly[a_, b_] := (1 - a^2) (1 - b^2);      (* 0 on all four edges, 1 at the centre *)

SpectralNDSolve[{-Laplacian[u[x, y], {x, y}] == -Laplacian[poly[x, y], {x, y}]}, u,
  {x, y} \[Element] Rectangle[{-1, -1}, {1, 1}], 12]
```

> `{{u -> Function[{qx, qy}, …]}}` in `0.016 s`, with a final residual of
> `5.3·10^-14`.

```
uf0 = %[[1, 1, 2]];
{uf0[1., 0.], uf0[-1., 0.], uf0[0., 1.], uf0[0., -1.], uf0[0.5, 1.], uf0[-0.5, -1.]}
```

> `{0., 0., 0., 0., 0., 0.}` — exactly zero at six points of the exterior
> boundary, not merely small. The install probe gates this as
> `=== 0.`, so a small non-zero value would fail it.

```
pts = {{0.25, 0.5}, {-0.5, -0.25}, {0.6, -0.7}, {0., 0.}};
Max[Abs[Apply[uf0, pts, {1}] - Apply[poly, pts, {1}]]]]
```

> `2.886579864025407·10^-15`. `poly` is a polynomial of degree 2 per
> variable, well inside the degree-12 discrete space, so round-off is the
> floor here rather than a truncation error. `Apply[fn, pts, {1}]` is the
> right way to map a two-argument function over a list of points; the
> `Function[…] & /@ points` form shown earlier works too.

The companion negative control — Dirichlet data that is not a number — is
refused by name:

```
gd[a_, b_] := gUndefined[a, b];

SpectralNDSolve[{-Laplacian[u[x, y], {x, y}] == 1,
    DirichletCondition[u[x, y] == gd[x, y],
      Abs[x] < 1.*^-8 || Abs[x - 1.] < 1.*^-8 || Abs[y] < 1.*^-8 || Abs[y - 1.] < 1.*^-8]},
  u, {x, y} \[Element] Rectangle[{-1, -1}, {1, 1}], 12]
```

> `$Failed` in `0.012 s`, with
>
> `SpectralNDSolve::nlift: SpectralNDSolve: the Dirichlet lift did not evaluate to numbers -- 27 non-numeric boundary node value(s) -- so no numeric system can be assembled; check the DirichletCondition data.`


### Regions other than a rectangle, and more than one patch

An annulus is split into as many polar sectors as its angular span needs,
one per `π` of arc:

```
SpectralDomainData[SpectralDomain[Annulus[{1, 2}, {0, Pi}], 6], "PatchCount"]
```

> `1`

```
SpectralDomainData[SpectralDomain[Annulus[{1, 2}, {0, 2 Pi}], 6], "PatchCount"]
```

> `2`

A disk is **not** supported, and says so rather than producing a wrong
Jacobian. The polar map is singular at `r = 0`, where `J = 0`:

```
SpectralDomain[Disk[], 6]
```

> `$Failed`, with `SpectralDomain::nreg` naming the reason.

Curved boundaries are solved on `CoonsPatch` objects built by hand, and a
list of patches that share an edge is coupled automatically. On the
half-annulus `Annulus[{1, 2}, {0, Pi}]` the three boundary pieces are the
two circular arcs **and** the two radial edges on `y = 0`; a manufactured
solution that omits the radial edges measures an error of exactly
`Cos[1] = 0.5402947682285932`, which is a good way to see why the boundary
predicate has to be complete:

```
bdAnn = Abs[Sqrt[x^2 + y^2] - 1] < 1.*^-8 || Abs[Sqrt[x^2 + y^2] - 2] < 1.*^-8 || Abs[y] < 1.*^-8;

SpectralNDSolve[{-Laplacian[u[x, y], {x, y}] == fLin,
    DirichletCondition[u[x, y] == uexz[x, y], bdAnn]}, u,
  {x, y} \[Element] Annulus[{1, 2}, {0, Pi}], 16]
```

> `{{u -> Function[{qx, qy}, …]}}`, max nodal error `7.88·10^-4` at degree
> 16 (`7.75·10^-4` on the nonlinear version). The error is set by the
> geometry — an annular sector is not a polynomial image of a square — not
> by the solver; it converges with degree and is stable under going from
> one sector to two coupled patches (`7.77·10^-4`).

### `Method -> "AAA"` for a boundary given as data

`Method -> "AAA"` samples each edge curve on an equispaced grid and fits it
with an AAA rational approximation, instead of evaluating the four edge
functions symbolically. It is fully wired and is the right choice when the
boundary is *data* — a sampled curve, an interpolating function, anything
that is expensive or impossible to differentiate.

```
CoonsPatch[edges, Method -> "AAA"]
```

> An association whose `"Method"` tag is `"AAA"`, never a silent fallback to
> `"Analytic"`. Its fit record reports `"Samples" -> 65`, the
> `AAASamples` default, and each edge's fit reports its status, type,
> relative error and support set — for these linear edges, two-point
> approximants with relative error `~10^-15`.

An unrecognised method name is still a rejection, never a downgrade:

```
CoonsPatch[edges, Method -> "NoSuchMethod"]
```

> `$Failed`, with `CoonsPatch::method` naming the two implemented methods.

### Errors are raised, not silently smoothed over

A patch needs exactly four edges:

```
CoonsPatch[Take[edges, 3]]
```

> `$Failed`, with `CoonsPatch::edges` explaining the
> `{bottom, top, left, right}` contract.

The edges must close at the corners:

```
CoonsPatch[{Function[t, {2 t, -1}], Function[t, {2 t, 1.5}],
            Function[t, {-2, t}], Function[t, {2, t}]}]
```

> `$Failed`, with `CoonsPatch::corners` reporting the maximum corner
> mismatch (`0.5`, against a tolerance of `1·10^-12`).

An unknown key is refused by name:

```
SpectralDomainData[disc, "NoSuchKey"]
```

> `$Failed`, with `SpectralDomain::key` listing the keys that do exist.

## Details and Options

Version 1 is deliberately narrow. The constraints below are modelling
requirements, not missing features.

**Geometry requirements.**

- Patch vertices must be **true corners**. On a smooth closed boundary the
  two edges meeting at a vertex are tangent to each other, the transfinite
  map's Jacobian vanishes there, and every operator built from the metric
  coefficients is singular. A patch cut from a smooth curve is therefore
  rejected rather than silently producing `J = 0` at its corners.
- The four edges must close at the corners to within `1·10^-12`.
- `Disk` is not supported, for the same reason: `r = 0` makes `J = 0`
  exactly. Use `Annulus[{r1, r2}, …]` with `r1 > 0`, or supply your own
  patches with true corners.

**Coupling.**

Patches that share a geometric edge are detected **by sampling**, not by
bookkeeping: two edges are the same edge when their traces agree at the
Chebyshev nodes within `"InterfaceTolerance"`. A matched pair then shares
**one unknown per physical node**, so the solution is continuous pointwise
with no cross-grid interpolation, and one normal-flux continuity row is
added per shared node.

**Solver options.** These are accepted by both `SpectralNDSolve` and
`SpectralNDSolveValue`.

- `Method`, default `"Automatic"` — `"Automatic"` dispatches on the
  equation: `LinearSolve` when the operator has no term that is nonlinear
  in `u`, Newton's method otherwise. `"Linear"` and `"Newton"` force one
  of the two. Any other value is refused with
  `SpectralNDSolve::method`. The choice is observable: the linear
  rectangle case reports `"Method" -> "Linear"` and the nonlinear one
  reports `"Method" -> "Newton"`, and asking for `"Newton"` explicitly
  reproduces the automatic dispatch **bit for bit** (difference `0.` at
  every sampled point).
- `MaxIterations`, default `30` — the Newton iteration cap. It is
  honoured, and the test for that is sharp: `MaxIterations -> 1` cannot
  converge the nonlinear problem, and the call returns `$Failed` with
  `SpectralNDSolve::nlnum` carrying the iteration count, the last step
  norm, the tolerance, the last residual norm and the tolerance again.
  A dropped option would return a solution instead, which is what the gate
  is looking for.
- `Tolerance`, `AccuracyGoal`, `PrecisionGoal`, default `Automatic` — the
  stopping tolerance, resolved in this order: an explicit `Tolerance`,
  then `10^-AccuracyGoal`, then `10^-PrecisionGoal`, and otherwise the
  solver's own `1·10^-13`. Newton stops when either the step norm or the
  residual norm drops below it.
- `"DomainOptions"`, default `{}` — options handed straight to
  `SpectralDomain` when the solver has to build the discretization itself.
  It is not consulted when `Ω` is already a `SpectralDiscretization`,
  which is consumed as-is.

**Geometry and discretization options.** These are the options of the
*lower* layers, which are public. They accept either the string form (the
one the repository style guide requires, since resource-function symbols
are moved into a dedicated context) or the equivalent symbol form.

- `CoonsPatch`: `Method` (default `"Analytic"` — the four edge curves are
  evaluated exactly; `"AAA"` samples and rationally fits them),
  `CornerTolerance` (default `1·10^-12`) and `AAASamples` (default `65`).
- `SpectralDomain`: `"InterfaceTolerance"` (default `1·10^-10`) — how far
  two edge traces may differ and still count as the same geometric edge —
  and `"BoundaryPredicate"` (default `Automatic`), an optional predicate
  that forces extra interior nodes to be Dirichlet. Nodes that lie on a
  *shared* interface edge are refused by that predicate, because dropping
  a shared unknown would silently change the coupling.

**Sign convention.** The assembled operator is `+Laplacian`, so a PDE
written `-Laplacian[u] + u^3 == f` assembles with `OpCoefficient = -1` and
the coefficient is applied in exactly one place in the code. This is pinned
by a test, not by a comment.

## Tests

The expressions below are the gates that were actually run against the
bundled implementation; each names the evidence file it came from.
`VerificationTest` itself is a built-in test-harness symbol and needs no
resource.

### Package loads and exposes its symbols

```wl
VerificationTest[AssociationQ[
   Quiet[Needs["SpectralElement`"]], True]]
```

> Loads the bundle and reports that the context is available. The install
> channel additionally proves the whole `PacletInstall` → `Needs` →
> uninstall path against a real `.paclet` archive, and gates it 56 ways:
> `Tests/out/installprobe_P_R4_FINAL.txt`, last line `TALLY 58/58 PASS`.

### A patch closes and its map is exact

```wl
edges = {Function[t, {2 t, -1}], Function[t, {2 t, 1}],
         Function[t, {-2, t}], Function[t, {2, t}]};
patch = Quiet[CoonsPatch[edges]];

VerificationTest[AssociationQ[patch]]
VerificationTest[TrueQ[CoonsPatchQ[patch]]]
VerificationTest[Max[Abs[N[CoonsPatchMap[patch, -1., -1.]] - {-2., -1.}]] < 1.*^-14]
VerificationTest[Max[Abs[N[CoonsPatchMap[patch, 0.3, -0.5]] - {0.6, -0.5}]] < 1.*^-14]
```

> All four pass: `Max[Abs[…]]` is `0.` for the corner and below `10^-14`
> for the interior point.

### Bad geometry is rejected, loudly and by name

```wl
VerificationTest[Quiet[CoonsPatch[Take[edges, 3]]] === $Failed]
VerificationTest[Quiet[CoonsPatch[edges, Method -> "NoSuchMethod"]] === $Failed]
VerificationTest[Quiet[SpectralDomain[Disk[], 6]] === $Failed]
```

> All three return `$Failed`, and the accompanying messages are verified by
> name against the run's captured output: `CoonsPatch::edges`,
> `CoonsPatch::method`, `SpectralDomain::nreg`.

### `Method -> "AAA"` never falls back silently

```wl
aaa = Quiet[CoonsPatch[edges, Method -> "AAA"]];

VerificationTest[AssociationQ[aaa]]
VerificationTest[TrueQ[CoonsPatchQ[aaa]]]
VerificationTest[Lookup[aaa, "Method", Missing[]] === "AAA"]
```

> The invariant that matters is the third line: whatever `"AAA"` does, it
> either builds an AAA patch or is rejected, and it never returns a patch
> tagged `"Analytic"`. The quality of the fit is a separate question,
> answered under [Author Notes](#author-notes).

### The assembled system is square and correctly sized

```wl
disc = Quiet[SpectralDomain[{patch}, 8]];

VerificationTest[SpectralDomainData[disc, "PatchCount"] === 1]
VerificationTest[SpectralDomainData[disc, "Degree"] === 8]
VerificationTest[SpectralDomainData[disc, "UnknownCount"] === 49]
VerificationTest[SpectralDomainData[disc, "RowCount"]
                === SpectralDomainData[disc, "UnknownCount"]]
VerificationTest[Length[SpectralDomainData[disc, "Nodes"]] === 9]
VerificationTest[Length[SpectralDomainData[disc, "InterfacePairs"]] === 0]
```

> All six pass. `UnknownCount === RowCount` is the load-bearing one: it is
> what shows the Dirichlet lifting left a square system rather than a
> singular one.

### Region shorthands

```wl
VerificationTest[SpectralDomainData[
    SpectralDomain[Rectangle[{-1, -1}, {1, 1}], 6], "PatchCount"] === 1]
VerificationTest[SpectralDomainData[
    SpectralDomain[Annulus[{1, 2}, {0, Pi}], 6], "PatchCount"] === 1]
VerificationTest[SpectralDomainData[
    SpectralDomain[Annulus[{1, 2}, {0, 2 Pi}], 6], "PatchCount"] === 2]
```

> All three pass.

### The solver returns the `NDSolve` shape and the right answer

```wl
uexz[x_, y_] := Sin[2 x + 1] Cos[3 y - 1] + x y/5;
fLin = -Laplacian[uexz[x, y], {x, y}];
bd = Abs[x + 1.5] < 1.*^-8 || Abs[x - 1.8] < 1.*^-8 || Abs[y + 1.2] < 1.*^-8 || Abs[y - 1.3] < 1.*^-8;

sol = Quiet[SpectralNDSolve[{-Laplacian[u[x, y], {x, y}] == fLin,
       DirichletCondition[u[x, y] == uexz[x, y], bd]}, u,
     {x, y} \[Element] Rectangle[{-1.5, -1.2}, {1.8, 1.3}], 12]];

VerificationTest[MatchQ[sol, {{u -> _Function}}]]
VerificationTest[Max[Abs[sol[[1, 1, 2]][#[[1]], #[[2]]]] -
                 uexz[#[[1]], #[[2]]]]] & /@ {{-0.5, 0.3}, {0.1, 0.2}, {-0.4, 0.6}}]
                 < 1.*^-5]
VerificationTest[MatchQ[
   Quiet[SpectralNDSolveValue[{-Laplacian[u[x, y], {x, y}] == fLin,
       DirichletCondition[u[x, y] == uexz[x, y], bd]}, u,
     {x, y} \[Element] Rectangle[{-1.5, -1.2}, {1.8, 1.3}], 12]],
   _Function]]
```

> The measured errors at degree 12 are `1.25·10^-6` (linear),
> `1.25·10^-6` (nonlinear), `0.` between the two independent solves that
> reuse a pre-built discretization, and `0.` between `Method -> "Newton"`
> and the automatic dispatch. Evidence:
> `Tests/out/installprobe_P_R4_FINAL.txt`, section 8.

### No boundary data: the `u == 0` default, and the refusal contract

```wl
poly[a_, b_] := (1 - a^2) (1 - b^2);
noDc = Quiet[SpectralNDSolve[{-Laplacian[u[x, y], {x, y}] ==
            -Laplacian[poly[x, y], {x, y}]}, u,
        {x, y} \[Element] Rectangle[{-1, -1}, {1, 1}], 12]];

VerificationTest[MatchQ[noDc, {{u -> _Function}}]]
VerificationTest[Max[Abs[Apply[noDc[[1, 1, 2]],
     {{1., 0.}, {-1., 0.}, {0., 1.}, {0., -1.}, {0.5, 1.}, {-0.5, -1.}}, {1}]]] === 0.]
VerificationTest[Max[Abs[Apply[noDc[[1, 1, 2]],
     {{0.25, 0.5}, {-0.5, -0.25}, {0.6, -0.7}, {0., 0.}}, {1}] -
     Apply[poly, {{0.25, 0.5}, {-0.5, -0.25}, {0.6, -0.7}, {0., 0.}}, {1}]]] < 1.*^-8]

gd[a_, b_] := gUndefined[a, b];
VerificationTest[Quiet[SpectralNDSolve[{-Laplacian[u[x, y], {x, y}] == 1,
     DirichletCondition[u[x, y] == gd[x, y],
       Abs[x] < 1.*^-8 || Abs[x - 1.] < 1.*^-8 || Abs[y] < 1.*^-8 || Abs[y - 1.] < 1.*^-8]},
     u, {x, y} \[Element] Rectangle[{-1, -1}, {1, 1}], 12]] === $Failed]
```

> All four pass. The second is the sharp one: `=== 0.`, not a tolerance,
> because the exact answer on the boundary *is* zero. The fourth is the
> refusal contract, and it asserts the message `SpectralNDSolve::nlift` by
> name. Both install gates -- `no DirichletCondition: the u == 0 default
> solves, fast and numeric` and `non-numeric Dirichlet data is refused with
> $Failed and ::nlift` -- are in the evidence above, whose last line is the
> tally.

### `MaxIterations` is honoured, and an unknown `Method` is refused

```wl
nlEq = {-Laplacian[u[x, y], {x, y}] + uexz[x, y]^3 == fNl,
        DirichletCondition[u[x, y] == uexz[x, y], bd]};

VerificationTest[Quiet[SpectralNDSolve[nlEq, u,
     {x, y} \[Element] Rectangle[{-1.5, -1.2}, {1.8, 1.3}], 12,
     MaxIterations -> 1]] === $Failed]
VerificationTest[Quiet[SpectralNDSolve[eqLin, u,
     {x, y} \[Element] Rectangle[{-1.5, -1.2}, {1.8, 1.3}], 12,
     Method -> "NoSuchMethod"]] === $Failed]
```

> Both pass. `MaxIterations -> 1` fires `SpectralNDSolve::nlnum` and returns
> `$Failed` rather than a wrong answer; the unknown `Method` fires
> `SpectralNDSolve::method`. Those two negatives are verified by message
> name as well as by return value in the benchmark
> (`Tests/out/bench_FINAL.txt`, gates `G10`, `G10b`, `G11`, `G11b`).

### Bundle integrity

```wl
bundleText = Import["wfr/SpectralNDSolve.wl", "Text"];

VerificationTest[SyntaxQ[bundleText]]
VerificationTest[StringFreeQ[bundleText, "\\$InputFileName"]]
```

> Both succeed. The `\\$` matters: `StringFreeQ[bundleText, "$InputFileName"]`
> with an unescaped dollar returns `False`, i.e. it claims the string *is*
> present in a file that does not contain it. The escaped pattern returns
> `True`. Write it escaped. Reported by the bundler itself, which
> additionally checks that no `Get` or `FileNameJoin` survives and that
> each inlined block parses on its own — so a half-written source file is
> *named* rather than silently producing an unparseable bundle.

## Performance

Measured on this machine, all five problems at degree 16, from
`Tests/out/bench_FINAL.txt` (41/41 gates). Wall time includes assembling
the operator from scratch.

| problem | spectral time | spectral max nodal error | Newton iterations |
| --- | --- | --- | --- |
| linear, `Rectangle` | `0.113 s` | `4.47·10^-11` | — (direct solve) |
| nonlinear, `Rectangle` | `0.112 s` | `4.46·10^-11` | 5 |
| linear, `Annulus` | `0.050 s` | `7.88·10^-4` | — (direct solve) |
| nonlinear, `Annulus` | `0.110 s` | `7.75·10^-4` | 5 |
| nonlinear, two coupled patches | `0.238 s` | `7.77·10^-4` | — |

Residuals of the assembled system at the computed solution are
`2.16·10^-12` (linear rectangle) and `3.41·10^-13` (nonlinear rectangle).

**Spectral convergence.** Sweeping the degree on the linear rectangle
problem, the max nodal error falls
`1.38·10^-2 → 4.87·10^-4 → 4.20·10^-6 → 1.71·10^-7 → 4.63·10^-9 →
4.47·10^-11` at degrees `6, 8, 10, 12, 14, 16`
(`Tests/out/d2_isolate_FINAL.txt`). The same probe also isolates the
assembly from the solver: the right-hand side the solver builds
node-for-node equals the discretization layer's own sampling to
`|seRowFvec - seFvec| = 0.` **exactly**, at every degree — so the
discretization and the assembly agree bit for bit, and the convergence
above is the method's, not an artefact of bookkeeping.

**Newton's cost.** The nonlinear degree-10 case in
`Tests/out/d2_newton_FINAL.txt` takes `0.0315 s` wall time end to end
(`0.0106 s` at degree 6, `0.0203 s` at degree 8), five Newton iterations,
final residual `2.84·10^-14`.

**Against `NDSolve`'s finite-element method.** Same problems, same
evaluation points, and both `AccuracyGoal` and `PrecisionGoal` passed
explicitly so the comparison is at a stated target rather than at an
implicit default. `FEM t` is `ToElementMesh` plus `NDSolveValue` wall time.

| problem | spectral t | spectral error | FEM t | FEM error | FEM speed-up | FEM/spectral error |
| --- | --- | --- | --- | --- | --- | --- |
| linear, `Rectangle` | `0.113` | `4.47·10^-11` | `0.023` | `9.85·10^-4` | **`0.21×`** | `2.2·10^7` |
| nonlinear, `Rectangle` | `0.113` | `4.46·10^-11` | `0.179` | `9.86·10^-4` | `1.59×` | `2.2·10^7` |
| nonlinear, `Annulus` | `0.110` | `7.75·10^-4` | `0.203` | `3.27·10^-3` | `1.85×` | `4.2` |

Read the first row honestly: **on the *linear* rectangle the FEM run is
about 4.8× faster in wall time**, because meshing a rectangle is trivial
and a degree-16 spectral element already over-resolves it. What the table
does say is that on the two *nonlinear* problems — the ones that need a
nonlinear solver, and therefore the ones a reader is most likely here for
— the spectral method is `1.6–1.8×` faster *and* two to four orders of
magnitude more accurate at the same points, and that at matched accuracy
goals the accuracy gap is `2.2·10^7` on the rectangle. The linear row is a
real result and is reported rather than dropped.

## Known Limitations

Each of these is measured, with the evidence named.

- **Non-numeric Dirichlet data is refused, not guessed.** If a
  `DirichletCondition` value does not evaluate to a number at some boundary
  node — a misspelled function name, an undefined symbol — the solver
  issues `SpectralNDSolve::nlift` naming the count of offending nodes and
  returns `$Failed`. It does **not** substitute a zero and it does not
  assemble a system it cannot solve. Measured: `0.012 s` to refuse, 27
  offending nodes. This is a deliberate contract, not a limitation to work
  around: silently zeroing the boundary is how a PDE solver produces a
  confidently wrong answer.
- **`Part::partw` / `Part::partd` during a solve.** Building the
  discretization of a single-patch rectangle raises these eight times, from
  the edge-matching bookkeeping in the geometry and discretization layers.
  They are silenced at the solver's own boundary and reported rather than
  edited elsewhere. They are provably harmless: the interpolant they
  accompany reproduces the nodal vector *exactly*, and the nodal error is
  identical with and without them.
- **The returned interpolant takes scalars.** `Function[{qx, qy}, …]`
  returns `Indeterminate` for anything that is not numeric — that is
  deliberate, and it means a bare `expr /@ points` will silently ask for
  `f[point1, point2, …]` and get nothing back. Use the
  `Function[…] & /@ points` form shown above.

## Author Notes

**Why a transfinite patch.** A curved quadrilateral is the smallest shape
that has four true corners *and* curved edges. The map is a bilinear blend
of the four boundary curves with the corner contributions subtracted:

```
sm[ξ, η] = (1-η)/2 · bottom[ξ] + (1+η)/2 · top[ξ]
         + (1-ξ)/2 · left[η]  + (1+ξ)/2 · right[η]
         - bilinear blend of the four corners
```

On this map the surface metric coefficients and the Jacobian follow
analytically, so the discretized Laplacian needs no mesh generation and no
geometry fitting.

**AAA versus the analytic map, measured.** `Method -> "AAA"` was compared
against `"Analytic"` on every quantity that matters, 68 gates, all
passing (`Tests/out/aaageom.*`, last line `GATE-TALLY 68/68 PASS`):

| quantity | result |
| --- | --- |
| boundary deviation, worst of four edges | `1.11·10^-15` |
| transfinite map deviation, interior | `1.36·10^-15` |
| assembled PDE residual ratio AAA/Analytic, `n = 16` | `1.0000000014` |
| assembled PDE residual ratio AAA/Analytic, `n = 24` | `0.99875` |
| Jacobian difference over the `n = 16` grid | `8.87·10^-14` |
| corner closure | `0.` for `"Analytic"`, `2.22·10^-16` for `"AAA"` |
| per-patch construction time | `0.0003 s` analytic, `0.153 s` AAA |
| time ratio | **510×** |

So `"AAA"` reproduces the analytic map to round-off — the residual ratios
are 0–0.2%, which is round-off, not modelling error — at **510× the
construction cost per patch**. The trade is only worth it when the
boundary is *data*: a sampled curve, an interpolating function, anything
that cannot be differentiated cheaply. For four closed-form edge
functions, `"Analytic"` is the right answer and the default stays that
way.

**Sign convention.** The assembled operator is `+Laplacian`. A PDE written
as `-Laplacian[u] + u^3 == f` therefore assembles as `-Lop.U + U^3`. This
is pinned deliberately by a gate; do not "fix" it by flipping a sign
anywhere.

**Build provenance.** `build/bundle.wl` records the SHA-256 of each inlined
source file in the marker comment that precedes it, so any byte of the
shipped implementation can be traced back to a file in the repository, and
a rebuild of an unchanged tree is byte-identical.

## Submission Notes

Notes for the repository reviewers.

- **Self-contained by construction.** The submitted `.wl` contains no
  `Get`, no `$InputFileName` and no `FileNameJoin`. The build script
  asserts all three, so this cannot regress silently.
- **Eight public symbols, one entry point.** The bundle exposes eight
  symbols in the context `SpectralElement``. `SpectralNDSolve` is the
  intended user-facing entry point; the other seven are the geometry and
  discretization layer, which are public so that the discretization can be
  inspected and reused (`SpectralNDSolve` accepts a
  `SpectralDiscretization` directly and consumes it as-is, which is only
  possible if `SpectralDomain` is public). If a single-symbol submission
  is preferred, the seven lower-level symbols can be made private without
  touching the method.
- **The solver is implemented, not stubbed.** `Kernel/Solve.wl` is
  39,048 bytes and both entry points are defined. Evidence:
  `Tests/out/bench_FINAL.txt` (`41/41 PASS` after the same fix, five problems, Newton
  digit-growth ratios `1.40, 1.97, 1.97`),
  `Tests/out/installprobe_P_R4_FINAL.txt` (`TALLY 58/58 PASS`, install,
  load, geometry, discretization, solver, options, uninstall), and
  `Tests/out/d2_isolate_FINAL.txt`
  (`|seRowFvec - seFvec| = 0.` at degrees 6 through 16).
- **The no-`DirichletCondition` path is real and gated.** An earlier
  revision of this resource documented a hang there and was not submitted.
  It is fixed and now has two dedicated install gates: one that the
  homogeneous default solves, quickly, with `u == 0` exactly on the
  boundary, and one that non-numeric Dirichlet data is refused with
  `$Failed` and `SpectralNDSolve::nlift`.
- **Not supported, on purpose.** `Disk`, `Polygon`, Neumann/Robin/periodic
  conditions, per-patch degree grading, and time-dependent or eigenvalue
  problems are all roadmap items, and the package says so rather than
  guessing.
- **`Creator` / `PublisherID` / `URL` are placeholders** in
  `PacletInfo.wl` and must be filled in by the submitter before
  submission.
