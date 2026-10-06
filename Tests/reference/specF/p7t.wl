(* why does rFD[257,800] time 0.018s while rFD[129,800] takes 0.324s?
   Same code path, work should scale linearly in n.  Time 3 reps each,
   alternating order, to separate warmup / scheduler / real cost. *)
$HistoryLength = 0;
Get[FileNameJoin[{Directory[], "helpers.wl"}]];
tst[e_] := ToString[N[e], InputForm];
xlo = -Pi; xhi = Pi; TT = 0.05;
icD[xx_] := Exp[-3 xx^2];
perg[nd_] := Table[N[xlo + j (xhi - xlo)/nd], {j, 0, nd - 1}];
lap[w_] := (RotateRight[w] - 2 w + RotateLeft[w]);
rFD[nd_, ns_] := Module[{h, uu, dt, k1, k2, k3, k4, i}, h = N[(xhi - xlo)/nd];
   uu = N[icD[perg[nd]]]; dt = N[TT/ns];
   Do[k1 = lap[uu]/h^2; k2 = lap[uu + dt k1/2]/h^2; k3 = lap[uu + dt k2/2]/h^2;
      k4 = lap[uu + dt k3]/h^2; uu = uu + dt (k1 + 2 k2 + 2 k3 + k4)/6, {i, ns}];
   uu];
sf["rFD timing probe (3 reps, warm rep marked)"];
Do[Module[{tm, uu},
    tm = AbsoluteTiming[rFD[nd, 800]];
    sf["  cold n=", tst[nd], " sec=", tst[tm[[1]]]];
    Do[tm = AbsoluteTiming[rFD[nd, 800]];
       sf["  warm n=", tst[nd], " sec=", tst[tm[[1]]]], {2}]],
    {nd, {257, 129, 257, 129}}];
(* also: is AbsoluteTiming itself the problem, or the value discarded? *)
Module[{tm, acc = {}},
   Do[tm = AbsoluteTiming[rFD[129, 800]]; AppendTo[acc, tm[[1]]], {3}];
   sf["  seq n=129 secs = ", tst[acc]]];
sfClose[];
Quit[];
