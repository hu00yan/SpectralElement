(* probe: why does rFFT disagree with refA? print pointwise values. *)
$HistoryLength = 0;
Get[FileNameJoin[{Directory[], "helpers.wl"}]];
tst[e_] := ToString[N[e], InputForm];
xlo = -Pi;
xhi = Pi;
TT = 0.05;
icD[xx_] := Exp[-3 xx^2];
refA[xx_, Tf_] := Module[{aa = 3 + 1/(4 Tf)}, N[Sum[Sqrt[Pi/aa] Exp[-3 (xx + 2 Pi kk)^2/(4 Tf aa)]/Sqrt[4 Pi Tf], {kk, -6, 6}], 50]];
perg[nd_] := Table[N[xlo + j (xhi - xlo)/nd], {j, 0, nd - 1}];
kwv[nd_] := Join[Range[0, Floor[nd/2]], -Range[Ceiling[nd/2] - 1, 1, -1]];
rFFT[nd_] := Module[{u0, kk, F, jm}, u0 = N[icD[perg[nd]]]; kk = kwv[nd]; F = Fourier[u0]; Table[N[Re[Sum[F[[mm]] Exp[-TT (2 Pi kk[[mm]]/(xhi - xlo))^2] Exp[2 Pi I kk[[mm]] jm/nd], {mm, nd}]/nd], 30], {jm, 0, nd - 1}]];

nd = 65;
vv = rFFT[nd];
ex = Table[refA[xx, TT], {xx, perg[nd]}];
sf["nd=65 pointwise (x, fft, ref, diff):"];
Do[sf["  ", tst[perg[nd][[i]]], "  ", tst[vv[[i]]], "  ", tst[ex[[i]]], "  ", tst[vv[[i]] - ex[[i]]]], {i, 1, 5}];
sf["  ... middle:"];
Do[sf["  ", tst[perg[nd][[i]]], "  ", tst[vv[[i]]], "  ", tst[ex[[i]]], "  ", tst[vv[[i]] - ex[[i]]], "  ic=", tst[icD[perg[nd][[i]]]]], {i, 30, 35}];
sf["max|fft| = ", tst[Max[Abs[vv]]], "  max|ref| = ", tst[Max[Abs[ex]]]];
sf["max|fft-ref| = ", tst[Max[Abs[vv - ex]]]];
(* control: does refA reduce to the IC at TT=0? *)
ex0 = Table[refA[xx, 0.0000001], {xx, perg[nd]}];
u0 = N[icD[perg[nd]]];
sf["TT->0 ref vs ic: max|ref0-ic| = ", tst[Max[Abs[ex0 - u0]]]];
(* control: fft with TT=0 vs ic *)
Module[{F, kk, rec, n = nd}, F = Fourier[u0]; kk = kwv[n];
   rec = Table[N[Re[Sum[F[[mm]] Exp[2 Pi I kk[[mm]] jm/n], {mm, n}]/n], 30], {jm, 0, n - 1}];
   sf["fft TT=0 vs ic: max = ", tst[Max[Abs[rec - u0]]]]];
(* control: closed-form heat solution by direct convolution integral? instead:
   compare refA to the analytic formula exp(-a x^2/(1+4 a t))/sqrt(1+4 a t) *)
refB[xx_, Tf_] := Exp[-3 xx^2/(1 + 4 3 Tf)]/Sqrt[1 + 4 3 Tf];
exB = Table[refB[xx, TT], {xx, perg[nd]}];
sf["refA vs refB(1+4at form): max diff = ", tst[Max[Abs[ex - exB]]]];
sf["  refA[0] = ", tst[refA[0., TT]], "  refB[0] = ", tst[refB[0., TT]],
   "  fft[nearest 0] = ", tst[vv[[Round[nd/2] + 1]]]];
sfClose[];
Quit[];
