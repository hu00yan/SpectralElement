#!/usr/bin/env python3
"""Generate e1.wl -- built-in spatial primitive study.

Design rule: `Quiet[Check[...]]` NEVER appears inside a Module var-list
or a Table body.  It only appears in top-level named helpers.  Every
Table body ends with a line of the form  `row[...]],` whose trailing
bracket run is fixed by the writer below.
"""
import sys

PRE = r'''(* ============ specF / E1 : the built-in spatial primitive ============ *)
Get[FileNameJoin[{Directory[], "harness.wl"}]];

uGrid[a_, b_, n_Integer?Positive] := Table[N[a + j (b - a)/(n - 1)], {j, 0, n - 1}];
cglGrid[a_, b_, n_Integer?Positive] :=
  Reverse[Table[N[(a + b)/2 + (b - a)/2 Cos[Pi j/(n - 1)]], {j, 0, n - 1}]];

f[e_, d_: 3] := ToString[Round[N[e], d], InputForm];
fi[e_] := ToString[N[e], InputForm];
row[args___] := StringJoin[PadRight[ToString[#, InputForm] & /@ {args}, 13, " "]];

ev[fn_, g_List] := Table[N[fn /. z -> g[[j]]], {j, 1, Length[g]}];

(* ---- the only place Quiet/Check appears -------------------------- *)
tryIt[expr_] := Quiet[Check[expr, $Failed]];
say[expr_] := If[expr === $Failed, "REJECTED", "accepted"];
stat[expr_] := If[expr === $Failed, "REJECTED",
  "accepted len=" <> fi[Length[expr]]];

optPSU = {"DifferenceOrder" -> "Pseudospectral", PeriodicInterpolation -> True};
optPSC = {"DifferenceOrder" -> "Pseudospectral"};

(* 1st derivative: {maxErr, rmsErr, maxErrLeftQuarter} *)
d1[g_List, opts_List] := tryIt[
  N[NDSolve`FiniteDifferenceDerivative[1, g, ev[Sin[#] &, g], opts]]];
dErr[g_List, fn_, dfn_, opts_List] := Module[{r, ex, er, k},
  r = N[NDSolve`FiniteDifferenceDerivative[1, g, ev[fn, g], opts]];
  ex = ev[dfn, g];
  er = Abs[r - ex];
  k = Max[1, Ceiling[Length[g]/4]];
  {Max[er], Sqrt[Mean[er^2]], Max[Take[er, k]]}];

fA[z_] := Exp[-z^2];
dfA[z_] := -2 z Exp[-z^2];
fB[z_] := Sin[z] + 0.3 Cos[3 z] + 0.1 Sin[7 z];
dfB[z_] := Cos[z] - 0.9 Sin[3 z] + 0.7 Cos[7 z];

sf["#E1 built-in spatial primitive  wl " <> $Version];
sf["#E1.1 DifferenceOrder accepted on a uniform grid of 9 points:"];
g0 = uGrid[0., 1., 9];
gcl = cglGrid[0., 1., 9];
dops = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 16, 20, 8.5, 0, -2, Automatic,
  "Pseudospectral", {2, 3}, "Bogus", 8.};
rl = Table[Module[{rr},
   rr = tryIt[NDSolve`FiniteDifferenceDerivative[1, g0, ev[Sin[#] &, g0],
     "DifferenceOrder" -> dop]];
   row[("DO=" <> fi[dop]), say[rr]]], {d, Length[dops]}, {dop, dops}];
Do[sf[rl[[i]]], {i, Length[rl]}];

sf["#E1.2 grid / order admissibility -- is Chebyshev reachable?"];
combos = {{g0, "uniform", optPSU}, {g0, "uniform", optPSC},
  {gcl, "CGL   ", optPSU}, {gcl, "CGL   ", optPSC}};
rl = Table[Module[{gr = combos[[i, 1]], rr},
   rr = tryIt[NDSolve`FiniteDifferenceDerivative[1, gr, ev[Sin[#] &, gr],
     combos[[i, 3]]]];
   row[combos[[i, 2]], stat[rr]]], {i, Length[combos]}];
Do[sf[rl[[i]]], {i, Length[rl]}];

sf[""];
sf["#E1.3  d/dx exp(-x^2) on [-5,10] : MAX abs error over all grid points"];
sf["     n  " <> row["psUniform", "psCGL", "maxOrdUni", "fd4", "fd2"]];
rl = Table[Module[{n = 2 nn + 1, gu, gc, ea, ec, em, e4, e2},
   gu = uGrid[-5., 10., n];
   gc = cglGrid[-5., 10., n];
   ea = dErr[gu, fA, dfA, optPSU];
   ec = dErr[gc, fA, dfA, optPSC];
   em = dErr[gu, fA, dfA, {"DifferenceOrder" -> n - 1}];
   e4 = dErr[gu, fA, dfA, {"DifferenceOrder" -> 4}];
   e2 = dErr[gu, fA, dfA, {"DifferenceOrder" -> 2}];
   row[fi[n], f[ea[[1]]], f[ec[[1]]], Round[em[[1]], 2], f[e4[[1]]], f[e2[[1]]]]],
  {nn, 8}];
Do[sf[rl[[i]]], {i, Length[rl]}];

sf["#E1.4 same, MAX error over the leftmost quarter only (Runge zone)"];
sf["     n  " <> row["psUniform", "psCGL", "maxOrdUni", "fd4"]];
rl = Table[Module[{n = 2 nn + 1, gu, gc, ea, ec, em, e4},
   gu = uGrid[-5., 10., n];
   gc = cglGrid[-5., 10., n];
   ea = dErr[gu, fA, dfA, optPSU];
   ec = dErr[gc, fA, dfA, optPSC];
   em = dErr[gu, fA, dfA, {"DifferenceOrder" -> n - 1}];
   e4 = dErr[gu, fA, dfA, {"DifferenceOrder" -> 4}];
   row[fi[n], f[ea[[3]]], f[ec[[3]]], Round[em[[3]], 2], f[e4[[3]]]]],
  {nn, 8}];
Do[sf[rl[[i]]], {i, Length[rl]}];

sf[""];
sf["#E1.5  periodic band-limited: u = sin x + 0.3cos3x + 0.1sin7x on [-pi,pi]"];
sf["     n  " <> row["psUniform", "fd4", "fd2"]];
rl = Table[Module[{n = 2 nn + 1, gu, ea, e4, e2},
   gu = uGrid[-Pi, Pi, n];
   ea = dErr[gu, fB, dfB, optPSU];
   e4 = dErr[gu, fB, dfB, {"DifferenceOrder" -> 4}];
   e2 = dErr[gu, fB, dfB, {"DifferenceOrder" -> 2}];
   row[fi[n], f[ea[[1]]], f[e4[[1]]], f[e2[[1]]]]],
  {nn, 8}];
Do[sf[rl[[i]]], {i, Length[rl]}];

sf[""];
sf["#E1.6 aliasing floor: d/dx exp(-x^2) on [-pi,pi] periodic, drop 2 alias pts"];
sf["      n  " <> row["maxErrAll", "maxErrNoAlias", "ratio"]];
rl = Table[Module[{n = 2 nn, gu, r, ex, er, kp, rt},
   gu = uGrid[-Pi, Pi, n];
   r = N[NDSolve`FiniteDifferenceDerivative[1, gu, ev[Exp[-#^2] &, gu], optPSU]];
   ex = ev[(-2 # Exp[-#^2]) &, gu];
   er = Abs[r - ex];
   kp = Drop[er, {n/2 + 1}];
   rt = Max[er]/Max[kp];
   row[fi[n], f[Max[er]], f[Max[kp]], f[rt]]],
  {nn, 8}];
Do[sf[rl[[i]]], {i, Length[rl]}];

sfClose[];
'''

def balance(src):
    depth = 0; inc = False; ins = False; i = 0
    while i < len(src):
        c = src[i]
        if inc:
            if src.startswith('*)', i): inc = False; i += 2; continue
            i += 1; continue
        if ins:
            if c == '"':
                if i + 1 < len(src) and src[i+1] == '"': i += 2; continue
                ins = False
            i += 1; continue
        if src.startswith('(*', i):
            j = src.find('*)', i+2)
            if j == -1: inc = True; i = len(src)
            else: i = j + 2
            continue
        if c == '"': ins = True; i += 1; continue
        if c in '([{': depth += 1
        elif c in ')]}':
            depth -= 1
            if depth < 0: return f"NEGATIVE at {i}: ...{src[max(0,i-70):i+20]!r}"
        i += 1
    return f"final depth {depth}, in_comment={inc}, in_string={ins}"

if __name__ == '__main__':
    out = sys.argv[1] if len(sys.argv) > 1 else 'e1.wl'
    print(balance(PRE))
    open(out, 'w').write(PRE)
    print("wrote", out, len(PRE), "bytes")