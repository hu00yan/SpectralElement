# Examples

Six scripts, in the order they are worth reading. Every one runs
end-to-end on the shipped package and prints its own numbers; nothing
here is transcribed by hand. Run any of them with the repo's guarded
runner, which writes the output to a committable evidence file under
`Tests/out/`:

```sh
./rr.sh 300 Examples/01-linear-rectangle.wl
```

Each script writes to the evidence file the runner names in
`$SPECF_OUT`, so the run is self-certifying: a truncated or failed run
does not end with the `VERDICT:` line.

Every example loads the package the same way, and works whether the
package is installed or the script is being read straight out of a
checkout:

```wl
If[! MemberQ[$ContextPath, "SpectralElement`"], Get[FileNameJoin[{DirectoryName[$InputFileName], "..", "Kernel", "SpectralElement.wl"}]]];
If[! MemberQ[$ContextPath, "SpectralElement`"], Needs["SpectralElement`"]];
```

## The scripts

| # | File | What it shows | Evidence |
|---|---|---|---|
| 1 | `01-linear-rectangle.wl` | `NDSolve`-shaped solve on a `Rectangle`, no options, against a manufactured solution | `Tests/out/01-linear-rectangle.124229_67308.txt` |
| 2 | `02-curved-coons-patch.wl` | a curved transfinite patch by hand; the map reproduces its own edges; the true-corner rule | `Tests/out/02-curved-coons-patch.125953_70548.txt` |
| 3 | `03-two-patch-annulus.wl` | two patches sharing an interface circle: shared unknowns and normal-flux rows | `Tests/out/03-two-patch-annulus.130159_71414.txt` |
| 4 | `04-convergence.wl` | spectral convergence, degrees 6 to 16, same problem each time | `Tests/out/04-convergence.130213_71659.txt` |
| 5 | `05-aaa-boundary.wl` | `Method -> "AAA"`: fit the boundary instead of evaluating it; and its refusals | `Tests/out/05-aaa-boundary.130544_72337.txt` |
| 6 | `06-nonlinear-vs-ndsolve.wl` | the capstone: `-Laplacian[u] + u^3 == f`, Newton, and an honest `NDSolve` FEM comparison | `Tests/out/06-nonlinear-vs-ndsolve.130937_73112.txt` |

## Expected messages

Examples 1, 3 and 4 are **silent**: they raise no message at all, and
each prints its message count so you can check that yourself.

Examples 2, 5 and 6 raise messages on purpose, and each header says
where:

- **02** raises `CoonsPatch` and `SpectralDomain` in the last section
  only. That section tries to build one transfinite patch out of a
  smooth closed curve, whose four "corners" are tangent to each other,
  and shows the package refusing it rather than returning a patch with a
  silently degenerate map.
- **05** raises `CoonsPatch` twice in the refusal section: an edge that
  cannot be sampled, and an edge that collapses to a point. Neither
  falls back to `Method -> "Analytic"`.
- **06** raises `SpectralNDSolve::nlnum` exactly once, from a
  deliberately capped Newton run (`MaxIterations -> 1`) used to show
  that a non-converging solve fails loudly instead of returning a wrong
  answer.

## The accuracy helper

Examples 1–4 and 6 share one helper, `nodeErr`, which takes the maximum
of `|fn - exact|` over **every node of every patch**. It reads the node
coordinates from the public `SpectralDomainData[disc, "X"]` and
`"Y"` keys, and it is always given a *manufactured* solution, so the
number is an error against a known answer and never a self-comparison.

Two traps it steps around, both found by writing it wrong first:

- every local is assigned in the `Module` **body**, never in the
  initializer list — an initializer cannot see another initializer in
  this kernel, and `np = Length[ps]` in the initializer list silently
  reads the wrong thing and leaves every `Table` empty;
- `Flatten[table, 1]` flattens **to depth 1**, so a `Table` of `{x, y}`
  pairs shredded by it stops being a list of points. Example 6 builds
  its node list with a single flat index instead.

## A boundary predicate must name every side

`DirichletCondition` carries a predicate, and any boundary node the
predicate does not match falls back to the homogeneous default `u == 0`.
A manufactured solution usually does not satisfy `u == 0`, so a
predicate that misses one side produces an `O(1)` error that does **not**
shrink when the degree goes up — a silent, expensive failure.

The sharpest version of this, measured: writing `Abs[y + 1.3]` where
`Abs[y - 1.3]` was meant leaves the top side of the rectangle uncovered.
The top-edge nodes then get `u == 0`, the error at the nearest interior
node reaches `1.4157`, and raising the degree from 6 to 16 moves it
from `1.2360` to `1.4158` — the signature of a missing condition, not of
truncation error. With the sign corrected the same run gives
`4.4655e-11` at degree 16, which is what `Tests/out/bench_FINAL.txt`
gate G6a records.

Example 3 carries the same warning for `Annulus[{r1, r2}, {t1, t2}]`,
whose two radial edges are easy to forget.

## Results of the pass

All six scripts run to completion. The line each one ends with, copied
from its evidence file:

```
VERDICT: 01-linear-rectangle OK (no messages)
VERDICT: 02-curved-coons-patch OK (the only messages are the documented CoonsPatch and SpectralDomain refusals in the last section)
VERDICT: 03-two-patch-annulus OK (no messages)
VERDICT: 04-convergence OK (no messages)
VERDICT: 05-aaa-boundary OK (the only messages are the two documented CoonsPatch refusals in the last section)
VERDICT: 06-nonlinear-vs-ndsolve OK (the only message is the documented SpectralNDSolve::nlnum from the capped Newton run)
```

**6/6 PASS**