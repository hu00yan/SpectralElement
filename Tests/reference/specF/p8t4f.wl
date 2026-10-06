(* lockstep: built-in FFD operator vs hand-built bigD2 power iteration.
   Same seed, same steps -> if g sequences diverge from step 1 the
   operators differ somewhere T4's single test-vector missed; if they
   track then diverge, non-normal amplification makes growth-after-200
   an unreliable metric and Eigenvalues must arbitrate. *)
$HistoryLength = 0;
Get[FileNameJoin[{Directory[], "helpers.wl"}]];
tst[e_] := ToString[N[e], InputForm];
cglg[n_] := N[-Cos[Range[0, n - 1] Pi/(n - 1)]];
bigD2[n_] := Module[{xx, cc, dd, i, j}, xx = cglg[n]; cc = Map[If[# == 1 || # == n, 2, 1] &, Range[n]];
   dd = Table[N[If[i == j, 0., cc[[i]]/cc[[j]] (-1)^(i + j)/(xx[[i]] - xx[[j]])]], {i, n}, {j, n}];
   dd = dd + DiagonalMatrix[Table[-Total[dd[[i]]], {i, n}]]; dd.dd];
applyOp[op_, v_] := If[MatrixQ[op], op.v, op[v]];

Do[Module[{g, opB, opH, vB, vH, seed, gB = {}, gH = {}, dvec = {}, i, sp},
   g = cglg[n];
   opB = Quiet[NDSolve`FiniteDifferenceDerivative[2, g, "DifferenceOrder" -> "Pseudospectral", PeriodicInterpolation -> False]];
   opH = bigD2[n];
   sp = Max[Abs[Eigenvalues[opH]]];
   seed = N[Sin[3 g] + 0.5 Cos[7 g]];
   vB = seed; vH = seed;
   Do[
      Module[{gb = N[Norm[applyOp[opB, vB]]], gh = N[Norm[applyOp[opH, vH]]]},
         AppendTo[gB, gb]; AppendTo[gH, gh];
         vB = N[applyOp[opB, vB]/gb]; vH = N[applyOp[opH, vH]/gh];
         AppendTo[dvec, Norm[vB - vH]]],
      {i, 1, 30}];
   sf["n=", tst[n], " spectral radius(Eig)=", tst[sp]];
   sf["  gB 1..30 = ", tst[gB]];
   sf["  gH 1..30 = ", tst[gH]];
   sf["  ||vB-vH|| 1..30 = ", tst[dvec]];
   (* 200-step both, like p8 does *)
   vB = seed; vH = seed;
   Module[{gb = 0., gh = 0.},
      Do[gb = N[Norm[applyOp[opB, vB]]]; vB = N[applyOp[opB, vB]/gb];
         gh = N[Norm[applyOp[opH, vH]]]; vH = N[applyOp[opH, vH]/gh], {i, 200}];
      sf["  g@200 built=", tst[gb], " hand=", tst[gh], " |vB-vH|=", tst[Norm[vB - vH]]]]],
   {n, {9, 17, 33}}];
sfClose[];
Quit[];
