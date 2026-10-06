#!/usr/bin/env python3
"""Generate e2.wl : operator identity + true roundoff floor + cost."""
import sys

PRE = r'''(* ============ specF / E2 : identity, roundoff floor, cost ============ *)
Get[FileNameJoin[{Directory[], "helpers.wl"}]];
$HistoryLength = 0;

(* EXACT Fourier derivative of a period-L function, from the n-1 DISTINCT
   samples of an n-point grid whose first and last point coincide.
   ph[m, j] = Exp[2 Pi I m j/(n-1)];  kk = wavenumber indices *)
mySpec[L_, n_] := Module[{nd = n - 1, kk, jj, ph},
  kk = kWave[nd];
  jj = Range[0, nd - 1];
  ph = Table[N[Exp[2 Pi I kk[[i]] jj[[j]]/nd]], {i, 1, nd}, {j, 1, nd}];
  ConjugateTranspose[ph].DiagonalMatrix[N[2 Pi I kk/L]].ph/nd];

(* ---------- (a) is the built-in THE Fourier spectral derivative? --- *)
sf["#E2 (a) built-in vs my own explicit Fourier spectral operator"];
sf["     n  " <> row["builtInVsExact", "builtInVsMine", "relDiff"]];
rl = Table[Module[{n = 2 nn, g, v, ex, bi, mine, dif},
   g = uGrid[-3., 5., n];
   v = ev[Sin[2 Pi z/8.] + 0.4 Cos[6 Pi z/8.], g];
   ex = ev[(2 Pi/8.) Cos[2 Pi z/8.] - 0.4 (6 Pi/8.) Sin[6 Pi z/8.], g];
   bi = NDSolve`FiniteDifferenceDerivative[1, g, v, optPSU];
   mine = Join[mySpec[8., n].v[[1]], {mySpec[8., n].v[[1]]}];
   dif = Max[Abs[N[bi] - N[mine]]];
   row[fi[n], f[dif, 3], f[dif/Norm[N[v]], 3], f[Max[Abs[N[bi] - ex]], 3]]],
  {nn, 4, 64, 4}];
Do[sf[rl[[i]]], {i, Length[rl]}];

(* ---------- (b) PERIODIC roundoff floor, EXACT band-limited data --- *)
sf[""];
sf["#E2 (b) PERIODIC roundoff floor: exact data, no truncation, no alias"];
sf["     n  " <> row["builtInMaxErr", "myOpMaxErr", "err*n^2"]];
rl = Table[Module[{n = 2 nn, nd, M, g, v, de, bi, mine},
   nd = n - 1;
   M = Min[6, nd/2 - 1];
   g = uGrid[0., 1., n];
   v = N[Table[Re[serU[2 Pi j/nd, M]], {j, 0, nd - 1}]];
   de = N[Table[Re[serD[2 Pi j/nd, M]], {j, 0, nd - 1}]];
   bi = Max[Abs[NDSolve`FiniteDifferenceDerivative[1, g, Join[v, {v[[1]]}],
        optPSU][[1 ;; nd]] - de]];
   mine = Max[Abs[mySpec[1., n].v - de]];
   row[fi[n], f[bi, 4], f[mine, 4], f[bi*nd^2, 4]]],
  {nn, 4, 128, 4}];
Do[sf[rl[[i]]], {i, Length[rl]}];

(* ---------- (c) Chebyshev-CGL roundoff floor ---------------------- *)
sf[""];
sf["#E2 (c) CGL roundoff floor, exp(-x^2) on [-5,10], exact data"];
sf["     n  " <> row["builtInMaxErr", "eps*n^4", "eps*n^2"]];
rl = Table[Module[{n = 2 nn + 1, g, v, de, bi},
   g = cglGrid[-5., 10., n];
   v = N[Table[N[Exp[-z^2], 60], {z, g}]];
   de = N[Table[N[-2 z Exp[-z^2], 60], {z, g}]];
   bi = Max[Abs[NDSolve`FiniteDifferenceDerivative[1, g, v, optPSC] - de]];
   row[fi[n], f[bi, 4], f[MachinePrecision*n^4, 4], f[MachinePrecision*n^2, 4]]],
  {nn, 3, 60, 3}];
Do[sf[rl[[i]]], {i, Length[rl]}];

(* ---------- (d) cost: FFT (O(n log n)) or dense (O(n^2))? ---------- *)
sf[""];
sf["#E2 (d) cost of ONE derivative application, seconds"];
sf["     n  " <> row["builtIn", "myOpDense", "fftOnly", "builtIn/nlogn"]];
rl = Table[Module[{n = 2 nn + 1, g, v, tb, td, tf},
   g = uGrid[-3., 5., n];
   v = ev[Sin[z], g];
   tb = Quiet[First[Timing[NDSolve`FiniteDifferenceDerivative[1, g, v, optPSU]]]];
   td = Quiet[First[Timing[mySpec[8., n].v]]];
   tf = Quiet[First[Timing[InverseFourier[N[Fourier[v]]]]]];
   row[fi[n], f[tb, 4], f[td, 4], f[tf, 4], f[tb/(n Log[2, n]), 4]]],
  {nn, 15, 400, 20}];
Do[sf[rl[[i]]], {i, Length[rl]}];

sfClose[];
Quit[];
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
            if depth < 0: return f"NEGATIVE at {i}: ...{src[max(0,i-80):i+25]!r}"
        i += 1
    return f"final depth {depth}, in_comment={inc}, in_string={ins}"

if __name__ == '__main__':
    out = sys.argv[1] if len(sys.argv) > 1 else 'e2.wl'
    print(balance(PRE))
    open(out, 'w').write(PRE)
    print("wrote", out, len(PRE), "bytes")