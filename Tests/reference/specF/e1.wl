(* ===================================================================
   E1  -- the built-in spatial primitive itself.
        NDSolve`FiniteDifferenceDerivative is what MethodOfLines /
        TensorProductGrid calls.  Test it directly so the spatial order
        and roundoff floor are measured with the time discretisation
        removed entirely.
   =================================================================== *)
Get[FileNameJoin[{Directory[], "harness.wl"}]];

(* ---- grids ------------------------------------------------------- *)
uGrid[a_, b_, n_Integer?Positive] := Table[N[a + j (b - a)/(n - 1)], {j, 0, n - 1}];
cglGrid[a_, b_, n_Integer?Positive] :=
  Reverse[Table[N[(a + b)/2 + (b - a)/2 Cos[Pi j/(n - 1)]], {j, 0, n - 1}]];

(* ---- formatting : ONE nesting level per row ----------------------- *)
sci[e_, d_: 3] := ToString[Round[N[e], d], InputForm];
pad[args___] := StringJoin[PadRight[ToString[#, InputForm] & /@ {args}, 13]];
sfNum[args___] := sf[pad[args___]];

ev[f_, g_List] := Table[N[f /. z -> g[[j]]], {j, 1, Length[g]}];

(* max / rms / max-over-leftmost-quarter error of the 1st-derivative op *)
e1Err[g_List, f_, df_, opts_List] := Module[{n = Length[g], r, ex, er, k},
  r = N[NDSolve`FiniteDifferenceDerivative[1, g, ev[f, g], opts]];
  ex = ev[df, g];
  er = Abs[r - ex];
  k = Max[1, Ceiling[n/4]];
  {Max[er], Sqrt[Mean[er^2]], Max[Take[er, k]]}];

fA[z_] := Exp[-z^2];
dfA[z_] := -2 z Exp[-z^2];
fB[z_] := Sin[z] + 0.3 Cos[3 z] + 0.1 Sin[7 z];
dfB[z_] := Cos[z] - 0.9 Sin[3 z] + 0.7 Cos[7 z];

optPSU = {"DifferenceOrder" -> "Pseudospectral", PeriodicInterpolation -> True};
optPSC = {"DifferenceOrder" -> "Pseudospectral"};

(* =================================================================== *)
sf["#E1 built-in spatial primitive  wl " <> $Version];

(* ---- 1. accepted DifferenceOrder values ---------------------------- *)
g0 = uGrid[0., 1., 9];
sf["#E1.1 accepted DifferenceOrder on a uniform grid of 9 points:"];
rlist = Table[
  {r = Quiet[Check[NDSolve`FiniteDifferenceDerivative[1, g0, ev[Sin[#] &, g0],
      "DifferenceOrder" -> dop], $Failed]];
   pad[("DO=" <> ToString[dop, InputForm]),
       If[r === $Failed, "REJECTED", "accepted"]]},
  {dop, {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 16, 20, 8.5, 0, -2, Automatic,
    "Pseudospectral", {2, 3}, "Bogus", 8.}}];
Do[sf[rlist[[i]]], {i, Length[rlist]}];

sf["#E1.2 grid/order admissibility (Chebyshev reachable from builtins?):"];
gcl = cglGrid[0., 1., 9];
combos = {{g0, "uniform", optPSU}, {g0, "uniform", optPSC},
  {gcl, "CGL   ", optPSU}, {gcl, "CGL   ", optPSC}};
rlist = Table[
  {r = Quiet[Check[NDSolve`FiniteDifferenceDerivative[1, combos[[i, 1]],
      ev[Sin[#] &, combos[[i, 1]]], combos[[i, 3]], $Failed]];
   pad[combos[[i, 2]], If[r === $Failed, "REJECTED", "accepted len=" <> ToString[Length[r]]]]},
  {i, Length[combos]}];
Do[sf[rlist[[i]]], {i, Length[rlist]}];

(* ---- 3. ACCURACY vs n, Gaussian d/dx on [-5,10] -------------------- *)
sf[""];
sf["#E1.3  d/dx exp(-x^2) on [-5,10] : MAX abs error over all grid points"];
sf["     n  " <> pad["psUniform", "psCGL", "maxOrdUni", "fd4", "fd2"]];
rlist = Table[
  {n = 2 nn + 1;
   gu = uGrid[-5., 10., n];
   gc = cglGrid[-5., 10., n];
   ea = e1Err[gu, fA, dfA, optPSU];
   ec = e1Err[gc, fA, dfA, optPSC];
   em = e1Err[gu, fA, dfA, {"DifferenceOrder" -> n - 1}];
   e4 = e1Err[gu, fA, dfA, {"DifferenceOrder" -> 4}];
   e2 = e1Err[gu, fA, dfA, {"DifferenceOrder" -> 2}];
   pad[n, sci[ea[[1]]], sci[ec[[1]]], Round[em[[1]], 2], sci[e4[[1]]], sci[e2[[1]]]]},
  {nn, 8}];
Do[sf[rlist[[i]]], {i, Length[rlist]}];

sf["#E1.4 same, MAX error over the leftmost quarter only (Runge zone)"];
sf["     n  " <> pad["psUniform", "psCGL", "maxOrdUni", "fd4"]];
rlist = Table[
  {n = 2 nn + 1;
   gu = uGrid[-5., 10., n];
   gc = cglGrid[-5., 10., n];
   ea = e1Err[gu, fA, dfA, optPSU];
   ec = e1Err[gc, fA, dfA, optPSC];
   em = e1Err[gu, fA, dfA, {"DifferenceOrder" -> n - 1}];
   e4 = e1Err[gu, fA, dfA, {"DifferenceOrder" -> 4}];
   pad[n, sci[ea[[3]]], sci[ec[[3]]], Round[em[[3]], 2], sci[e4[[3]]]]},
  {nn, 8}];
Do[sf[rlist[[i]]], {i, Length[rlist]}];

(* ---- 4. periodic band-limited data --------------------------------- *)
sf[""];
sf["#E1.5  periodic: u = sin x + 0.3cos3x + 0.1sin7x on [-pi,pi], errMax"];
sf["     n  " <> pad["psUniform", "fd4", "fd2"]];
rlist = Table[
  {n = 2 nn + 1;
   gu = uGrid[-Pi, Pi, n];
   ea = e1Err[gu, fB, dfB, optPSU];
   e4 = e1Err[gu, fB, dfB, {"DifferenceOrder" -> 4}];
   e2 = e1Err[gu, fB, dfB, {"DifferenceOrder" -> 2}];
   pad[n, sci[ea[[1]]], sci[e4[[1]]], sci[e2[[1]]]]},
  {nn, 8}];
Do[sf[rlist[[i]]], {i, Length[rlist]}];

(* ---- 5. aliasing floor of the periodic route ----------------------- *)
sf[""];
sf["#E1.6  aliasing: d/dx exp(-x^2) on [-pi,pi] periodic. drop the 2 aliased pts"];
sf["      n  " <> pad["maxErrAll", "maxErrNoAlias", "ratio"]];
rlist = Table[
  {n = 2 nn;
   gu = uGrid[-Pi, Pi, n];
   r = N[NDSolve`FiniteDifferenceDerivative[1, gu, ev[Exp[-#^2] &, gu], optPSU]];
   ex = ev[(-2 # Exp[-#^2]) &, gu];
   er = Abs[r - ex];
   keep = Drop[er, {n/2 + 1}];
   rat = Max[er]/Max[keep];
   pad[n, sci[Max[er]], sci[Max[keep]], sci[rat]]},
  {nn, 8}];
Do[sf[rlist[[i]]], {i, Length[rlist]}];

sfClose[];