(* trace power iteration on built-in FFD CGL n=9 vs n=17 *)
$HistoryLength = 0;
Get[FileNameJoin[{Directory[], "helpers.wl"}]];
tst[e_] := ToString[N[e], InputForm];
cglg[n_] := N[-Cos[Range[0, n - 1] Pi/(n - 1)]];
Do[Module[{g, op, v, gs = {}},
   g = cglg[n];
   op = NDSolve`FiniteDifferenceDerivative[2, g, "DifferenceOrder" -> "Pseudospectral", PeriodicInterpolation -> False];
   v = N[Sin[3 g] + 0.5 Cos[7 g]];
   Do[Module[{gg = N[Norm[op[v]]]}, AppendTo[gs, gg]; v = N[op[v]/gg]], {i, 20}];
   sf["n=", tst[n], " g_1..g_20 =", tst[gs]]],
   {n, {9, 17}}];
(* also: full 200 like pitest does *)
Do[Module[{g, op, v, gr},
   g = cglg[n];
   op = NDSolve`FiniteDifferenceDerivative[2, g, "DifferenceOrder" -> "Pseudospectral", PeriodicInterpolation -> False];
   v = N[Sin[3 g] + 0.5 Cos[7 g]];
   gr = 0.;
   Do[gr = N[Norm[op[v]]]; v = N[op[v]/gr], {i, 200}];
   sf["n=", tst[n], " g after 200 =", tst[gr], " ||v||=", tst[Norm[v]]]],
   {n, {9, 17}}];
sfClose[];
Quit[];
