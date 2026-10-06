(* specF / p2a : correct invocation of the built-in FFT/pseudospectral route.
   ; terminators only; never Print a composite; shallow lines. *)
$HistoryLength = 0;
Get[FileNameJoin[{Directory[], "helpers.wl"}]];
t2[e_] := If[Head[e] === String, e, ToString[N[e], InputForm]];
tst[e_] := ToString[N[e], InputForm];
mtxt[ms_] := If[Length[ms] === 0, "clean", t2[First[ms]]];
cls[v_] := If[TrueQ[v === $Failed], "FAILED", If[TrueQ[AtomQ[v]], StringJoin["ATOMIC:", Head[v]], StringJoin["LIST len=", Length[v], " head=", Head[v]]]);
ev2[expr_] := Module[{r, ms}, Block[{$MessageList = {}}, r = Quiet[expr]]; ms = $MessageList; {r, mtxt[ms]}];
probe[tag_, expr_] := Module[{r = ev2[expr]}, sf[tag, " : ", cls[r[[1]]], "  msg=", r[[2]]]; Null];
nu = 1.;
TT = 0.05;
heatBC = {u[x, 0] == Exp[-3 x^2], u[-Pi, t] == u[Pi, t]};
mkMoM[dord_] := {"MethodOfLines", "SpatialDiscretization" -> {"TensorProductGrid", "DifferenceOrder" -> dord}};

(* helper: the canonical call, explicit spatial grid of n points *)
canon[dord_, n_] := NDSolveValue[Join[{u'[t] == nu u''[x]}, heatBC], u, {x, -Pi, Pi, n}, {t, 0, TT}, Method -> mkMoM[dord]];
canon0[dord_] := NDSolveValue[Join[{u'[t] == nu u''[x]}, heatBC], u, {x, -Pi, Pi}, {t, 0, TT}, Method -> mkMoM[dord]];
doprob[d_] := probe[Join["4 DOrder=", tst[d]], canon0[d]];
sf["P2A start ", $Version];

(* 1. explicit spatial grid, 65 points, Pseudospectral *)
probe["1 explicit grid n=65 Pseudospectral", canon["Pseudospectral", 65]];
sf["S1 done"];

(* 2. no explicit grid *)
probe["2 no explicit grid Pseudospectral", canon0["Pseudospectral"]];
sf["S2 done"];

(* 3. which DifferenceOrder values are accepted *)
Do[doprob[d], {d, {1, 2, 3, 4, 5, 6, 7, 8, 9, 12, "Pseudospectral", "Spectral"}}];
sf["S3 done"];

(* 4. does the explicit grid actually control the answer? *)
gr[n_] := Module[{r = ev2[canon["Pseudospectral", n]]}, If[TrueQ[AtomQ[r[[1]]]], sf["GRID n=", n, " -> ", cls[r[[1]]]], sf["GRID n=", n, " -> ", cls[r[[1]]], "  val@x=0,t=0 ", t2[N[r[[1]][0, 0]]]]]]];
Do[gr[n], {n, {33, 65, 129}}];
sf["S4 done"];

(* 5. default MethodOfLines with periodic BC *)
probe["5 default MoM periodic", NDSolveValue[Join[{u'[t] == nu u''[x]}, heatBC], u, {x, -Pi, Pi, 65}, {t, 0, TT}, Method -> "MethodOfLines"]];
sf["S5 done"];

(* 6. Dirichlet ends + Pseudospectral *)
probe["6 Dirichlet+Pseudospectral", NDSolveValue[{u'[t] == nu u''[x], u[x, 0] == Exp[-3 x^2], u[-Pi, t] == 0, u[Pi, t] == 0}, u, {x, -Pi, Pi, 65}, {t, 0, TT}, Method -> mkMoM["Pseudospectral"]]];
sf["S6 done"];

(* 7. internal primitive: matrix or function? *)
g17 = uGrid[-Pi, Pi, 17];
fdprobe[d_] := Module[{r = ev2[NDSolve`FiniteDifferenceDerivative[2, g17, "DifferenceOrder" -> d, PeriodicInterpolation -> True]]}, sf["7 NDDeriv DOrder=", tst[d], " : ", cls[r[[1]]], " msg=", r[[2]]]];
Do[fdprobe[d], {d, {"Pseudospectral", "FiniteDifference", 2, 4}}];
sf["S7 done"];

(* 8. apply the primitive to a vector to see if a matrix emerges *)
fp = NDSolve`FiniteDifferenceDerivative[2, g17, "DifferenceOrder" -> "Pseudospectral", PeriodicInterpolation -> True];
probe["8 NDDeriv applied to ones", fp[ConstantArray[1., 17]]];
sf["S8 done"];

sf["DONE-p2a"];
sfClose[];
Quit[];