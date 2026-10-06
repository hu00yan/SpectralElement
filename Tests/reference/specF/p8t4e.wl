(* arbitrate: built-in FFD D2 vs hand-built D1.D1 vs analytic seed'' *)
$HistoryLength = 0;
Get[FileNameJoin[{Directory[], "helpers.wl"}]];
tst[e_] := ToString[N[e], InputForm];
cglg[n_] := N[-Cos[Range[0, n - 1] Pi/(n - 1)]];
handD1[n_] := Module[{xx, cc, dd, i, j}, xx = cglg[n]; cc = Map[If[# == 1 || # == n, 2, 1] &, Range[n]];
   dd = Table[N[If[i == j, 0., cc[[i]]/cc[[j]] (-1)^(i + j)/(xx[[i]] - xx[[j]])]], {i, n}, {j, n}];
   dd = dd + DiagonalMatrix[Table[-Total[dd[[i]]], {i, n}]]; dd];
Do[Module[{g, seed, ana, wBuilt, d1, wSq},
   g = cglg[n];
   seed = N[Sin[3 g] + 0.5 Cos[7 g]];
   ana = N[-9 Sin[3 g] - 24.5 Cos[7 g]];
   wBuilt = Quiet[NDSolve`FiniteDifferenceDerivative[2, g, "DifferenceOrder" -> "Pseudospectral", PeriodicInterpolation -> False][seed]];
   d1 = handD1[n];
   wSq = d1.(d1.seed);
   sf["n=", tst[n]];
   sf["  ||ana||      = ", tst[Norm[ana]]];
   sf["  built  err   = ", tst[Norm[wBuilt - ana]/Norm[ana]]];
   sf["  D1.D1  err   = ", tst[Norm[wSq - ana]/Norm[ana]]];
   sf["  ||D1.seed||  = ", tst[Norm[d1.seed]], "   (should be ~|u'|, < ||ana||)"]],
   {n, {9, 17, 33}}];
sfClose[];
Quit[];
