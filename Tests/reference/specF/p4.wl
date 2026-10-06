(* specF / p4 : get REAL numbers out of the built-in route, settle FFT vs dense.
   Bug fixes: (1) NumericQ is NOT Listable -> use VectorQ[v, NumericQ];
   (2) Module[{a=..., b=a...}] does not see a -> never reference a local
   inside another local's initializer; compute outside Module. *)
$HistoryLength = 0;
Get[FileNameJoin[{Directory[], "helpers.wl"}]];
t2[e_] := If[Head[e] === String, e, ToString[N[e], InputForm]];
pv[r_] := r[[1]];
pv2[r_] := r[[2]];
mtxt[ms_] := If[Length[ms] === 0, "clean", t2[First[ms]]];
ev2[expr_] := Module[{r, ms}, Block[{$MessageList = {}}, r = Quiet[expr]; ms = $MessageList]; {r, mtxt[ms]}];
isnum[v_] := Quiet[TrueQ[VectorQ[N[v], NumericQ]]];
rep[tag_, v_] := Module[{ok = isnum[v]}, sf[tst[tag], " | K=", Head[v], " len=", If[AtomQ[v], 0, Length[v]], " numeric=", ok, If[ok, "", " | raw=", t2[v]], " | v0=", tst[Quiet[N[v[[1]]]]]]; ok];
nu = 1.;
TT = 0.05;
xlo = -Pi;
xhi = Pi;
moM = {"MethodOfLines", "SpatialDiscretization" -> {"TensorProductGrid", "DifferenceOrder" -> "Pseudospectral"}};
eqsA = {D[u[x, t], t] == nu D[u[x, t], x, x], u[x, 0] == Exp[-3 x^2], u[xlo, t] == u[xhi, t]};
eqsB = {D[u[t, x], t] == nu D[u[t, x], x, x], u[0, x] == Exp[-3 x^2], u[t, xlo] == u[t, xhi]};
xs = Table[N[xlo + j (xhi - xlo)/65], {j, 1, 64}];
sf["P4 start ", $Version];

(* ---------- 0. baseline: a trivial ODE must work ---------- *)
z = ev2[NDSolveValue[{ww'[t] == -ww, ww[0] == 1}, ww[TT]]];
rep["0 ODE sanity e^-0.05", pv[z]];

(* ---------- 1. which invocation variant returns a function? ---------- *)
v1 = ev2[NDSolveValue[eqsA, u, {x, xlo, xhi}, {t, 0, TT}, Method -> moM]];
rep["1 eqsA sym-u {x},{t}", pv[v1]];
v2 = ev2[NDSolveValue[eqsB, u, {x, xlo, xhi}, {t, 0, TT}, Method -> moM]];
rep["2 eqsB u[t,x] sym-u", pv[v2]];
v3 = ev2[NDSolveValue[eqsA, u, {x, xlo, xhi, 33}, {t, 0, TT}, Method -> moM]];
rep["3 eqsA x-grid n=33", pv[v3]];
v4 = ev2[NDSolveValue[eqsA, u, {x, xlo, xhi}, {t, 0, TT}]];
rep["4 eqsA NO method (baseline)", pv[v4]];
v5 = ev2[NDSolveValue[eqsA, u[x, TT], {x, xlo, xhi}, Method -> moM]];
rep["5 eqsA u[x,TT] 1 range", pv[v5]];
sf["S1 done"];

(* ---------- 2. if some variant works, evaluate it on xs ---------- *)
tryEval[tag_, s_, xq_] := Module[{vv = Quiet[N[s[xq, TT]]]}, rep[tag, vv]];
Do[If[!TrueQ[AtomQ[pv[v1]]], tryEval["2.1 v1 on xs", pv[v1], xs]], {i, 1}];
Do[If[!TrueQ[AtomQ[pv[v2]]], tryEval["2.2 v2 on xs", pv[v2], xs]], {i, 1}];
Do[If[!TrueQ[AtomQ[pv[v4]]], tryEval["2.4 v4 on xs", pv[v4], xs]], {i, 1}];
sf["S2 done"];

(* ---------- 3. FFT or dense?  cost scaling of the pseudospectral D2 -------- *)
applySec[nn_] := First[AbsoluteTiming[Quiet[N[NDSolve`FiniteDifferenceDerivative[2, uGrid[xlo, xhi, nn], ConstantArray[Exp[2.], nn], PeriodicInterpolation -> True, "DifferenceOrder" -> "Pseudospectral"]]]]];
Do[sf["3 n=", nn, " applySec=", tst[applySec[nn]]], {nn, {33, 65, 129, 257, 513, 1025, 2049}}];
sf["S3 done"];

(* ---------- 4. is the pseudospectral D2 an exact spectral derivative? -------- *)
specD2[vals_, nn_] := NDSolve`FiniteDifferenceDerivative[2, uGrid[xlo, xhi, nn], vals, PeriodicInterpolation -> True, "DifferenceOrder" -> "Pseudospectral"];
fdD2[vals_, nn_] := NDSolve`FiniteDifferenceDerivative[2, uGrid[xlo, xhi, nn], vals, PeriodicInterpolation -> True, "DifferenceOrder" -> 2];
nnq = 33;
gq = uGrid[xlo, xhi, nnq];
modechk[fn_, k_, lbl_] := Module[{e = Exp[I k gq], got = fn[e, nnq], want = N[-(2 Pi k/(xhi - xlo))^2 e]}, sf[lbl, " k=", k, " maxrelerr=", tst[Max[Abs[(got - want)/want]]]]];
Do[modechk[specD2, k, "4 spectral D2"], {k, {1, 2, 3}}];
Do[modechk[fdD2, k, "4 FD2 order2"], {k, {1, 2, 3}}];
sf["S4 done"];

(* ---------- 5. D2 of a constant must vanish exactly ---------- *)
rep["5 spectral D2 ones", specD2[ConstantArray[1., nnq], nnq]];
rep["5 FD2 ones", fdD2[ConstantArray[1., nnq], nnq]];
sf["S5 done"];

sf["DONE-p4"];
sfClose[];
Quit[];