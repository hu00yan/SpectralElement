(* scratch probe 5: WHERE is the fitted edge non-finite? *)
$HistoryLength = 0;
(* this file lives in Tests/probes/, so the repo root is three levels up *)
repo = DirectoryName[DirectoryName[DirectoryName[$InputFileName]]];
sfLog = FileNameJoin[{repo, "Tests", "out", "gp5.txt"}];
st = OpenWrite[sfLog];
sfSafe[e_] := Module[{s = ToString[e, InputForm]}, If[StringLength[s] > 260, StringTake[s, 260] <> "..TRUNC", s]];
sf[args___] := (WriteString[st, StringJoin[sfSafe /@ {args}] <> "\n"]; Flush[st]; Print[args]);
fin[q_] := AllTrue[q, (TrueQ[NumericQ[#]] && Abs[#] < Infinity) &];
emx[v_] := If[TrueQ[VectorQ[v, NumericQ]], N[Max[Abs[v]]], -1.];
nfidx[pg_, pv_] := Select[Range[Length[pg]], Not[TrueQ[fin[pv[[#]]]]] &];

Get[FileNameJoin[{repo, "Kernel", "SpectralElement.wl"}]];
$ContextPath = Join[{"SpectralElement`", "SpectralElement`Private`", "System`"}, $ContextPath];
CP = SpectralElement`CoonsPatch;
CPQ = SpectralElement`CoonsPatchQ;

bot = Function[{t}, {t, -1 - 0.30 Sin[Pi (1 - t)/2]}];
ts = seAAASampleGrid[65];
sf["ts len=", Length[ts], " lo=", sfSafe[ts[[1]]], " hi=", sfSafe[ts[[-1]]]];
pg = seAAAProbeGrid[];
sf["pg len=", Length[pg], " lo=", sfSafe[pg[[1]]], " hi=", sfSafe[pg[[-1]]]];

ka = seAAAFitCoord[bot, ts, 1];
kb = seAAAFitCoord[bot, ts, 2];
aa = ka[[2]];
bb = kb[[2]];
sf["fitX tag=", ka[[1]], " type=", sfSafe[aa[["Type"]]], " relerr=", sfSafe[aa[["RelError"]]], " nodes=", sfSafe[aa[["Nodes"]]]];
sf["fitY tag=", kb[[1]], " type=", sfSafe[bb[["Type"]]], " relerr=", sfSafe[bb[["RelError"]]], " nodes=", sfSafe[bb[["Nodes"]]]];

fnP = seAAAFitFn[aa, bb];
pv = Quiet[Check[N[Table[fnP[z], {z, pg}], MachinePrecision], "TAG5", {IterationLimit::itlim}]];
sf["probe head=", Head[pv], " len=", Length[pv], " finiteQ=", seAAAFiniteVecQ[Flatten[pv]]];
nf = nfidx[pg, pv];
sf["non-finite probe idx count=", Length[nf], " first idx=", sfSafe[Take[nf, UpTo[6]]]];
sf["  max |value| over probe=", sfSafe[Max[Abs[Flatten[pv]]]]];

pvx = Quiet[aaaeval[aa, pg]];
pvy = Quiet[aaaeval[bb, pg]];
sf["X finite=", fin[pvx], " Y finite=", fin[pvy]];
sf["X max=", sfSafe[Max[Abs[pvx]]], " Y max=", sfSafe[Max[Abs[pvy]]]];
nfx = nfidx[pg, pvx];
nfy = nfidx[pg, pvy];
sf["X bad idx=", sfSafe[Take[nfx, UpTo[6]]]];
zX = {};
vX = {};
If[Length[nfx] > 0, zX = pg[[Take[nfx, UpTo[3]]]]; vX = pvx[[Take[nfx, UpTo[3]]]]];
sf["  X z=", sfSafe[zX], " X v=", sfSafe[vX]];
sf["Y bad idx=", sfSafe[Take[nfy, UpTo[6]]]];
zY = {};
vY = {};
If[Length[nfy] > 0, zY = pg[[Take[nfy, UpTo[3]]]]; vY = pvy[[Take[nfy, UpTo[3]]]]];
sf["  Y z=", sfSafe[zY], " Y v=", sfSafe[vY]];

dens = N[Subdivide[-1., 1., 999], 12];
ax = Quiet[aaaeval[aa, dens]];
ay = Quiet[aaaeval[bb, dens]];
ex = N[Table[N[bot[t][[1]], 16], {t, dens}]];
ey = N[Table[N[bot[t][[2]], 16], {t, dens}]];
sf["off-sample max |fitX - exact|=", emx[ax - ex], " max |fitY - exact|=", emx[ay - ey]];
sf["endpoint fit(-1)=", sfSafe[fnP[-1]], " exact=", sfSafe[bot[-1]]];
sf["endpoint fit(1)=", sfSafe[fnP[1]], " exact=", sfSafe[bot[1]]];

eOK = seAAAFitEdge[bot, ts];
eOKtag = If[TrueQ[eOK[[1]] === "Fail"], "TAG-FAIL", "TAG-OK"];
eOKval = If[TrueQ[eOK[[1]] === "OK"], eOK[[2]][0.3], eOK[[2]]];
sf["seAAAFitEdge tag=", eOKtag, " value=", sfSafe[eOKval]];
rE = seAAAFitEdges[{bot, bot, bot, bot}, ts];
rEtag = If[TrueQ[rE[[1]] === "Fail"], "TAG-FAIL", "TAG-OK"];
dT = seAAAFitDecide[rawT];
sf["seAAAFitDecide at top level: tag=", If[TrueQ[dT[[1]] === "Fail"], "TAG-FAIL", "TAG-OK"], " n=", Length[dT[[2]]]];
shad = Select[Names["SpectralElement`Private`*"], StringMatchQ[#, "Table|Do|Select|Append|Part|Length|raw|bad|ix"] &];
sf["shadowing names: ", sfSafe[shad]];
rawT = Table[seAAAFitEdge[bot, ts], {k, 1, 4}];
sf["rawT len=", Length[rawT], " rowHeads=", sfSafe[Heads /@ rawT]];
sf["rawT all2 len=", Length[rawT[[All, 2]]], " all3 len=", Length[rawT[[All, 3]]]];
sf["rawT row1 len=", Length[rawT[[1]]], " row1 head=", sfSafe[Head[rawT[[1]]]]];
shad = Select[Names["SpectralElement`Private`*"], StringMatchQ[#, "Table|Do|Select|Append|Part|Length"]].
sf["shadowing names: ", sfSafe[shad]];
sf["seAAAFitEdges tag=", rEtag, " n=", Length[rE[[2]]]];
sq = {Function[{t}, {t, 1}], Function[{t}, {-1, t}], Function[{t}, {1, t}]};
pB2 = Quiet[Check[CP[Join[{bot}, sq], Method -> "AAA"], $Failed]];
isA = AssociationQ[pB2];
mB2 = If[TrueQ[isA], pB2[["Method"]], "REJECTED"];
cB2 = If[TrueQ[isA], pB2[["CornerClosure"]], "n/a"];
sf["CP AAA Q=", CPQ[pB2], " method=", mB2, " closure=", cB2];

sf["P5 OK"];
Close[st];
Quit[];