(* scratch probe 4: message-capture semantics + what the AAA branch really returns *)
$HistoryLength = 0;
sfLog = FileNameJoin[{"/path/to/SpectralElement", "Tests", "out", "gp4.txt"}];
st = OpenWrite[sfLog];
sfSafe[e_] := Module[{s = ToString[e, InputForm]}, If[StringLength[s] > 300, StringTake[s, 300] <> "..TRUNC", s]];
sf[args___] := (WriteString[st, StringJoin[sfSafe /@ {args}] <> "\n"]; Flush[st]; Print[args]);
cnt[ml_List] := DeleteDuplicates[Map[SymbolName[#1] &, ml]];

sf["P4 start: len($MessageList)=", Length[$MessageList]];
sf["names: ", sfSafe[cnt[$MessageList]]];

(* does Quiet clear $MessageList? *)
msgTest[] := Message[SpectralElement`CoonsPatch::method, "probe", "reason"];
nq = Length[$MessageList];
msgTest[];
sf["after plain Message: +", Length[$MessageList] - nq];
nq = Length[$MessageList];
Quiet[msgTest[]];
sf["after Quiet[Message]: +", Length[$MessageList] - nq];
nq = Length[$MessageList];
Quiet[msgTest[]];
sf["after Quiet[Message] again: +", Length[$MessageList] - nq];
nq = Length[$MessageList];
Quiet[Check[msgTest[], $Failed]];
sf["after Quiet[Check[Message]]: +", Length[$MessageList] - nq, "  (check fired=", $Failed === $Failed, ")"];

$MessageList = {};
sf["after clearing: len=", Length[$MessageList]];

repo = "/path/to/SpectralElement";
Get[FileNameJoin[{repo, "Kernel", "SpectralElement.wl"}]];
sf["after Get loader: len=", Length[$MessageList], " names=", sfSafe[cnt[$MessageList]]];
$ContextPath = Join[{"SpectralElement`", "SpectralElement`Private`", "System`"}, $ContextPath];
CP = SpectralElement`CoonsPatch;

bot = Function[{t}, {t, -1 - 0.30 Sin[Pi (1 - t)/2]}];
top = Function[{t}, {t, 1 + 0.20 Sin[Pi (1 + t)/2]}];
lef = Function[{t}, {-1 - 0.25 Sin[Pi (1 + t)/2], t}];
rig = Function[{t}, {1 + 0.35 Sin[Pi (1 - t)/2], t}];
ed = {bot, top, lef, rig};

(* direct private call, no wrapper *)
n0 = Length[$MessageList];
r = seAAAFitEdges[ed, seAAASampleGrid[65]];
sf["seAAAFitEdges: Length[r]=", Length[r]];
sf["  r1 = ", sfSafe[r[[1]]]];
sf["  Head[r2] = ", Head[r[[2]]], "  Length[r2] = ", Length[r[[2]]]];
sf["  Length[r3] = ", Length[r[[3]]]];
sf["  r3 first = ", sfSafe[If[Length[r[[3]]]] >= 1, r[[3]][[1]]["X"]["Type"], "EMPTY"]];
sf["  new msgs=", Length[$MessageList] - n0, " names=", sfSafe[cnt[Drop[$MessageList, n0]]]];

$MessageList = {};
n0 = Length[$MessageList];
pB = CP[ed, Method -> "AAA"];
sf["CP[ed, Method->AAA] head=", Head[pB], " === $Failed: ", pB === $Failed];
sf["  new msgs=", Length[$MessageList] - n0, " names=", sfSafe[cnt[Drop[$MessageList, n0]]]];

$MessageList = {};
n0 = Length[$MessageList];
bad = {Function[t, {t, foo[t]}], top, lef, rig};
r2 = seAAAFitEdges[bad, seAAASampleGrid[65]];
sf["seAAAFitEdges(bad): r1=", sfSafe[r2[[1]]], " r2=", sfSafe[r2[[2]]]];
pC = CP[bad, Method -> "AAA"];
sf["CP[bad, AAA] === $Failed: ", pC === $Failed, "  new msgs=", Length[$MessageList] - n0,
   " names=", sfSafe[cnt[Drop[$MessageList, n0]]]];

$MessageList = {};
n0 = Length[$MessageList];
badZ = {Function[t, {0., 0.}], top, lef, rig};
r3 = seAAAFitEdges[badZ, seAAASampleGrid[65]];
sf["seAAAFitEdges(zero): r1=", sfSafe[r3[[1]]], " r2=", sfSafe[r3[[2]]]];
pE = CP[badZ, Method -> "AAA"];
sf["CP[zero, AAA] === $Failed: ", pE === $Failed, "  new msgs=", Length[$MessageList] - n0,
   " names=", sfSafe[cnt[Drop[$MessageList, n0]]]];

(* corner closure of the FIT edges, measured directly *)
e1 = seAAAFitEdge[bot, seAAASampleGrid[65]];
e3 = seAAAFitEdge[lef, seAAASampleGrid[65]];
sf["bot fit corner values: ", sfSafe[e1[[2]][-1]], " ", sfSafe[e1[[2]][1]]];
sf["lef fit corner values: ", sfSafe[e3[[2]][-1]], " ", sfSafe[e3[[2]][1]]];
sf["analytic bot[-1]=", sfSafe[bot[-1]], " bot[1]=", sfSafe[bot[1]],
   " lef[-1]=", sfSafe[lef[-1]], " lef[1]=", sfSafe[lef[1]]];

$MessageList = {};
n0 = Length[$MessageList];
pD = CP[ed];
sf["CP[ed] Q=", SpectralElement`CoonsPatchQ[pD], " closure=", pD[["CornerClosure"]], "  new msgs=", Length[$MessageList] - n0];

(* direct probe of the sampling step *)
tsX = seAAASampleGrid[65];
sf["tsX head=", Head[tsX], " Length=", Length[tsX]];
fsX = N[Table[N[bot[t][[1]], 16], {t, tsX}], MachinePrecision];
sf["fsX head=", Head[fsX], " Length=", Length[fsX], " finiteQ=", seAAAFiniteVecQ[fsX],
   " first=", sfSafe[fsX[[1]]], " last=", sfSafe[fsX[[-1]]]];
tagY = Quiet[Check[N[Table[N[bot[t][[1]], 16], {t, tsX}], MachinePrecision], "TAG", seAAAFatalMsgs]];
sf["Check sample head=", Head[tagY], " Length=", Length[tagY], " val=", sfSafe[If[TrueQ[VectorQ[tagY, NumericQ]], "NUMERIC", tagY]]];
sf["seAAAFatalMsgs = ", sfSafe[seAAAFatalMsgs], " head=", Head[seAAAFatalMsgs], " len=", Length[seAAAFatalMsgs]];
cA = Quiet[Check[Message[IterationLimit::itlim], "TA", {IterationLimit::itlim}]];
cB = Quiet[Check[Message[IterationLimit::itlim], "TB", seAAAFatalMsgs]];
cC = Quiet[Check[Message[IterationLimit::itlim], "TC"]];
cD = Quiet[Check[Message[IterationLimit::itlim], "TD", {MessageName[IterationLimit, "itlim"]}]];
sf["cA=", sfSafe[cA], " cB=", sfSafe[cB], " cC=", sfSafe[cC], " cD=", sfSafe[cD]];
cX = seAAAFitCoord[bot, tsX, 1];
sf["seAAAFitCoord cX1=", sfSafe[cX[[1]]], " cX2=", sfSafe[If[TrueQ[cX[[1]] === "OK"], "<fit assoc>", cX[[2]]]]];

(* Module-local capture vs pattern capture of a fitted edge *)
pkX = seAAAFitCoord[bot, tsX, 1];
pkY = seAAAFitCoord[bot, tsX, 2];
aa = pkX[[2]];
bb = pkY[[2]];
sf["fitX status=", aa[["Status"]], " type=", sfSafe[aa[["Type"]]], " relerr=", sfSafe[aa[["RelError"]]]];
sf["fitY status=", bb[["Status"]], " type=", sfSafe[bb[["Type"]]], " relerr=", sfSafe[bb[["RelError"]]]];
gv = Quiet[aaaeval[aa, tsX]];
sf["fitX eval on grid: finiteQ=", seAAAFiniteVecQ[gv], " first=", sfSafe[gv[[1]]], " last=", sfSafe[gv[[-1]]]];
gw = Quiet[aaaeval[bb, tsX]];
sf["fitY eval on grid: finiteQ=", seAAAFiniteVecQ[gw], " first=", sfSafe[gw[[1]]], " last=", sfSafe[gw[[-1]]]];
fnP = seAAAFitFn[aa, bb];
sf["seAAAFitFn[0.3]=", sfSafe[fnP[0.3]], " fnP[-1]=", sfSafe[fnP[-1]], " fnP[1]=", sfSafe[fnP[1]]];
fnM = Module[{u = aa, v = bb}, Function[{tt}, {aaaeval[u, tt], aaaeval[v, tt]}]];
sf["Module-captured [0.3]=", sfSafe[Quiet[fnM[0.3]]], " [-1]=", sfSafe[Quiet[fnM[-1]]]];
eOK = seAAAFitEdge[bot, tsX];
sf["seAAAFitEdge[bot]: tag=", If[TrueQ[eOK[[1]] === "Fail"], "TAG-FAIL", "TAG-OK"], " value=", sfSafe[If[TrueQ[eOK[[1]] === "OK"], eOK[[2]][0.3], eOK[[2]]]]];
rE = seAAAFitEdges[ed, tsX];
sf["seAAAFitEdges: tag=", If[TrueQ[rE[[1]] === "Fail"], "TAG-FAIL", "TAG-OK"], " nEdges=", Length[rE[[2]]]];
sf["   edge1[0.3]=", sfSafe[If[TrueQ[rE[[1]] === "OK"], rE[[2]][[1]][0.3], "n/a"]],
   " edge1[-1]=", sfSafe[If[TrueQ[rE[[1]] === "OK"], rE[[2]][[1]][-1], "n/a"]]];
pB2 = CP[ed, Method -> "AAA"];
sf["CP[ed,AAA] Q=", CPQ[pB2], " method=", pB2[["Method"]], " closure=", pB2[["CornerClosure"]],
   " mincross=", pB2[["CornerConsistency"]]["MinTangentCross"]];

sf["P4 OK"];
Close[st];
Quit[];