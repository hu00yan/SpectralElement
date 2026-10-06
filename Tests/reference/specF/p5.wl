(* specF / p5 : grid control + convergence + FFT-vs-dense, cleanly.
   Hard-won rules: define tst; NumericQ is NOT Listable (use VectorQ);
   NEVER reference one Module local inside another's initializer;
   the 4-arg NDSolve`FiniteDifferenceDerivative[deriv,grid,values,opts]
   OOM-CRASHED the kernel in p4 -> use the 2-positional function form. *)
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
sf["P5 start ", $Version];

(* ---------- references: three independent ---------- *)
refA[xx_, Tf_] := Module[{aa = 3 + 1/(4 Tf)}, N[Sum[Sqrt[Pi/aa] Exp[-3 (xx + 2 Pi kk)^2/(4 Tf aa)]/Sqrt[4 Pi Tf], {kk, -6, 6}], 50]];
caB = Table[NIntegrate[Exp[-3 zz^2] Cos[mm zz], {zz, -Pi, Pi}, WorkingPrecision -> 30]/Pi, {mm, 0, 120}];
refB[xx_, Tf_] := N[caB[[1]]/2 + Total[Table[caB[[mm + 1]] Cos[mm xx] Exp[-mm^2 Tf], {mm, 1, 120}]], 50];
caC[k_] := If[k == 0, Sqrt[Pi/3], Sqrt[Pi/3] Exp[-k^2/12]];
refC[xx_, Tf_] := N[Total[Table[If[mm == 0, caC[0]/2, caC[mm] Cos[mm xx] Exp[-mm^2 Tf]], {mm, 0, 120}]], 50];
exA = refA[xs, TT];
exB = refB[xs, TT];
exC = refC[xs, TT];
rep["REF max|A-B|", Max[Abs[exA - exB]]];
rep["REF max|A-C|", Max[Abs[exA - exC]]];
rep["REF max|B-C|", Max[Abs[exB - exC]]];
rep["REF normA", Norm[exA]];
rep["REF valA at x=0 (mid)", refA[0., TT]];
sf["S-ref done"];

(* ---------- grid control placements ---------- *)
solveMoM[m_] := NDSolveValue[eqsA, u, {x, xlo, xhi}, {t, 0, TT}, Method -> m];
knob[tag_, m_] := Module[{r = ev2[solveMoM[m]], s = pv[r], vv}, vv = Quiet[N[s[xs, TT]]]; rep[tag, vv]; tst[First[vv]]];
knob["K1 plain MoM (no knob) ", {"MethodOfLines", "SpatialDiscretization" -> {"TensorProductGrid", "DifferenceOrder" -> "Pseudospectral"}}];
knob["K2 MinMax in SpatialDisc 33 ", {"MethodOfLines", "SpatialDiscretization" -> {"TensorProductGrid", "DifferenceOrder" -> "Pseudospectral", "MinPoints" -> 33, "MaxPoints" -> 33}}];
knob["K3 MinMax in SpatialDisc 65 ", {"MethodOfLines", "SpatialDiscretization" -> {"TensorProductGrid", "DifferenceOrder" -> "Pseudospectral", "MinPoints" -> 65, "MaxPoints" -> 65}}];
knob["K4 MaxPoints at MoM level 33 ", {"MethodOfLines", "SpatialDiscretization" -> {"TensorProductGrid", "DifferenceOrder" -> "Pseudospectral"}, "MaxPoints" -> 33}];
knob["K5 MaxPoints at MoM level 65 ", {"MethodOfLines", "SpatialDiscretization" -> {"TensorProductGrid", "DifferenceOrder" -> "Pseudospectral"}, "MaxPoints" -> 65}];
sf["S-K done"];

(* ---------- operator: prebuild then time ONLY the application ---------- *)
mkop[nn_, dord_] := NDSolve`FiniteDifferenceDerivative[2, uGrid[xlo, xhi, nn], "DifferenceOrder" -> dord, PeriodicInterpolation -> True];
applySec[op_, vv_] := First[AbsoluteTiming[Quiet[N[op[vv]]]]];
Do[Module[{op = mkop[nn, "Pseudospectral"], vv = ConstantArray[Exp[2.], nn]}, sf["T spectral n=", nn, " sec=", tst[applySec[op, vv]]]], {nn, {33, 65, 129, 257, 513, 1025}}];
sf["S-T1 done"];
Do[Module[{op = mkop[nn, 2], vv = ConstantArray[Exp[2.], nn]}, sf["T fd2      n=", nn, " sec=", tst[applySec[op, vv]]]], {nn, {33, 65, 129, 257, 513, 1025}}];
sf["S-T2 done"];

(* ---------- Fourier-mode exactness ---------- *)
modetest[nn_, dord_, lbl_] := Module[{op = mkop[nn, dord], g = uGrid[xlo, xhi, nn]}, Do[Module[{e = Exp[I k g]}, got = Quiet[N[op[e]]]; want = N[-(2 Pi k/(xhi - xlo))^2 e]; sf[lbl, " k=", k, " maxrel=", tst[Max[Abs[(got - want)/want]]]]], {k, {1, 2, 3}}]];
modetest[33, "Pseudospectral", "M spectral"];
modetest[33, 2, "M fd2"];
sf["S-M done"];

(* ---------- D2 of a constant vanishes ---------- *)
Do[Module[{op = mkop[nn, "Pseudospectral"]}, sf["Z spectral nn=", nn, " maxabs D2(1)=", tst[Max[Abs[N[op[ConstantArray[1., nn]]]]]]], sf["Z err vs nu*const: ", tst[Quiet[Max[Abs[N[op[ConstantArray[1., nn]] - nu ConstantArray[1., nn]]]]]]], {nn, {17, 33}}];
sf["S-Z done"];

sf["DONE-p5"];
sfClose[];
Quit[];