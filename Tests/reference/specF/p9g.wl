(* p9g -- why did the poly-exactness gate print -1. while the roundtrip
   printed 1.3e-15?  Both feed Cos[Range[0,n] Pi/n] through rmax's
   VectorQ[..., MachineNumberQ] guard.  Measure machine-ness at every
   stage directly (no Position tricks -- VectorQ/Head only). *)
$HistoryLength = 0;
Get[FileNameJoin[{Directory[], "helpers.wl"}]];
tst[e_] := StringTake[ToString[e, InputForm], Min[240, StringLength[ToString[e, InputForm]]]];

(* --- is Cos[Range Pi/N] machine at all? --- *)
x64 = Cos[Range[0, 64] Pi/64];
sf["x64: machineQ=", tst[VectorQ[x64, MachineNumberQ]],
   " elem2Head=", tst[Head[x64[[2]]]], " elem2=", tst[x64[[2]]]];
x16 = Cos[Range[0, 16] Pi/16];
sf["x16: machineQ=", tst[VectorQ[x16, MachineNumberQ]],
   " elem2Head=", tst[Head[x16[[2]]]], " elem2=", tst[x16[[2]]]];

(* --- poly pipeline (the -1 producer) --- *)
fp = x16^4 - 2 x16^2 + 1;
sf["fp: machineQ=", tst[VectorQ[fp, MachineNumberQ]],
   " numericQ=", tst[VectorQ[fp, NumericQ]], " elem1=", tst[fp[[1]]]];
ex = 12 x16^2 - 4;
sf["exactP: machineQ=", tst[VectorQ[ex, MachineNumberQ]],
   " elem1=", tst[ex[[1]]]];

(* same defs as p9 (sctOf path, no runtime calib needed) *)
sctOf[Np_] := 1/Sqrt[2 Np];
toC[u_, Np_] := Module[{y = FourierDCT[u, 1]/(sctOf[Np] Np)},
   y[[1]] = y[[1]]/2; y[[Np + 1]] = y[[Np + 1]]/2; y];
fromC[c_, Np_] := Module[{e = c},
   e[[1]] = 2 c[[1]]; e[[Np + 1]] = 2 c[[Np + 1]];
   FourierDCT[e, 1]/(2 sctOf[Np])];
d1[a_, Np_] := Module[{R, b},
   R = Developer`ToPackedArray[Table[0., {Np + 3}]];
   b = Developer`ToPackedArray[Table[0., {Np + 1}]];
   Do[R[[j + 1]] = (j + 1) a[[j + 2]] + R[[j + 3]], {j, Np - 1, 0, -1}];
   b[[1]] = R[[1]];
   Do[b[[j + 1]] = 2 R[[j + 1]], {j, 1, Np - 1}];
   b];
d2fast[u_, Np_] := fromC[d1[d1[toC[u, Np], Np], Np], Np];

f = d2fast[fp, 16];
sf["d2fast(fp): head=", tst[Head[f]],
   " len=", tst[If[ListQ[f], Length[f], -1]],
   " machineQ=", tst[If[ListQ[f], VectorQ[f, MachineNumberQ], False]],
   " elem1=", tst[If[ListQ[f], f[[1]], f]]];
poly = If[VectorQ[f, MachineNumberQ] && VectorQ[ex, MachineNumberQ],
   Max[Abs[f - ex]], -1.];
sf["poly diff=", tst[poly],
   " lenF=", tst[If[ListQ[f], Length[f], -1]], " lenEx=", tst[Length[ex]]];

(* --- roundtrip input (the 1.3e-15 producer) for comparison --- *)
fv64 = Exp[Sin[3 x64]] + 0.3/(1 + 25 x64^2);
sf["fv64: machineQ=", tst[VectorQ[fv64, MachineNumberQ]],
   " elem1Head=", tst[Head[fv64[[1]]]], " elem1=", tst[fv64[[1]]]];
cf = toC[fv64, 64];
sf["toC(fv64): machineQ=", tst[VectorQ[cf, MachineNumberQ]],
   " roundtrip=", tst[If[VectorQ[fromC[cf, 64], MachineNumberQ] &&
      VectorQ[fv64, MachineNumberQ], Max[Abs[fromC[cf, 64] - fv64]], -1.]]];
sf["DONE-p9g"];
sfClose[];
Quit[];
