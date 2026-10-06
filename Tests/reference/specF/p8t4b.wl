(* isolate: why does powgrow[bigD2[9], ...] hang? *)
$HistoryLength = 0;
Get[FileNameJoin[{Directory[], "helpers.wl"}]];
tst[e_] := ToString[N[e], InputForm];
cglg[n_] := N[-Cos[Range[0, n - 1] Pi/(n - 1)]];
bigD2[n_] := Module[{xx, cc, dd, i, j}, xx = cglg[n]; cc = Map[If[# == 1 || # == n, 2, 1] &, Range[n]];
   dd = Table[N[If[i == j, 0., cc[[i]]/cc[[j]] (-1)^(i + j)/(xx[[i]] - xx[[j]])]], {i, n}, {j, n}];
   dd = dd + DiagonalMatrix[Table[-Total[dd[[i]]], {i, n}]]; dd];
n = 9;
op = bigD2[n];
sf["op dims: ", tst[Dimensions[op]], "  finite: ", tst[And @@ Map[NumericQ, op]]];
seed = N[Sin[3 cglg[n]]];
sf["seed: ", tst[seed]];
v = seed;
Do[
   g = N[Norm[op[v]]];
   sf["i=", tst[i], " g=", tst[g], " v0=", tst[v[[1]]]];
   v = N[op[v]/g];
   , {i, 1, 12}];
sf["survived 12 iters"];
sfClose[];
Quit[];
