(* scratch probe 3: which messages does a LEGITIMATE AAA fit emit? *)
$HistoryLength = 0;
(* this file lives in Tests/probes/, so the repo root is three levels up *)
repo = DirectoryName[DirectoryName[DirectoryName[$InputFileName]]];
sfLog = FileNameJoin[{repo, "Tests", "out", "gp3.txt"}];
st = OpenWrite[sfLog];
sfSafe[e_] := Module[{s = ToString[e, InputForm]}, If[StringLength[s] > 300, StringTake[s, 300] <> "..TRUNC", s]];
sf[args___] := (WriteString[st, StringJoin[sfSafe /@ {args}] <> "\n"]; Flush[st]; Print[args]);

Get[FileNameJoin[{repo, "Kernel", "SpectralElement.wl"}]];
$ContextPath = Join[{"SpectralElement`", "SpectralElement`Private`", "System`"}, $ContextPath];

bot = Function[{t}, {t, -1 - 0.30 Sin[Pi (1 - t)/2]}];
ts = N[Subdivide[-1., 1., 65], MachinePrecision];
fs = N[Table[N[bot[t][[2]], 16], {t, ts}], MachinePrecision];

n0 = Length[$MessageList];
fit = aaazfit[ts, fs];
new = Drop[$MessageList, n0];
sf["messages emitted by a legitimate aaazfit: ", Length[new]];
sf[sfSafe[new]];

n1 = Length[$MessageList];
r = Quiet[Check[aaazfit[ts, fs], "TAG"]];
sf["Check[aaazfit] returns: ", sfSafe[r]];

n2 = Length[$MessageList];
geo = Quiet[Check[CPsin = Function[{t}, {t, -1 - 0.30 Sin[Pi (1 - t)/2]}], "T2"]];
pB = Quiet[Check[SpectralElement`CoonsPatch[{bot, Function[{t}, {t, 1}], Function[{t}, {-1, t}], Function[{t}, {1, t}]}, Method -> "AAA"], "T3"]];
sf["CoonsPatch AAA on sinusoid bottom returned: ", sfSafe[pB]];
sf["new messages: ", sfSafe[Drop[$MessageList, n2]]];

n3 = Length[$MessageList];
r3 = Quiet[Check[seAAAFitEdge[bot, ts], "T4"]];
sf["seAAAFitEdge: ", sfSafe[r3]];
sf["new messages: ", sfSafe[Drop[$MessageList, n3]]];

n4 = Length[$MessageList];
r4 = Quiet[Check[seAAAFitCoord[bot, ts, 2], "T5"]];
sf["seAAAFitCoord: ", sfSafe[If[TrueQ[AssociationQ[r4]], r4[["Status"]], r4]]];
sf["new messages: ", sfSafe[Drop[$MessageList, n4]]];

sf["P3 OK"];
Close[st];
Quit[];