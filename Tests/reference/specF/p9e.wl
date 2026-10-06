(* p9e -- step through bigD2v at n=65 and count non-machine entries after
   EACH assignment, to localize where the unevaluated Plus/Times junk
   (seen by p9d inside dd) is born. *)
$HistoryLength = 0;
Get[FileNameJoin[{Directory[], "helpers.wl"}]];
tst[e_] := StringTake[ToString[e, InputForm], Min[220, StringLength[ToString[e, InputForm]]]];
n = 65;
xx = N[-Cos[Range[0, n - 1] Pi/(n - 1)]];
cc = Map[If[# == 1 || # == n, 2., 1.] &, Range[n]];
sg = (-1.)^Range[n];
a = sg cc;
b = sg/cc;
nj[v_] := Length[Position[v, x_ /; !MachineNumberQ[x], {2}]];
firstj[v_] := Module[{p = Position[v, x_ /; !MachineNumberQ[x], {2}]},
   If[Length[p] > 0, Extract[v, First[p]], "none"]];
sf["xx: head=", tst[Head[xx]], " nj=", tst[nj[xx]], " first=", tst[firstj[xx]]];
sf["cc: head=", tst[Head[cc]], " nj=", tst[nj[cc]], " first=", tst[firstj[cc]]];
sf["sg: head=", tst[Head[sg]], " nj=", tst[nj[sg]], " first=", tst[firstj[sg]]];
sf["a:  head=", tst[Head[a]], " nj=", tst[nj[a]], " first=", tst[firstj[a]]];
sf["b:  head=", tst[Head[b]], " nj=", tst[nj[b]], " first=", tst[firstj[b]]];
O1 = Outer[Times, a, b];
sf["O1=Outer[Times,a,b]: head=", tst[Head[O1]], " dims=", tst[Dimensions[O1]],
   " nj=", tst[nj[O1]], " first=", tst[firstj[O1]]];
O2 = Outer[Minus, xx, xx];
sf["O2=Outer[Minus,xx,xx]: head=", tst[Head[O2]], " dims=", tst[Dimensions[O2]],
   " nj=", tst[nj[O2]], " first=", tst[firstj[O2]]];
I0 = IdentityMatrix[n];
sf["IdentityMatrix: head=", tst[Head[I0]], " dims=", tst[Dimensions[I0]],
   " packed=", tst[Developer`PackedArrayQ[I0]],
   " elemHead=", tst[Head[I0[[1, 1]]]]];
S1 = O2 + I0;
sf["S1=O2+I0: head=", tst[Head[S1]], " nj=", tst[nj[S1]], " first=", tst[firstj[S1]]];
Q1 = O1/S1;
sf["Q1=O1/S1: head=", tst[Head[Q1]], " nj=", tst[nj[Q1]], " first=", tst[firstj[Q1]]];
D1 = Q1 - I0;
sf["D1=Q1-I0: head=", tst[Head[D1]], " nj=", tst[nj[D1]], " first=", tst[firstj[D1]]];
ii = -Map[Total, D1];
sf["ii: head=", tst[Head[ii]], " nj=", tst[nj[ii]], " first=", tst[firstj[ii]]];
D2 = D1 + DiagonalMatrix[ii];
sf["D2=D1+Diag[ii]: head=", tst[Head[D2]], " nj=", tst[nj[D2]], " first=", tst[firstj[D2]]];
D3 = D2.D2;
sf["D3=D2.D2: head=", tst[Head[D3]], " dims=", tst[Dimensions[D3]],
   " nj=", tst[nj[D3]], " first=", tst[firstj[D3]]];
sf["DONE-p9e"];
sfClose[];
Quit[];
