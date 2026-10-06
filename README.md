# SpectralElement

Spectral multi-domain (spectral-element) solvers for PDEs on curved 2D
domains, packaged as a Wolfram paclet.

The geometry is a transfinite (Coons) interpolation of four boundary
curves per patch, so a patch is a curved quadrilateral, not a triangle
or a straight-sided box. Patches are coupled through shared interface
unknowns plus explicit normal-flux continuity rows, which makes the
method a genuine conforming multi-domain spectral-element method rather
than a patchwork of independent solves.

## Install

Requires Wolfram Language 13.0 or later. No compiled libraries, no external
dependencies. There are two routes, and they differ in what you get.

### From a checkout (development)

```wl
PacletDirectoryLoad["/path/to/SpectralElement"];
Needs["SpectralElement`"];
```

No `$Path` manipulation and no `init.m` trickery: the `Kernel` extension in
`PacletInfo.wl` maps the context `SpectralElement`` directly to
`Kernel/SpectralElement.wl`.

This registers the working tree, so edits under `Kernel/` take effect on the
next kernel start with no rebuild.

### From a built archive (release)

`PacletInstall` does **not** accept a bare directory — it reads the argument
as a paclet *name* and tries to download it (`PacletInstall::notavail`), and
`File[dir]` gives `PacletInstall::fnotfound`. It wants a `.paclet` archive:

```sh
./build/release.sh                       # builds build/SpectralElement-0.1.0.paclet
```

```wl
PacletInstall["SpectralElement-0.1.0.paclet"];
Needs["SpectralElement`"];
```

The archive is built from a **staging copy**, not from the working tree. A
paclet ships exactly what is on disk at build time — there is no `PacletInfo`
field and no option on `PacletObject` or `PacletDirectoryLoad` that excludes
anything, and `CreateArchive` does not respect `.gitignore` — so archiving
the checkout directly would also pack `Tests/`, `build/`, `wfr/` and `.git`.
`release.sh` stages only `PacletInfo.wl`, `LICENSE`, `README.md`, `API.md`
and `Kernel/`, verifies the archive contains nothing else, and then installs
the archive it just built to confirm it loads, uninstalling afterwards.

To remove an installed copy:

```wl
PacletUninstall["SpectralElement"];
```

### Rebuilding the single-file bundle

The Wolfram Function Repository artifact is a separate distribution channel:
one self-contained file with the four `Kernel/` subfiles inlined in place of
the loader's `Get` statements.

```sh
./build/bundle.sh        # -> wfr/SpectralNDSolve.wl, plus Tests/out/bundle.*.txt
```

The build is deterministic and idempotent: an unchanged source tree always
produces a byte-identical bundle — `wfr/SpectralNDSolve.wl` is 151,810
bytes with SHA-256 `733af4ac06369673f869ec6708bdb43af4286917e9fdf09ed29f8d93b5114f37`.
See `build/README-packaging.md`.

## Quickstart

Poisson's equation on a **curved** patch: four true corners joined by four
concave quadratic arcs. Copy this whole block; it runs as-is.

```wl
Needs["SpectralElement`"];

(* Four boundary curves of the unit square, each side pushed inward. *)
gamma = 0.4;
bot = Function[t, {t, -1 + gamma (1 - t^2)}];                 (* \[Eta] = -1 *)
top = Function[t, {t,  1 - gamma (1 - t^2)}];                 (* \[Eta] = +1 *)
lef = Function[t, {-1 + gamma (1 - t^2), t}];                 (* \[Xi] = -1   *)
rig = Function[t, { 1 - gamma (1 - t^2), t}];                 (* \[Xi] = +1   *)
patch = CoonsPatch[{bot, top, lef, rig}];

(* A manufactured solution, so the error below is against a known answer. *)
uex[x_, y_] := Sin[2 x + 1] Cos[3 y - 1] + x y/5;
fLin = -Laplacian[uex[x, y], {x, y}];

(* Every side of the boundary has to be named.  Miss one and those nodes
   fall back to u == 0, which uex does not satisfy: an O(1) error that
   does not shrink with the degree. *)
onPatch = Abs[y + 1 - gamma (1 - x^2)] < 1.*^-8 || Abs[y - 1 + gamma (1 - x^2)] < 1.*^-8 || Abs[x + 1 - gamma (1 - y^2)] < 1.*^-8 || Abs[x - 1 + gamma (1 - y^2)] < 1.*^-8;

disc = SpectralDomain[{patch}, 14];
sol = SpectralNDSolveValue[{-Laplacian[u[x, y], {x, y}] == fLin,
     DirichletCondition[u[x, y] == uex[x, y], onPatch]}, u, {x, y} \[Element] {patch}, 14];

sol[0, 0]
```

That prints `0.4546487121705494`; the exact value is
`0.4546487134128409`, and the maximum error over all 169 nodes is
`8.396047932457407*^-7` at degree 14. Both numbers are from
`Tests/out/02-curved-coons-patch.125953_70548.txt`, which is the run of
`Examples/02-curved-coons-patch.wl` — this block is that file's first
half. `Examples/01-linear-rectangle.wl` is the same thing on a flat
rectangle, where the error reaches `4.4654946407263196*^-11` at degree
16.

The geometry and discretization layers are public too, and are the layer
to reach for when you want to see or change the discretization:

```wl
SpectralDomainData[disc, "PatchCount"]
SpectralDomainData[disc, "UnknownCount"]
SpectralDomainData[disc, "InterfacePairs"]
SpectralDomainData[disc, "MinJacobian"]
SpectralDomainData[disc, "Coordinates"]
SpectralDomainData[disc, "X"]
SpectralDomainData[disc, "Y"]
```

## API

The full binding contract — loader rules, every signature, every message
name, v1 constraints — is in **[API.md](API.md)**. Short version:

| Symbol | Layer | Purpose |
| --- | --- | --- |
| `CoonsPatch`, `CoonsPatchQ`, `CoonsPatchMap` | geometry | transfinite patch from four boundary curves, and its map |
| `SpectralDomain`, `SpectralDomainQ`, `SpectralDomainData` | discretization | Chebyshev nodes, shared interfaces, flux rows |
| `SpectralNDSolve`, `SpectralNDSolveValue` | solver | `NDSolve`-shaped entry points |

v1 supports `Rectangle` and `Annulus[{r1, r2}, {\[Theta]1, \[Theta]2}]` with
`r1 > 0`. `Disk` is **not** supported: the polar map has `J = 0` at `r = 0`,
so the metric coefficients are singular there. `Polygon` is not
decomposed automatically either. See API.md §4.2 for the full reasoning
and the roadmap entries.

All 33 data keys resolve and raise no message. `"Coordinates"` returns
one `{x, y}` pair per node, shaped `{patchCount, nn, nn, 2}`, and is the
pairing of `"X"` and `"Y"` — they differ by `0.` to machine precision on
both one-patch and multi-patch domains.

That key did not always work: an earlier build left the patch index
unbound inside that one branch, so the fetch raised `Part::pkspec1` and
handed back a `Symbol`. A key-by-key walk of all 33 keys is what caught
it — `Tests/out/e_probe5.115628_60497.txt`, whose `"Coordinates"` line
reads `head=Symbol ... nmsgs=12` while the other 32 read `nmsgs=0`. The
repair, and the 17 gates that verify it on a one-patch rectangle and a
two-patch annulus, are in `Tests/out/d2_coords.132405_75895.txt`. Read
`"Coordinates"` when you want pairs, and `"X"` / `"Y"` when you want to
index one coordinate directly.

## Examples

Six scripts in **[Examples/](Examples/README.md)**, from a one-patch
hello-world to the nonlinear capstone. All six run end-to-end on the
shipped package, and each ends with a `VERDICT:` line.

## Benchmarks

Every number below is from `Tests/out/bench_FINAL.txt` (agent D's
`Tests/bench.wl`, 41/41 gates), re-verified today in
`Tests/out/e_bench_recheck.122011_63783.txt`. Reproduce with:

```sh
./rr.sh 3000 Tests/bench.wl
```

**Spectral convergence.** `-Laplacian[u] == f` on a rectangle with a
manufactured solution, maximum nodal error:

| degree `n` | 6 | 8 | 10 | 12 | 14 | 16 |
| --- | --- | --- | --- | --- | --- | --- |
| max nodal error | `1.38e-2` | `4.87e-4` | `1.39e-5` | `2.67e-7` | `3.86e-9` | `4.47e-11` |

Roughly three orders of magnitude per two degrees.
`Examples/04-convergence.wl` reproduces that whole row from the public
API alone, in `Tests/out/04-convergence.130213_71659.txt`.

**Newton converges quadratically.** On the nonlinear rectangle
(`-Laplacian[u] + u^3 == f`) the step norms are `1.39, 5.94e-2,
7.12e-4, 1.17e-7, 4.05e-15` — five iterations, and the number of digits
gained per step roughly doubles (`1.37, 1.92, 3.78, 7.46`), which is the
signature of a quadratic method. The nonlinear solve at degree 16 takes
`0.0989 s`.

**Against `NDSolve`'s built-in FEM.** The same problems, solved by
`ToElementMesh` + `NDSolveValue`, evaluated at the *same* nodes, with
`AccuracyGoal` and `PrecisionGoal` passed explicitly:

| problem | spectral `t` | spectral error | FEM `t` | FEM error | speed | accuracy ratio |
| --- | --- | --- | --- | --- | --- | --- |
| linear, rectangle | `0.1127` | `4.4655e-11` | `0.0232` | `9.848e-4` | FEM **4.8x faster** | spectral **2.2e7x** more accurate |
| nonlinear, rectangle | `0.1125` | `4.4554e-11` | `0.1793` | `9.855e-4` | spectral **1.59x** faster | spectral **2.2e7x** more accurate |
| nonlinear, half-annulus | `0.1101` | `7.751e-4` | `0.2033` | `3.267e-3` | spectral **1.85x** faster | spectral **4.2x** more accurate |

Wall clock is mesh-plus-solve on one machine and moves with load; the
accuracy ratios do not. Read the two columns separately: on the linear
problem the built-in FEM is the faster of the two, and this package is
orders of magnitude more accurate. Nothing here is a claim that this
package wins every column.

**Fitting the boundary with AAA.** `Method -> "AAA"` replaces the four
boundary curves with AAA rational fits of 65 samples each. On these
smooth arcs the fitted boundary sits within `1.22e-15` of the true one and
the two patches agree on all four corners to `2.22e-16`, at `0.170 s`
against `0.00032 s` for the analytic patch — about `529x` the
construction cost. `Tests/out/05-aaa-boundary.130544_72337.txt`. Use it
when the boundary arrives as data, not as a callable you would rather not
evaluate a million times.

The reference implementation this package is derived from
(`Tests/reference/specF/p11.wl`) reports, for `-Laplacian[u] + u^3 = f` on a
half-annulus split into two patches, nodal errors `3.7e-4`, `2.2e-7`,
`7.9e-11` at `n = 16, 24, 32`. Those are *reference* numbers from a
separate implementation, quoted as the target to reproduce, not as
results of this package.

## Roadmap

- `Disk` (via a pole treatment) and automatic `Polygon` decomposition
- Per-patch degree `n` and `hp`-adaptivity
- Neumann, Robin and periodic boundary conditions
- Time-dependent and eigenvalue problems
- Function Repository submission

`Method -> "AAA"` — arbitrary-boundary parametrization — is **not** on
this list: it is implemented and measured. See the Benchmarks section.

## License

MIT — see [LICENSE](LICENSE).