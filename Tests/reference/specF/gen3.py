#!/usr/bin/env python3
"""Generate e3.wl : four-route benchmark, exact-in-time where structure allows.

PERIODIC problem, L = 2 Pi, nu = 1, T = 0.05, IC Exp[-3 x^2].
  Because every route here is a CIRCULANT discretisation of a constant-
  coefficient operator, its semidiscrete solution is EXACTLY
      u_h(j,T) = IFFT[ FFT[v] . w_k ] / nd ,
  with only the WEIGHT VECTOR w_k differing between routes.  So all the
  time-discretisation error is removed by construction and what is left
  is purely spatial -- which is what the question is about.

  A  built-in Fourier spectral      w_k = Exp[-T k^2]
  C2 uniform 2nd-order FD          w_k = Exp[-T (2-2cos(2 Pi k/n))/h^2]
  C4 uniform 4th-order FD          w_k = Exp[-T (30-32cos+2cos2)/12/h^2]

NON-PERIODIC problem, Dirichlet on [0,1], same IC shape.
  C2  tridiagonal, exact in time through the sine transform
  CGL the BUILT-IN Chebyshev path: its own CGL operator + a theta scheme
"""
import sys

PRE = r'''(* ============ specF / E3 : four-route benchmark ============ *)
Get[FileNameJoin[{Directory[], "helpers.wl"}]];
$HistoryLength = 0;

nu = 1.;
TT = 0.05;
L = 2 Pi;

(* ---- exact solutions, 60 digits --------------------------------- *)
exactP[xx_, Tf_] := N[Sum[Exp[-(xx - 2 Pi kk)^2/(4 Tf)]/Sqrt[4 Pi Tf],
     {kk, -4, 4}], 60];

(* ---- periodic routes: IFFT[ FFT[v] . w ] / nd -------------------- *)
(* wnd takes the ND wavenumbers kWave[nd] and the period, returns weights *)
wSpectral[k_, TT_, nd_, L_] := Exp[-TT k^2];
wFD2[k_, TT_, nd_, L_] := Exp[-TT (2 - 2 Cos[2 Pi k/nd])/((L/nd)^2)];
wFD4[k_, TT_, nd_, L_] := Exp[-TT (30 - 32 Cos[2 Pi k/nd] +
     2 Cos[4 Pi k/nd])/(12 (L/nd)^2)];

periodicRun[nd_, TT_, wfun_] := Module[{g, v, w},
  g = uGrid[-L/2, L/2, nd + 1];
  v = ev[Exp[-3 z^2], g];
  w = Map[wfun[#, TT, nd, L] &, kWave[nd]];
  InverseFourier[N[Fourier[v] w]]/nd];

(* ---- Dirichlet problem, [0,1] ------------------------------------ *)
icD[xx_] := Sin[Pi xx]^2 (1 + 0.5 Sin[2 Pi xx]);
dirB[n_] := If[EvenQ[n], 0., 2 N[Integrate[icD[xx] Sin[n Pi xx],
     {xx, 0, 1}], 40]];
exactD[xx_, Tf_] := N[Sum[dirB[n] Sin[n Pi xx] Exp[-n^2 Pi^2 Tf],
     {n, 1, 400}], 60];

(* 2nd-order FD on [0,1] with Dirichlet; exact in time via the sine
   transform: v -> sine coefficients -> exp(nu*(2cos(m pi/n)-2)/h^2 * t)
   -> sine series back *)
fdDirac[n_, Tf_, nu_] := Module[{h = 1/n, nn = n - 1, j, m, v, S, cf},
  j = Range[1, nn];
  m = Range[1, nn];
  v = ev[icD, Table[q h, {q, 0, n}]][[2 ;; n - 1]];
  S = Table[N[Sin[m[[r]] j[[s]] Pi/n], {r, 1, nn}, {s, 1, nn}];
  cf = Sqrt[2/n] S;
  Sqrt[2/n] S.(Table[Exp[nu 2 (Cos[m[[r]] Pi/n] - 1)/h^2 Tf] (cf.v)[[r]],
    {r, 1, nn}])];

(* ---- Chebyshev via the BUILT-IN operator + theta scheme ---------- *)
cglRun[nb_, Tf_, nu_, ns_] := Module[{xs, D1, h, v, A, P, w},
  xs = cglGrid[-1/2, 1/2, nb + 1];
  D1 = NDSolve`FiniteDifferenceDerivative[1, xs,
        "DifferenceOrder" -> "Pseudospectral"];
  h = N[Tf/ns];
  A = nu Rest[Rest[D1.{ConstantArray[1., nb + 1]}]];
  w = ev[icD, xs][[2 ;; nb]];
  P = Inverse[IdentityMatrix[nb - 1] - h A].(IdentityMatrix[nb - 1] +
       0.5 h A);
  w = Nest[Function[s, P.s], w, ns];
  w];

(* =============== TABLES ========================================== *)
nu = 1.;
TT = 0.05;

sf["#E3 P1 PERIODIC  u_t=u_xx on [-Pi,Pi], IC Exp[-3x^2], T=0.05, nu=1"];
sf["   nd    " <> row["A-spectral", "C2-FD2nd", "C4-FD4th",
     "secA", "secC2", "secC4"]];
xsamp = Table[N[-Pi + 2 Pi j/64], {j, 0, 64}];
tr = exactP[xsamp, TT];
nn = Length[xsamp];
rl = Table[Module[{nd = 8 nn2, ua, ub, uc, ta, tb, tc},
   ta = Quiet[First[Timing[periodicRun[nd, TT, wSpectral]]]];
   ua = periodicRun[nd, TT, wSpectral];
   tb = Quiet[First[Timing[periodicRun[nd, TT, wFD2]]]];
   ub = periodicRun[nd, TT, wFD2];
   tc = Quiet[First[Timing[periodicRun[nd, TT, wFD4]]]];
   uc = periodicRun[nd, TT, wFD4];
   row[fi[nd],
     f[Norm[N[ua - tr]]/Norm[N[tr]], 3],
     f[Norm[N[ub - tr]]/Norm[N[tr]], 3],
     f[Norm[N[uc - tr]]/Norm[N[tr]], 3],
     f[ta, 3], f[tb, 3], f[tc, 3]]],
  {nn2, 3, 96, 3}];
Do[sf[rl[[i]]], {i, Length[rl]}];

sf[""];
sf["#E3 D1 DIRICHLET u_t=u_xx on [0,1], IC sin^2(pi x)(1+0.5sin2pix), T=0.05"];
sf["    n    " <> row["FD2nd", "secFD2", "CGL-theta", "secCGL"]];
xs2 = Table[N[j/64], {j, 0, 64}];
tr2 = exactD[xs2, TT];
m2 = Length[xs2];
rl = Table[Module[{n = 4 n2, ua, ub, ta, tb},
   ta = Quiet[First[Timing[fdDirac[n, TT, nu]]]];
   ua = fdDirac[n, TT, nu];
   tb = Quiet[First[Timing[cglRun[n - 1, TT, nu, 400]]]];
   ub = cglRun[n - 1, TT, nu, 400];
   row[fi[n],
     f[Norm[N[ua - tr2]]/Norm[N[tr2]], 3], f[ta, 3],
     f[Norm[N[ub - tr2]]/Norm[N[tr2]], 3], f[tb, 3]]],
  {n2, 8, 256, 8}];
Do[sf[rl[[i]]], {i, Length[rl]}];

sfClose[];
Quit[];
'''

def balance(src):
    depth = 0; inc = ins = False; i = 0
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
            if depth < 0: return f"NEGATIVE at {i}: ...{src[max(0,i-90):i+25]!r}"
        i += 1
    return f"final depth {depth}, in_comment={inc}, in_string={ins}"

if __name__ == '__main__':
    out = sys.argv[1] if len(sys.argv) > 1 else 'e3.wl'
    print(balance(PRE))
    open(out, 'w').write(PRE)
    print("wrote", out, len(PRE), "bytes")