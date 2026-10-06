(* lap alone is 20x slower at n=129 than n=257 (50000 reps: 1.82s vs
   0.187s).  Find where the cost flips over length, with the CORRECT
   symbol Developer`PackedArrayQ, plus a random-array control to separate
   size-threshold from value/structure dependence. *)
$HistoryLength = 0;
Get[FileNameJoin[{Directory[], "helpers.wl"}]];
tst[e_] := ToString[N[e], InputForm];
xlo = -Pi; xhi = Pi;
icD[xx_] := Exp[-3 xx^2];
perg[nd_] := Table[N[xlo + j (xhi - xlo)/nd], {j, 0, nd - 1}];
lap[w_] := (RotateRight[w] - 2 w + RotateLeft[w]);
sf["gaussian-array sweep: packed? bytes? lap x20000"];
Do[Module[{w, tm},
   w = N[icD[perg[len]]];
   tm = AbsoluteTiming[Do[lap[w], {20000}]];
   sf["  gauss n=", tst[len], " packed=", tst[Developer`PackedArrayQ[w]],
      " bytes=", tst[ByteCount[w]], " lap x20000 sec=", tst[tm[[1]]]]],
  {len, {17, 65, 128, 129, 130, 160, 200, 256, 257, 300}}];
sf["random control"];
Do[Module[{w, tm},
   w = RandomReal[1., len];
   tm = AbsoluteTiming[Do[lap[w], {20000}]];
   sf["  rand n=", tst[len], " packed=", tst[Developer`PackedArrayQ[w]],
      " bytes=", tst[ByteCount[w]], " lap x20000 sec=", tst[tm[[1]]]]],
  {len, {129, 257}}];
sfClose[];
Quit[];
