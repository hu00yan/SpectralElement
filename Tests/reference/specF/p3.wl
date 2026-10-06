(* specF / p3 : make the built-in route actually return numbers.
   p2b found: NDSolveValue with a 4-element x-range spec returned the
   equations UNEVALUATED under MethodOfLines.  STATE_OF_THE_ART quotes the
   docs using "MaxPoints"/"MinPoints" instead.  Also fixes:
   - refB Sum[...of NIntegrate...] never evaluated -> use Total[Table[...]];
   - assert NumericQ before Norm, never print a symbolic composite. *)
$HistoryLength = 0;
Get[FileNameJoin[{Directory[], "helpers.wl"}]];
t2[e_] := If[Head[e] === String, e, ToString[N[e], InputForm]];
tst[e_] := ToString[N[e], InputForm];
pv[r_] := r[[1]];
pv2[r_] := r[[2]];
mtxt[ms_] := If[Length[ms] === 0, "clean", t2[First[ms]]];
cls[v_] := StringJoin["K=", Head[v], " atomQ=", AtomQ[v], " len=", If[AtomQ[v], 0, Length[v]]];
ev2[expr_] := Module[{r, ms}, Block[{$MessageList = {}}, r = Quiet[expr]; ms = $MessageList]; {r, mtxt[ms]}];
chk[tag_, v_] := Module[{ok = Quiet[TrueQ[NumericQ[N[v]]]]}, sf[tag, " numeric=", tst[ok], "  cls=", cls[v], If[ok, "", "  raw=", t2[v]]]; ok];
nu = 1.;
TT = 0.05;
xlo = -Pi;
xhi = Pi;
xs = Table[N[xlo + j (xhi - xlo)/65], {j, 1, 64}];
eqs[] := {D[u[x, t], t] == nu D[u[x, t], x, x], u[x, 0] == Exp[-3 x^2], u[xlo, t] == u[xhi, t]};
sf["P3 start ", $Version];

(* ---------- references: three independent ---------- *)
refA[xx_, Tf_] := Module[{aa = 3 + 1/(4 Tf)}, N[Sum[Sqrt[Pi/aa] Exp[-3 (xx + 2 Pi kk)^2/(4 Tf aa)]/Sqrt[4 Pi Tf], {kk, -6, 6}], 50]];
caB = Table[NIntegrate[Exp[-3 zz^2] Cos[mm zz], {zz, -Pi, Pi}, WorkingPrecision -> 30]/Pi, {mm, 0, 120}];
refB[xx_, Tf_] := N[caB[[1]]/2 + Total[Table[caB[[mm + 1]] Cos[mm xx] Exp[-mm^2 Tf], {mm, 1, 120}]], 50];
caC[k_] := If[k == 0, Sqrt[Pi/3], Sqrt[Pi/3] Exp[-k^2/12]];
refC[xx_, Tf_] := N[Total[Table[If[mm == 0, caC[0]/2, caC[mm] Cos[mm xx] Exp[-mm^2 Tf]], {mm, 0, 120}]], 50];
exA = refA[xs, TT];
exB = refB[xs, TT];
exC = refC[xs, TT];
chk["REF A vs B maxabs ", Max[Abs[exA - exB]]];
chk["REF A vs C maxabs ", Max[Abs[exA - exC]]];
chk["REF norm ", Norm[exA]];
chk["REF sanity: exA[1] ", exA[[1]]];
sf["S-ref done"];

(* ---------- A. which grid-control knob works? ---------- *)
moM0 = {"MethodOfLines", "SpatialDiscretization" -> {"TensorProductGrid", "DifferenceOrder" -> "Pseudospectral"}};
moMn[nn_] = {"MethodOfLines", "SpatialDiscretization" -> {"TensorProductGrid", "DifferenceOrder" -> "Pseudospectral", "MinPoints" -> nn, "MaxPoints" -> nn}};
gridctl[tag_, m_, xspec_] := Module[{r = ev2[NDSolveValue[eqs[], u, xspec, {t, 0, TT}, Method -> m]], s = pv[r], v, tm}, tm = AbsoluteTiming[v = Quiet[N[s[xs, TT]]]]; sf[tag, " cls=", cls[s], " msg=", pv2[r], "  numeric=", tst[Quiet[TrueQ[NumericQ[N[v]]]]], "  v0=", tst[Quiet[N[v[[1]]]]], "  sec=", tst[tm[[1]]]]];
gridctl["A1 xspec={x,a,b,n} n=33 ", moM0, {x, xlo, xhi, 33}];
gridctl["A2 xspec={x,a,b}    n=auto", moM0, {x, xlo, xhi}];
gridctl["A3 MinPoints/MaxPoints=33 ", moMn[33], {x, xlo, xhi}];
gridctl["A4 MinPoints/MaxPoints=65 ", moMn[65], {x, xlo, xhi}];
sf["S-A done"];

(* ---------- B. Fourier-mode exactness: is it a true spectral operator? ---------- *)
gg = uGrid[xlo, xhi, 17];
fsp = NDSolve`FiniteDifferenceDerivative[2, gg, "DifferenceOrder" -> "Pseudospectral", PeriodicInterpolation -> True];
ffd = NDSolve`FiniteDifferenceDerivative[2, gg, "DifferenceOrder" -> 2, PeriodicInterpolation -> True];
modeop[fp_, k_] := Module[{e = Exp[I k gg], got, want}, got = Quiet[N[fp[e]]]; want = N[-(2 Pi k/(xhi - xlo))^2 e]; chk[Join["B fp k=", k], got]; chk[Join["B ratio got/want k=", k], got/want]];
Do[modeop[fsp, k], {k, {1, 2, 3}}];
Do[modeop[ffd, k], {k, {1, 2, 3}}];
sf["S-B done"];

(* ---------- C. cost scaling: FFT (n log n) or dense (n^2)? ---------- *)
scale[nn_] := Module[{g2 = uGrid[xlo, xhi, nn], fp, tm}, fp = NDSolve`FiniteDifferenceDerivative[2, g2, "DifferenceOrder" -> "Pseudospectral", PeriodicInterpolation -> True]; tm = AbsoluteTiming[Quiet[N[fp[Exp[3 xlo + Range[nn]]^2]]]]; sf["C n=", nn, " apply sec=", tst[tm[[1]]]]];
Do[scale[nn], {nn, {17, 65, 257, 1025}}];
sf["S-C done"];

(* ---------- D. dense hand-built reference for comparison (matrix build) ---------- *)
gsmall = uGrid[xlo, xhi, 65];
fsm = NDSolve`FiniteDifferenceDerivative[2, gsmall, "DifferenceOrder" -> "Pseudospectral", PeriodicInterpolation -> True];
chk["D D2 applied to 1 on 65-pt grid ", Quiet[N[fsm[ConstantArray[1., 65]]]]];
sf["S-D done"];

sf["DONE-p3"];
sfClose[];
Quit[];