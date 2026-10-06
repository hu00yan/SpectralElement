(* p8 section S-T4 only: hand-built bigD2 power iteration *)
$HistoryLength = 0;
Get[FileNameJoin[{Directory[], "helpers.wl"}]];
tst[e_] := ToString[N[e], InputForm];
cglg[n_] := N[-Cos[Range[0, n - 1] Pi/(n - 1)]];
bigD2[n_] := Module[{xx, cc, dd, i, j}, xx = cglg[n]; cc = Map[If[# == 1 || # == n, 2, 1] &, Range[n]];
   dd = Table[N[If[i == j, 0., cc[[i]]/cc[[j]] (-1)^(i + j)/(xx[[i]] - xx[[j]])]], {i, n}, {j, n}];
   dd = dd + DiagonalMatrix[Table[-Total[dd[[i]]], {i, n}]]; dd.dd];
applyOp[op_, v_] := If[MatrixQ[op], op.v, op[v]];
powgrow[op_, seed_, iters_] := Module[{v = seed, g = 0., i},
   Do[g = N[Norm[applyOp[op, v]]]; v = N[applyOp[op, v]/g], {i, iters}]; g];
sf["T4 start"];
Do[Module[{op, seed, gr, tm, ev},
   tm = AbsoluteTiming[op = bigD2[n]];
   sf["  built n=", tst[n], " sec=", tst[tm[[1]]],
      " ||D2||_F=", tst[Norm[op]], " spectral radius=", tst[Max[Abs[Eigenvalues[op]]]]];
   seed = N[Sin[3 cglg[n]]];
   tm = AbsoluteTiming[gr = Quiet[powgrow[op, seed, 200]]];
   sf["  T4 n=", tst[n], " growth=", tst[gr], " sec=", tst[tm[[1]]]]],
   {n, {9, 17, 33, 65}}];
sf["S-T4 done"];
sfClose[];
Quit[];