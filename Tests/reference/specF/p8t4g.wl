(* what is the top of the spectrum of cheb D1 / D2, and does power
   iteration ever settle?  decisive arbiter for the T-section metric. *)
$HistoryLength = 0;
Get[FileNameJoin[{Directory[], "helpers.wl"}]];
tst[e_] := ToString[N[e], InputForm];
cglg[n_] := N[-Cos[Range[0, n - 1] Pi/(n - 1)]];
handD1[n_] := Module[{xx, cc, dd, i, j}, xx = cglg[n]; cc = Map[If[# == 1 || # == n, 2, 1] &, Range[n]];
   dd = Table[N[If[i == j, 0., cc[[i]]/cc[[j]] (-1)^(i + j)/(xx[[i]] - xx[[j]])]], {i, n}, {j, n}];
   dd = dd + DiagonalMatrix[Table[-Total[dd[[i]]], {i, n}]]; dd];

Do[Module[{d1, d2, ev2, top, v, gs = {}, k},
   d1 = handD1[n]; d2 = d1.d1;
   ev2 = Eigenvalues[d2];
   top = Take[SortBy[ev2, -Abs[#] &], 4];
   sf["n=", tst[n], "  top-4 eig(D2) = ", tst[top]];
   sf["   |.| = ", tst[Abs[top]], "   ||D2||_2 = ", tst[Norm[d2, 2]]];
   (* long power iteration: does g settle? *)
   v = N[Sin[3 cglg[n]] + 0.5 Cos[7 cglg[n]]];
   Do[Module[{g = N[Norm[d2.v]]}, AppendTo[gs, g]; v = N[d2.v/g]], {k, 2000}];
   sf["   g @ 1000,1500,2000 = ", tst[{gs[[1000]], gs[[1500]], gs[[2000]]}],
      "   max g last 500 = ", tst[Max[Take[gs, -500]]],
      "   min g last 500 = ", tst[Min[Take[gs, -500]]]]],
   {n, {9, 17, 33}}];
sfClose[];
Quit[];
