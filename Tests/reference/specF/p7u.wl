(* rFD[129,800] takes 0.31s but rFD[257,800] only 0.017s -- deterministic,
   18x.  Hypotheses: (a) 129-path arrays unpacked or promoted to arbitrary
   precision, (b) one specific subexpression is slow.  Probe packing,
   precision and isolated timings per nd. *)
$HistoryLength = 0;
Get[FileNameJoin[{Directory[], "helpers.wl"}]];
tst[e_] := ToString[N[e], InputForm];
xlo = -Pi; xhi = Pi; TT = 0.05;
icD[xx_] := Exp[-3 xx^2];
perg[nd_] := Table[N[xlo + j (xhi - xlo)/nd], {j, 0, nd - 1}];
lap[w_] := (RotateRight[w] - 2 w + RotateLeft[w]);
sf["isolate probe"];
Do[Module[{uu, h, dt, k1, tm, pk0, pk1, pr0, pr1, n},
   n = Length[perg[nd]];
   uu = N[icD[perg[nd]]];
   h = N[(xhi - xlo)/nd]; dt = N[TT/800];
   pk0 = PackedArrayQ[uu]; pr0 = Precision[uu[[1]]];
   tm = AbsoluteTiming[Do[k1 = lap[uu]/h^2; uu = uu + dt k1/6, {800}]];
   pk1 = PackedArrayQ[k1]; pr1 = Precision[k1[[1]]];
   sf["n=", tst[n], " packed(uu)=", tst[pk0], " prec(uu)=", tst[pr0],
      " packed(k1)=", tst[pk1], " prec(k1)=", tst[pr1],
      " simple-step 800x sec=", tst[tm[[1]]]];
   uu = N[icD[perg[nd]]];
   tm = AbsoluteTiming[Do[k1 = lap[uu]/h^2; k2 = lap[uu + dt k1/2]/h^2;
      k3 = lap[uu + dt k2/2]/h^2; k4 = lap[uu + dt k3]/h^2;
      uu = uu + dt (k1 + 2 k2 + 2 k3 + k4)/6, {800}]];
   sf["   full RK4 800x sec=", tst[tm[[1]]],
      " packed(final)=", tst[PackedArrayQ[uu]], " prec(final)=", tst[Precision[uu[[1]]]]]],
  {nd, {65, 129, 257}}];
(* raw lap cost, no division *)
Do[Module[{uu, tm},
   uu = N[icD[perg[nd]]];
   tm = AbsoluteTiming[Do[lap[uu], {50000}]];
   sf["lap x50000 n=", tst[Length[uu]], " sec=", tst[tm[[1]]],
      " packed=", tst[PackedArrayQ[uu]]]],
  {nd, {129, 257}}];
sfClose[];
Quit[];
