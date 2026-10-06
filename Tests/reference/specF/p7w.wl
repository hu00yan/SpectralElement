(* Where does the unpacking happen: perg (Table) or the Exp path?
   Binary-search the length threshold, then verify that forcing
   Developer`ToPackedArray in rFD restores the speed at n=129. *)
$HistoryLength = 0;
Get[FileNameJoin[{Directory[], "helpers.wl"}]];
tst[e_] := ToString[N[e], InputForm];
xlo = -Pi; xhi = Pi; TT = 0.05;
icD[xx_] := Exp[-3 xx^2];
perg[nd_] := Table[N[xlo + j (xhi - xlo)/nd], {j, 0, nd - 1}];
lap[w_] := (RotateRight[w] - 2 w + RotateLeft[w]);
sf["step-by-step packing status"];
Do[Module[{p = perg[len], q},
   q = Exp[-3 p^2];
   sf["  n=", tst[len],
      " perg: ", tst[Developer`PackedArrayQ[p]], " b=", tst[ByteCount[p]],
      " Exp: ", tst[Developer`PackedArrayQ[q]], " b=", tst[ByteCount[q]],
      " icD+N: ", tst[Developer`PackedArrayQ[N[icD[p]]]],
      " plain Table[N[j]]: ", tst[Developer`PackedArrayQ[Table[N[j], {j, 0, len - 1}]]]]],
  {len, {64, 129, 200, 240, 250, 255, 256}}];
sf["rFD with packed uu (same RK4 body, 800 steps)"];
Do[Module[{h, uu, dt, k1, k2, k3, k4, tm, i},
   h = N[(xhi - xlo)/nd]; dt = N[TT/800];
   tm = AbsoluteTiming[
      uu = Developer`ToPackedArray[N[icD[perg[nd]]]];
      Do[k1 = lap[uu]/h^2; k2 = lap[uu + dt k1/2]/h^2; k3 = lap[uu + dt k2/2]/h^2;
         k4 = lap[uu + dt k3]/h^2; uu = uu + dt (k1 + 2 k2 + 2 k3 + k4)/6, {i, 800}]];
   sf["  packed n=", tst[nd], " sec=", tst[tm[[1]]],
      " final packed=", tst[Developer`PackedArrayQ[uu]],
      " prec=", tst[Precision[uu[[1]]]]]],
  {nd, {65, 129, 257}}];
sfClose[];
Quit[];