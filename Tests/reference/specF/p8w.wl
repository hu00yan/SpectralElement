(* p8 section (3) only: the elliptic wall -- 3 NDSolve routes, timed. *)
$HistoryLength = 0;
Get[FileNameJoin[{Directory[], "helpers.wl"}]];
t2[e_] := If[Head[e] === String, e, ToString[N[e], InputForm]];
tst[e_] := ToString[N[e], InputForm];
mtxt[ms_] := If[Length[ms] === 0, "clean", t2[First[ms]]];
ev2[expr_] := Module[{r, ms}, Block[{$MessageList = {}}, r = Quiet[expr]; ms = $MessageList]; {r, mtxt[ms]}];
pois = {-D[vv[x], x, x] == Sin[Pi x], vv[0] == 0, vv[1] == 0};
pfex[xx_] := Sin[Pi xx]/Pi^2;
pfHalf = N[pfex[1/2]];
sf["W start, exact v(1/2) = ", tst[pfHalf]];
wtest[tag_, opts___Rule] := Module[{r, ms, tm, val, er},
   tm = AbsoluteTiming[{r, ms} = ev2[Quiet[Check[
      NDSolveValue[pois, vv[1/2], {x, 0, 1}, opts], $Failed]]]];
   val = If[Head[r] === InterpolatingFunction, Quiet[N[r[1/2]]], N[r]];
   er = If[NumericQ[val], val - pfHalf, $Failed];
   sf[tst[tag], " | v(1/2)=", tst[val], " | err=", tst[er],
      " | msg=", ms, " | sec=", tst[tm[[1]]]];
   val];
wtest["W1 pseudo route (TensorProductGrid Pseudospectral n=65)",
   Method -> {"MethodOfLines", "SpatialDiscretization" -> {"TensorProductGrid", "DifferenceOrder" -> "Pseudospectral", "MinPoints" -> 65, "MaxPoints" -> 65}}];
sf["S-W1 done"];
wtest["W2 FiniteElement", Method -> "FiniteElement"];
sf["S-W2 done"];
wtest["W3 default"];
sf["S-W done"];
sfClose[];
Quit[];
