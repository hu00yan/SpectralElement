(* p9d -- diagnose why `rel = Max[Abs[fast - Reverse[dense]]]` stayed
   unevaluated in p9 (printed as Max[Sqrt[Im[...]]] and hung the next size).
   Also verify the DCT scale hypothesis sct(N) = 1/Sqrt[2N] (sct measured at
   N=16 was 2^-2.5; roundtrip at N=64 failed by k^2 with k=1/2 => size dep). *)
$HistoryLength = 0;
Get[FileNameJoin[{Directory[], "helpers.wl"}]];
tst[e_] := StringTake[ToString[e, InputForm], Min[260, StringLength[ToString[e, InputForm]]]];
tstN[e_] := ToString[N[e], InputForm];

(* --- scale hypothesis --- *)
Do[Module[{nv = nn + 1, ones, yy},
   ones = Table[1., {nv}];
   yy = FourierDCT[ones, 1];
   sf["scale N=", tst[nn], " measured sct=", tstN[yy[[1]]/(2 nn)],
      " 1/Sqrt[2N]=", tstN[1/Sqrt[2 nn]]]],
  {nn, {16, 64, 128}}];

(* --- same defs as p9 (sct from N=16 calibration, deliberately wrong at 64) *)
NC = 16;
sct = N[FourierDCT[Table[1., {NC + 1}], 1][[1]]/(2 NC)];
dctI[v_] := FourierDCT[v, 1]/sct;
toC[u_, Np_] := Module[{y = dctI[u]/Np}, y[[1]] = y[[1]]/2; y[[Np + 1]] = y[[Np + 1]]/2; y];
fromC[c_, Np_] := Module[{e = c}, e[[1]] = 2 c[[1]]; e[[Np + 1]] = 2 c[[Np + 1]]; dctI[e]/2];
d1[a_, Np_] := Module[{R, b},
   R = Developer`ToPackedArray[Table[0., {Np + 3}]];
   b = Developer`ToPackedArray[Table[0., {Np + 1}]];
   Do[R[[j + 1]] = (j + 1) a[[j + 2]] + R[[j + 3]], {j, Np - 1, 0, -1}];
   b[[1]] = R[[1]];
   Do[b[[j + 1]] = 2 R[[j + 1]], {j, 1, Np - 1}];
   b];
d2fast[u_, Np_] := fromC[d1[d1[toC[u, Np], Np], Np], Np];
cglg[n_] := N[-Cos[Range[0, n - 1] Pi/(n - 1)]];
bigD2v[n_] := Module[{xx, cc, sg, a, b, dd, ii},
   xx = cglg[n]; cc = Map[If[# == 1 || # == n, 2., 1.] &, Range[n]];
   sg = (-1.)^Range[n]; a = sg cc; b = sg/cc;
   dd = Outer[Times, a, b]/(Outer[Minus, xx, xx] + IdentityMatrix[n]) - IdentityMatrix[n];
   ii = -Map[Total, dd];
   dd = dd + DiagonalMatrix[ii];
   dd.dd];

(* --- walk the pipeline at n=65 --- *)
nv = 64;
xf = Cos[Range[0, nv] Pi/nv];
u = Exp[Sin[3 xf]] + 0.3/(1 + 25 xf^2);
sf["u: head=", tst[Head[u]], " len=", tst[Length[u]], " vecQ=", tst[VectorQ[u, MachineNumberQ]]];
dd = bigD2v[65];
sf["dd: head=", tst[Head[dd]], " dims=", tst[Dimensions[dd]],
   " matQ=", tst[MatrixQ[dd]], " packed=", tst[Developer`PackedArrayQ[dd]]];
bad = Position[dd, x_ /; !MachineNumberQ[x], {2}];
sf["dd nonmachine: n=", tst[Length[bad]],
   If[Length[bad] > 0, " vals=" <> tst[Extract[dd, Take[bad, Min[4, Length[bad]]]]], ""]];
dense = Dot[dd, Reverse[u]];
sf["dense: head=", tst[Head[dense]],
   " len=", tst[If[ListQ[dense], Length[dense], -1]],
   " vecQ=", tst[If[ListQ[dense], VectorQ[dense], False]]];
badD = Position[dense, x_ /; !MachineNumberQ[x]];
sf["dense nonmachine: n=", tst[Length[badD]],
   If[Length[badD] > 0, " pos=" <> tst[Take[badD, Min[4, Length[badD]]]] <>
      " vals=" <> tst[Extract[dense, Take[badD, Min[4, Length[badD]]]]], ""]];
fastD = d2fast[u, nv];
sf["fast: head=", tst[Head[fastD]],
   " len=", tst[If[ListQ[fastD], Length[fastD], -1]],
   " vecQ=", tst[If[ListQ[fastD], VectorQ[fastD], False]]];
badF = Position[fastD, x_ /; !MachineNumberQ[x]];
sf["fast nonmachine: n=", tst[Length[badF]],
   If[Length[badF] > 0, " pos=" <> tst[Take[badF, Min[4, Length[badF]]]] <>
      " vals=" <> tst[Extract[fastD, Take[badF, Min[4, Length[badF]]]]], ""]];
rg = Reverse[dense];
sf["reverse(dense): head=", tst[Head[rg]], " len=", tst[If[ListQ[rg], Length[rg], -1]]];
diff = fastD - rg;
sf["diff: head=", tst[Head[diff]],
   " len=", tst[If[ListQ[diff], Length[diff], -1]],
   " vecQ=", tst[If[ListQ[diff], VectorQ[diff], False]],
   " depth=", tst[Depth[diff]]];
If[Head[diff] =!= List, sf["diff is NOT a list; diff[[1]]=", tst[diff[[1]]]]];
mm = Max[Abs[diff]];
sf["MaxAbs: head=", tst[Head[mm]], " numericQ=", tst[NumericQ[mm]]];
sf["DONE-p9d"];
sfClose[];
Quit[];
