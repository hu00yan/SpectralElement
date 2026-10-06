(* specF / p6 : (a) MethodOfLines grid control, (b) clean timing,
   (c) Trefethen-Trummer via the BUILT-IN Chebyshev route, using POWER
   ITERATION (Eigenvalues does not finish in this install),
   (d) the Runge test across three grid types, (e) the elliptic wall.
   No Module initializer may reference another local. *)
$HistoryLength = 0;
Get[FileNameJoin[{Directory[], "helpers.wl"}]];
t2[e_] := If[Head[e] === String, e, ToString[N[e], InputForm]];
tst[e_] := ToString[N[e], InputForm];
pv[r_] := r[[1]];
pv2[r_] := r[[2]];
mtxt[ms_] := If[Length[ms] === 0, "clean", t2[First[ms]]];
ev2[expr_] := Module[{r, ms}, Block[{$MessageList = {}}, r = Quiet[expr]; ms = $MessageList]; {r, mtxt[ms]}];
isnum[v_] := Quiet[TrueQ[VectorQ[N[v], NumericQ]]];
rep[tag_, v_] := Module[{ok = isnum[v]}, sf[tst[tag], " | K=", Head[v], " len=", If[AtomQ[v], 0, Length[v]], " numeric=", ok, " | v0=", tst[Quiet[N[v[[1]]]]]]; ok];
nu = 1.;
TT = 0.05;
xlo = -Pi;
xhi = Pi;
xs = Table[N[xlo + j (xhi - xlo)/65], {j, 1, 64}];
eqsA = {D[u[x, t], t] == nu D[u[x, t], x, x], u[x, 0] == Exp[-3 x^2], u[xlo, t] == u[xhi, t]};
exA = Module[{aa = 3 + 1/(4 TT)}, N[Sum[Sqrt[Pi/aa] Exp[-3 (xx + 2 Pi kk)^2/(4 TT aa)]/Sqrt[4 Pi TT], {kk, -6, 6}], 50] /@ xs];
relerr[a_, b_] := Norm[N[a - b]]/Norm[N[b]];
sf["P6 start ", $Version];

(* ---------- (a) MethodOfLines grid control ---------- *)
solveM[m_] := NDSolveValue[eqsA, u, {x, xlo, xhi}, {t, 0, TT}, Method -> m];
knob[tag_, m_] := Module[{r = ev2[solveM[m]], s, vv, er}, s = pv[r]; vv = Quiet[N[s[xs, TT]]]; er = If[isnum[vv], relerr[vv, exA], -1.]; sf[tst[tag], " | numeric=", tst[isnum[vv]], " relerr=", tst[er], " v0=", tst[Quiet[N[vv[[1]]]]]]; er];
moM[n_] := {"MethodOfLines", "SpatialDiscretization" -> {"TensorProductGrid", "DifferenceOrder" -> "Pseudospectral", "MinPoints" -> n, "MaxPoints" -> n}};
moM2[n_] := {"MethodOfLines", "SpatialDiscretization" -> {"TensorProductGrid", "DifferenceOrder" -> "Pseudospectral"}, "MaxPoints" -> n, "MinPoints" -> n};
e17 = knob["K1 no knob ", {"MethodOfLines", "SpatialDiscretization" -> {"TensorProductGrid", "DifferenceOrder" -> "Pseudospectral"}}];
e33 = knob["K2 MinMax-in-SD 33 ", moM[33]];
e65 = knob["K3 MinMax-in-SD 65 ", moM[65]];
e129 = knob["K4 MinMax-in-SD 129 ", moM[129]];
f33 = knob["K5 MinMax-at-MoM 33 ", moM2[33]];
f65 = knob["K6 MinMax-at-MoM 65 ", moM2[65]];
sf["S-a done"];

(* ---------- (c) power iteration for the dominant eigenvalue ---------- *)
d2op[g_, dord_, per_] := NDSolve`FiniteDifferenceDerivative[2, g, "DifferenceOrder" -> dord, PeriodicInterpolation -> per];
powit[op_, v0_, iters_] := Module[{v = v0, lam, i}, Do[lam = N[op[v]]; v = lam/Max[Abs[lam]]; , {i, iters}]; N[lam]];
psi[nn_] := Reverse[Table[N[-1 + 2 j/(nn - 1)], {j, 0, nn - 1}]];
cgl[nn_] := Reverse[Table[N[Cos[Pi j/(nn - 1)]], {j, 0, nn - 1}]];
pergrid[nn_] := uGrid[-1, 1, nn];
pitest[tag_, g_, dord_, per_, it_] := Module[{op = d2op[g, dord, per], seed = N[Sin[3 g] + 0.5 Cos[7 g]], lam}, lam = Quiet[powit[op, seed, it]]; sf[tst[tag], " | n=", Length[g], " dominant |lam|=", tst[Abs[lam]], " sign=", tst[Sign[Re[lam]]], " Re=", tst[Re[lam]]]; Abs[lam]];
Do[pitest["C cheb-CGL pseudospec", cgl[nn], "Pseudospectral", False, 60], {nn, {17, 33, 65, 129}}];
sf["S-c1 done"];
Do[pitest["C uniform-periodic pseudospec", pergrid[nn], "Pseudospectral", True, 60], {nn, {17, 33, 65, 129}}];
sf["S-c2 done"];
Do[pitest["C uniform-NONperiodic pseudospec", pergrid[nn], "Pseudospectral", False, 60], {nn, {17, 33, 65, 129}}];
sf["S-c3 done"];
Do[pitest["C cheb-CGL order2", cgl[nn], 2, False, 60], {nn, {17, 33, 65}}];
sf["S-c done"];

(* ---------- (d) Runge test across the three grid types ---------- *)
runge[x_] := 1/(1 + 25 x^2);
rtest[tag_, g_, dord_, per_] := Module[{op = d2op[g, dord, per], u1 = N[runge[g]], d2 = Quiet[N[op[u1]]], want}, want = N[100 (1 - 750 x^2 + 9375 x^4)/(1 + 25 x^2)^3 /@ g]; sf[tst[tag], " | n=", Length[g], " maxrel=", tst[Max[Abs[(d2 - want)/want]]]]];
rtest["D uniform-periodic pseudospec ", pergrid[65], "Pseudospectral", True];
rtest["D cheb-CGL pseudospec ", cgl[65], "Pseudospectral", False];
rtest["D uniform-NONperiodic pseudospec ", pergrid[65], "Pseudospectral", False];
rtest["D uniform-periodic order2 ", pergrid[65], 2, True];
sf["S-d done"];

(* ---------- (e) the elliptic wall ---------- *)
{sn, mn} = ev2[NDSolveValue[{-D[uu[x], x, x] == Sin[Pi x], uu[0] == 0, uu[1] == 0}, uu[x], {x, 0, 1}, Method -> {"MethodOfLines", "SpatialDiscretization" -> {"TensorProductGrid", "DifferenceOrder" -> "Pseudospectral"}}]];
rep["E1 stationary Poisson + pseudo route ", pv[sn]];
sf["E1 msg=", pv2[sn]];
{sn2, mn2} = ev2[NDSolveValue[{-D[uu[x], x, x] == Sin[Pi x], uu[0] == 0, uu[1] == 0}, uu[x], {x, 0, 1}, Method -> "FiniteElement"]];
rep["E2 stationary Poisson + FEM ", pv[sn2]];
sf["E2 msg=", pv2[sn2]];
{sn3, mn3} = ev2[NDSolveValue[{-D[uu[x], x, x] == Sin[Pi x], uu[0] == 0, uu[1] == 0}, uu[x], {x, 0, 1}]];
rep["E3 stationary Poisson default ", pv[sn3]];
sf["E3 msg=", pv2[sn3]];
{sn4, mn4} = ev2[NDSolveValue[{D[uu[x], x, x] == -Sin[Pi x], uu[0] == 0, uu[1] == 0}, uu[x, 0.5], {x, 0, 1}, Method -> moM[33]]];
rep["E4 Poisson as pseudo-time + pseudo route ", pv[sn4]];
sf["E4 msg=", pv2[sn4]];
sf["S-e done"];

sf["DONE-p6"];
sfClose[];
Quit[];