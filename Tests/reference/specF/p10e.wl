(* p10e -- E2 honesty probe: Gibbs error of the single-patch global Chebyshev
   interpolation of chi_{[-1,0]}, EXCLUDING the node-snap artifact:
   a fine point t with 0<t<1e-13 snaps to node 0 -> interp = chi(0) = 1 while
   chi(t) = 0 -> |diff| = 1 exactly, at EVERY n (that is what p10's
   "maxErr=1." partly was).  Here: max over |t|>1e-6, plus fixed probe points,
   plus n=513, to see the true Gibbs magnitude. *)
$HistoryLength = 0;
Get[FileNameJoin[{Directory[], "helpers.wl"}]];
tst[e_] := StringTake[ToString[e, InputForm],
   Min[300, StringLength[ToString[e, InputForm]]]];
cgl[a_, b_, nn_] := Table[(a + b)/2 - (b - a)/2 Cos[k Pi/(nn - 1)], {k, 0, nn - 1}];
baryW[g_] := Module[{nn = Length[g]},
   Table[1./Product[If[k == j, 1., g[[j]] - g[[k]]], {k, nn}], {j, nn}]];
baryVec[g_, w_, t_] := Module[{nn = Length[g], wl, dd, hp, num},
   wl = w/Max[Abs[w]]; dd = t - g;
   hp = FirstPosition[Abs[dd], x_ /; x < 1.*^-13];
   If[hp =!= Missing["NotFound"],
    Return[ReplacePart[ConstantArray[0., nn], First[hp] -> 1.]]];
   num = wl/dd; num/Total[num]];
chi[x_] := If[x <= 0., 1., 0.];
fine = Range[-1., 1., 2./4000];
safe = Select[fine, Abs[#] > 1.*^-6 &];
probes = {-0.01, -0.001, 0.001, 0.01};
sf["p10e: fine=", Length[fine], " safe=", Length[safe]];
Do[
  g = cgl[-1., 1., nn]; w = baryW[g]; v = chi /@ g;
  eAll = Max[Abs[Table[baryVec[g, w, t] . v, {t, fine}] - chi /@ fine]];
  eSafe = Max[Abs[Table[baryVec[g, w, t] . v, {t, safe}] - chi /@ safe]];
  pv = Table[baryVec[g, w, t] . v - chi[t], {t, probes}];
  sf["n=", nn, " maxErrAll=", eAll, " maxErr(|t|>1e-6)=", eSafe,
     " probes {-0.01,-0.001,+0.001,+0.01} diff=", tst[pv]],
  {nn, {33, 65, 129, 257, 513}}];
sf["DONE-p10e"];
sfClose[];
Quit[];
