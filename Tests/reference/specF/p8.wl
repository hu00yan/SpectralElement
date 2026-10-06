(* specF / p8 FIXED : same four experiments as p8, with the two bugs that
   made the original output unreadable repaired:

   BUG 1 (relerr unevaluated):  exA was built ONCE on the fixed 64-point
     xs grid, while rFFT[nd] returns nd points -> Thread::tdlen ->
     relerr stayed unevaluated and sf printed "0.411*Norm[{...}]".
     FIX: the reference is regenerated on perg[nd] (the SAME grid the
     solver returns) for every nd, and relerr guards the lengths.

   BUG 2 (pitest printed one garbage line):  the Module of pitest closed
     early -- "seed/gr/sf" sat OUTSIDE it as top-level statements with
     unbound g/op, so the Do loops only built operators and the only
     line emitted was "tag | n=0. growth=0." (Length[unbound symbol]=0).
     FIX: everything moved inside Module, tag/n/growth all printed.

   Sections: (4) exact-in-time FFT vs closed form on the matching grid;
   (1)+(2) Trefethen-Trummer power iteration, built-in vs hand-built D2;
   (3) the elliptic wall: NDSolve pseudo / FEM / default, with timing. *)
$HistoryLength = 0;
Get[FileNameJoin[{Directory[], "helpers.wl"}]];
t2[e_] := If[Head[e] === String, e, ToString[N[e], InputForm]];
tst[e_] := ToString[N[e], InputForm];
pv[r_] := r[[1]];
pv2[r_] := r[[2]];
mtxt[ms_] := If[Length[ms] === 0, "clean", t2[First[ms]]];
ev2[expr_] := Module[{r, ms}, Block[{$MessageList = {}}, r = Quiet[expr]; ms = $MessageList]; {r, mtxt[ms]}];
isnum[v_] := Quiet[TrueQ[VectorQ[N[v], NumericQ]]];
rep[tag_, v_] := Module[{ok = isnum[v]}, sf[tst[tag], " | K=", Head[v], " len=", If[AtomQ[v], 0, Length[v]], " numeric=", ok, " | v0=", tst[Quiet[N[v[[1]]]]]]; ok];
xlo = -Pi;
xhi = Pi;
nu = 1.;
TT = 0.05;
xs = Table[N[xlo + j (xhi - xlo)/65], {j, 1, 64}];
icD[xx_] := Exp[-3 xx^2];
(* length-guarded relerr: a length mismatch now returns the sentinel -2.
   instead of leaving the whole expression unevaluated downstream *)
relerr[a_, b_] := If[Length[a] =!= Length[b], -2.,
   Norm[N[a - b]]/Norm[N[b]]];
(* reference on the SOLVER's own grid: same nd, same node positions *)
refA[xx_, Tf_] := Module[{aa = 3 + 1/(4 Tf)}, N[Sum[Sqrt[Pi/aa] Exp[-3 (xx + 2 Pi kk)^2/(4 Tf aa)]/Sqrt[4 Pi Tf], {kk, -6, 6}], 50]];
perg[nd_] := Table[N[xlo + j (xhi - xlo)/nd], {j, 0, nd - 1}];
(* reference on the SOLVER's own grid: same nd, same node positions *)
exg[nd_Integer] := Table[refA[xx, TT], {xx, perg[nd]}];
exA = Table[refA[xx, TT], {xx, xs}];
sf["P8FIX start ", $Version];
sec[tag_, tm_] := sf["  TIMING ", tag, " = ", tst[tm], " s"];

(* ---------- (4) exact-in-time Fourier --------------------------------
   Measured convention (probe p8f): Mathematica's Fourier is
     F_m = (1/Sqrt[n]) Sum_j f_j Exp[+2 Pi I m j / n],
   so the inverse is Exp[-2 Pi I m j/n]/Sqrt[n] -- NOT /n, NOT +sign.
   The earlier rFFT used +sign and /nd: round-trip 0.87 and a shrinking
   amplitude (max|out| 0.098 vs 0.79 true).  Time stepping is exact:
   multiply each mode by Exp[-nu k^2 TT].  kwv must be in FFT storage
   order {0..floor(n/2), -ceil(n/2)+1..-1} to pair F[[mm]] with its mode. *)
kwv[nd_] := Join[Range[0, Floor[nd/2]], -Range[Ceiling[nd/2] - 1, 1, -1]];
rFFT[nd_] := Module[{u0, kk, F, Fm}, u0 = N[icD[perg[nd]]]; kk = kwv[nd];
   F = Fourier[u0];
   Fm = F Exp[-TT (2 Pi kk/(xhi - xlo))^2];
   N[Re[InverseFourier[Fm]], 30]];
(* R0 round-trip: TT=0 must reproduce the samples, via InverseFourier and
   via the explicit Sum form -- confirms 1/Sqrt[n] + the sign together. *)
Module[{u0, F, kk, rec1, rec2, n = 65}, u0 = N[icD[perg[n]]]; F = Fourier[u0]; kk = kwv[n];
   rec1 = N[Re[InverseFourier[F]], 30];
   rec2 = Table[N[Re[Sum[F[[mm]] Exp[-2 Pi I kk[[mm]] jm/n], {mm, n}]/Sqrt[n]], 30], {jm, 0, n - 1}];
   sf["R0 round-trip: max|InverseFourier-ic| = ", tst[Max[Abs[rec1 - u0]]],
      " | max|explicit Sum-ic| = ", tst[Max[Abs[rec2 - u0]]],
      " | max|IF - explicit| = ", tst[Max[Abs[rec1 - rec2]]]]];
Do[Module[{vv, er, tm, ex}, tm = AbsoluteTiming[vv = Quiet[rFFT[nd]]]; ex = exg[nd];
   er = If[isnum[vv], relerr[vv, ex], -1.];
   sf["R1 FFT-exact nd=", tst[nd], " | relerr=", tst[er], " sec=", tst[tm[[1]]],
      " (ref len ", tst[Length[ex]], " vs out ", tst[Length[vv]], ")"]],
   {nd, {17, 33, 65, 129, 257, 513}}];
sf["S-R1 done"];

(* ---------- (1)+(2) power iteration, scalar growth ---------- *)
cglg[n_] := N[-Cos[Range[0, n - 1] Pi/(n - 1)]];
perpg[n_] := Table[N[-1 + 2 j/n], {j, 0, n - 1}];
(* NOTE: the off-diagonal c_i/c_j (-1)^(i+j)/(x_i-x_j) with diagonal =
   -row sum is the CHEBYSHEV FIRST-derivative matrix (Trefethen cheb.m).
   The original p8 called it D2 and never squared it, so "hand-built D2"
   was silently measuring D1 (eigenvalues ~n^2, not ~n^4).  Square it. *)
bigD2[n_] := Module[{xx, cc, dd, i, j}, xx = cglg[n]; cc = Map[If[# == 1 || # == n, 2, 1] &, Range[n]];
   dd = Table[N[If[i == j, 0., cc[[i]]/cc[[j]] (-1)^(i + j)/(xx[[i]] - xx[[j]])]], {i, n}, {j, n}];
   dd = dd + DiagonalMatrix[Table[-Total[dd[[i]]], {i, n}]]; dd.dd];
(* op may be an operator (NDSolve`FFD) or a raw matrix (bigD2); WL does NOT
   evaluate matrix[v] -- it stays unevaluated and v=op[v]/g nests forever
   (that was the S-T4 hang).  Dot does the matrix-vector product. *)
applyOp[op_, v_] := If[MatrixQ[op], op.v, op[v]];
powgrow[op_, seed_, iters_] := Module[{v = seed, g = 0., i},
   Do[g = N[Norm[applyOp[op, v]]]; v = N[applyOp[op, v]/g], {i, iters}]; g];
(* FIXED: the whole body lives inside Module; nothing leaks to top level *)
pitest[tag_, g_, dord_, per_, it_] := Module[{op, seed, gr, tm},
   tm = AbsoluteTiming[op = Quiet[NDSolve`FiniteDifferenceDerivative[2, g, "DifferenceOrder" -> dord, PeriodicInterpolation -> per]]];
   seed = N[Sin[3 g] + 0.5 Cos[7 g]];
   gr = Quiet[powgrow[op, seed, it]];
   sf[tst[tag], " | n=", tst[Length[g]], " | growth=", tst[gr], " | sec=", tst[tm[[1]]]];
   gr];
Do[pitest["T built-in CHEB-CGL pseudospec", cglg[n], "Pseudospectral", False, 200], {n, {9, 17, 33, 65}}];
sf["S-T1 done"];
Do[pitest["T built-in UNIFORM-PERIODIC pseudospec", perpg[n], "Pseudospectral", True, 200], {n, {9, 17, 33, 65}}];
sf["S-T2 done"];
(* T3 was labelled "hand-built" but called pitest (built-in) in the
   original -- so T1 vs T3 never actually compared anything.  Now it
   really applies bigD2. *)
Do[Module[{op, seed, gr, tm},
   op = bigD2[n];
   seed = N[Sin[3 cglg[n]] + 0.5 Cos[7 cglg[n]]];
   tm = AbsoluteTiming[gr = powgrow[op, seed, 200]];
   sf["T hand-built CGL collocation D2 n=", tst[n], " growth=", tst[gr],
      " sec=", tst[tm[[1]]]]],
   {n, {9, 17, 33, 65}}];
sf["S-T3 done"];
(* T4: built-in FFD vs hand-built bigD2, same seed, pointwise agreement *)
Do[Module[{g, opB, opH, seed, wB, wH},
   g = cglg[n];
   opB = Quiet[NDSolve`FiniteDifferenceDerivative[2, g, "DifferenceOrder" -> "Pseudospectral", PeriodicInterpolation -> False]];
   opH = bigD2[n];
   seed = N[Sin[3 g] + 0.5 Cos[7 g]];
   wB = Quiet[opB[seed]]; wH = opH.seed;
   sf["T4 built-in vs hand-built n=", tst[n],
      " rel-diff=", tst[Norm[wB - wH]/Norm[wB]]]],
   {n, {9, 17, 33, 65}}];
sf["S-T4 done"];

(* ---------- (3) the elliptic wall ----------
   -v'' = Sin[Pi x] on (0,1), v(0)=v(1)=0, exact Sin[Pi x]/Pi^2.
   All three NDSolve routes timed AND scored at x=1/2 against the exact
   value; the message string is printed as-is (it IS a string). *)
pois = {-D[vv[x], x, x] == Sin[Pi x], vv[0] == 0, vv[1] == 0};
(* exact: -v''=Sin[Pi x], v(0)=v(1)=0  =>  v = Sin[Pi x]/Pi^2.
   (an earlier draft wrongly divided by x(1-x); that function does not
   even vanish at the endpoints) *)
pfex[xx_] := Sin[Pi xx]/Pi^2;
pfHalf = N[pfex[1/2]];
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
wtest["W2 FiniteElement", Method -> "FiniteElement"];
wtest["W3 default"];
sf["W exact v(1/2) = ", tst[pfHalf]];
sf["S-W done"];

sf["DONE-p8fix"];
sfClose[];
Quit[];
