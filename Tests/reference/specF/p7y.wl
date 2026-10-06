(* p7x measured the ACCURACY side of tightening AccuracyGoal/PrecisionGoal;
   this supplies the SPEED side for the report table.  Each config is solved
   twice, the second (warm) solve is timed. *)
$HistoryLength = 0;
Get[FileNameJoin[{Directory[], "helpers.wl"}]];
tst[e_] := ToString[N[e], InputForm];
t2[e_] := If[Head[e] === String, e, ToString[N[e], InputForm]];
mtxt[ms_] := If[Length[ms] === 0, "clean", t2[First[ms]]];
ev2[expr_] := Module[{r, ms}, Block[{$MessageList = {}}, r = Quiet[expr]; ms = $MessageList]; {r, mtxt[ms]}];
isnum[v_] := Quiet[TrueQ[VectorQ[N[v], NumericQ]]];
relerr[a_, b_] := If[Length[a] === Length[b], Norm[N[a - b]]/Norm[N[b]], -1.];
xlo = -Pi; xhi = Pi; TT = 0.05;
refA[xx_, Tf_] := Module[{aa = 3 + 1/(4 Tf)}, N[Sum[Sqrt[Pi/aa] Exp[-3 (xx + 2 Pi kk)^2/(4 Tf aa)]/Sqrt[4 Pi Tf], {kk, -6, 6}], 50]];
xs = Table[N[xlo + j (xhi - xlo)/65], {j, 1, 64}];
exA = Table[refA[xx, TT], {xx, xs}];
eqsA = {D[u[x, t], t] == D[u[x, t], x, x], u[x, 0] == Exp[-3 x^2], u[xlo, t] == u[xhi, t]};
moMp[n_] := {"MethodOfLines", "SpatialDiscretization" -> {"TensorProductGrid", "DifferenceOrder" -> "Pseudospectral", "MinPoints" -> n, "MaxPoints" -> n}};
binSolve[m_, opts___] := NDSolveValue[eqsA, u, {x, xlo, xhi}, {t, 0, TT}, Method -> m, opts];
probe[tag_, n_, opts___] := Module[{s, m, tm, vv, er},
   Quiet[s = binSolve[moMp[n], opts]];
   tm = AbsoluteTiming[{s, m} = ev2[binSolve[moMp[n], opts]]];
   vv = Quiet[N[s[xs, TT]]];
   er = If[isnum[vv], relerr[vv, exA], -1.];
   sf["  ", tag, " | relerr=", tst[er], " sec=", tst[tm[[1]]], " msg=", m]];
sf["speed cost of tightening AccuracyGoal/PrecisionGoal (pseudo route)"];
probe["n=65  default    ", 65];
probe["n=65  AgPg10     ", 65, AccuracyGoal -> 10, PrecisionGoal -> 10];
probe["n=129 default    ", 129];
probe["n=129 AgPg10     ", 129, AccuracyGoal -> 10, PrecisionGoal -> 10];
probe["n=257 default    ", 257];
probe["n=257 AgPg8      ", 257, AccuracyGoal -> 8, PrecisionGoal -> 8];
probe["n=257 AgPg10     ", 257, AccuracyGoal -> 10, PrecisionGoal -> 10];
probe["n=257 AgPg12     ", 257, AccuracyGoal -> 12, PrecisionGoal -> 12];
sfClose[];
Quit[];
