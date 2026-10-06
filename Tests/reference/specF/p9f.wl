(* p9f -- definitive junk localization.  p9e's `nj` used Position[...,{2}]
   whose level semantics look wrong (O2 counted 4290 > 65^2), and for
   vectors level 2 skips the elements entirely.  Use direct tests:
   VectorQ/Count[Flatten] on known-clean random matrices to calibrate
   Position, then the real suspects. *)
$HistoryLength = 0;
Get[FileNameJoin[{Directory[], "helpers.wl"}]];
tst[e_] := StringTake[ToString[e, InputForm], Min[240, StringLength[ToString[e, InputForm]]]];
(* --- calibrate Position semantics on a KNOWN-clean matrix --- *)
cm = RandomReal[1., {3, 3}];
sf["calib clean 3x3: Position with {2} -> ",
   tst[Length[Position[cm, x_ /; !MachineNumberQ[x], {2}]]],
   " | no levelspec -> ", tst[Length[Position[cm, x_ /; !MachineNumberQ[x]]]],
   " | VectorQ[cm[[1]], MachineNumberQ] -> ", tst[VectorQ[cm[[1]], MachineNumberQ]]];
(* --- the real suspects --- *)
n = 65;
xx = N[-Cos[Range[0, n - 1] Pi/(n - 1)]];
cc = Map[If[# == 1 || # == n, 2., 1.] &, Range[n]];
sg = (-1.)^Range[n];
a = sg cc;
b = sg/cc;
sf["VectorQ machine: xx=", tst[VectorQ[xx, MachineNumberQ]],
   " cc=", tst[VectorQ[cc, MachineNumberQ]],
   " sg=", tst[VectorQ[sg, MachineNumberQ]],
   " a=", tst[VectorQ[a, MachineNumberQ]],
   " b=", tst[VectorQ[b, MachineNumberQ]]];
sf["xx first3: ", tst[Take[xx, 3]], " | a first3: ", tst[Take[a, 3]],
   " | b first3: ", tst[Take[b, 3]]];
O1 = Outer[Times, a, b];
O2 = Outer[Minus, xx, xx];
njm[v_] := Count[Flatten[v], z_ /; !MachineNumberQ[z]];
sf["O1 junk elements (Count Flatten): ", tst[njm[O1]], " head=", tst[Head[O1[[1, 1]]]],
   " O1[[1,1]]=", tst[O1[[1, 1]]], " O1[[1,2]]=", tst[O1[[1, 2]]]];
sf["O2 junk elements (Count Flatten): ", tst[njm[O2]], " head=", tst[Head[O2[[1, 1]]]],
   " O2[[1,1]]=", tst[O2[[1, 1]]], " O2[[1,2]]=", tst[O2[[1, 2]]]];
S1 = O2 + IdentityMatrix[n];
sf["S1 junk: ", tst[njm[S1]], " S1[[1,1]]=", tst[S1[[1, 1]]], " S1[[1,2]]=", tst[S1[[1, 2]]]];
Q1 = O1/S1;
sf["Q1 junk: ", tst[njm[Q1]], " Q1[[1,2]]=", tst[Q1[[1, 2]]]];
sf["DONE-p9f"];
sfClose[];
Quit[];
