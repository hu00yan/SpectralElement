(* why does built-in FFD give growth=1.47e-11 at n=9 but 16.9 at n=17? *)
$HistoryLength = 0;
Get[FileNameJoin[{Directory[], "helpers.wl"}]];
tst[e_] := ToString[N[e], InputForm];
cglg[n_] := N[-Cos[Range[0, n - 1] Pi/(n - 1)]];
bigD2[n_] := Module[{xx, cc, dd, i, j}, xx = cglg[n]; cc = Map[If[# == 1 || # == n, 2, 1] &, Range[n]];
   dd = Table[N[If[i == j, 0., cc[[i]]/cc[[j]] (-1)^(i + j)/(xx[[i]] - xx[[j]])]], {i, n}, {j, n}];
   dd = dd + DiagonalMatrix[Table[-Total[dd[[i]]], {i, n}]]; dd.dd];
Do[Module[{g, op, seed, w, msgs = {}},
   g = cglg[n];
   Block[{$MessageList = {}},
      op = NDSolve`FiniteDifferenceDerivative[2, g, "DifferenceOrder" -> "Pseudospectral", PeriodicInterpolation -> False];
      msgs = $MessageList];
   seed = N[Sin[3 g] + 0.5 Cos[7 g]];
   w = Quiet[op[seed]];
   sf["n=", tst[n], " grid0=", tst[g[[1]]], " gridN=", tst[g[[n]]],
      " | msgs=", If[Length[msgs] === 0, "clean", tst[First[msgs]]],
      " | Head(w)=", tst[Head[w]], " len=", tst[If[AtomQ[w], 0, Length[w]]],
      " | Norm(w)=", tst[Quiet[Norm[w]]],
      " | w[[1]]=", tst[Quiet[N[w[[1]]]]],
      " | ||w - bigD2.seed||=", tst[Quiet[Norm[w - bigD2[n].seed]]]]],
   {n, {9, 17}}];
sfClose[];
Quit[];
