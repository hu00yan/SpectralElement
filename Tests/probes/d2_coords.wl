(* ==================================================================== *)
(* Tests/probes/d2_coords.wl -- GATE for the "Coordinates" data key.    *)
(* Owner: agent D, round 4.                                           *)
(*                                                                   *)
(* DEFECT: the "Coordinates" branch of SpectralDomainData took a pure  *)
(* function with NO parameter -- `(Table[{N[o[[p]]["Xs"][[ix, iy]]],  *)
(* ...}, {ix, 1, nn}, {iy, 1, nn}] &) /@ Range[disc["PatchCount"]]`    *)
(* -- so the mapped value was discarded, `p` stayed unbound, and the   *)
(* fetch returned $Failed after 12 messages (agent E's key-by-key audit:*)
(* Tests/out/e_probe5.115628_60497.txt, KEY "Coordinates" head=Symbol  *)
(* nmsgs=12; every other key nmsgs=0).                                *)
(*                                                                   *)
(* This probe re-runs E's audit shape -- head, dims and the number of *)
(* messages raised DURING the fetch -- on a 1-patch and a 2-patch     *)
(* domain, and adds the check the audit could not make: that the pairs *)
(* agree with the "X" and "Y" keys entry by entry.                     *)
(*                                                                   *)
(* Run: ./rr.sh 300 Tests/probes/d2_coords.wl                         *)
(* ==================================================================== *)
$HistoryLength = 0;
sfLog = If[StringQ[Environment["SPECF_OUT"]], Environment["SPECF_OUT"], FileNameJoin[{DirectoryName[$InputFileName], "out", "d2_coords.nofallback.txt"}]];
sfStream = OpenWrite[sfLog];
sfSafe[e_] := If[StringQ[e], e, Module[{s = ToString[e, InputForm]}, If[StringLength[s] > 300, StringTake[s, 300] <> "..TRUNC", s]]];
sf[args___] := Module[{s = StringJoin[sfSafe /@ {args}]}, WriteString[sfStream, s <> "\n"]; Flush[sfStream]; Print[s]];
sfClose[] := Module[{Close[sfStream]}];
$pass = 0; $fail = 0; $failNames = {};
gate[name_, value_, target_, op_String] := Module[{v = value, ok = False}, ok = Switch[op, "<=", TrueQ[NumericQ[v] && N[v] <= N[target]], "==", TrueQ[v === target], True, False]; If[! TrueQ[ok], AppendTo[$failNames, name]; $fail++, $pass++]; sf["  ", If[! TrueQ[ok], "FAIL", "PASS"], "  ", name, " = ", sfSafe[v]]; ok];

(* this file lives in Tests/probes/, so the repo root is three levels up *)
repo = DirectoryName[DirectoryName[DirectoryName[$InputFileName]]];
Get[FileNameJoin[{repo, "Kernel", "SpectralElement.wl"}]];

(* one audit line in E's exact shape: head, dims, messages raised by the fetch *)
auditKey[disc_, k_] := Module[{m0 = Length[$MessageList], v = SpectralElement`SpectralDomainData[disc, k], nm}, nm = Length[$MessageList[[m0 + 1 ;; Length[$MessageList]]]]; sf["KEY """, k, """  head=", Head[v], "  dims=", Dimensions[v], "  nmsgs=", nm]; <|"Value" -> v, "Head" -> Head[v], "Dims" -> Dimensions[v], "Nmsgs" -> nm|>];

(* the entry-by-entry agreement with X and Y: Coordinates[[p]][[ix, iy]] is
   {X[[p]][[ix, iy]], Y[[p]][[ix, iy]]} at the SAME (ix, iy) the X and Y
   matrices use, so the reference is rebuilt patch by patch -- comparing the
   whole {np, nn, nn, 2} object against a single-patch reference silently
   degenerates into "coords minus a too-short list" and returns the coords
   unchanged.  dmax is that direct identity; tmax is the same statement with
   both sides transposed, i.e. Transpose[{X, Y}] with the two index axes
   swapped, which is the orientation the data actually has. *)
pairAgree[coords_, xs_, ys_, nn_, np_] := Module[{ref, dmax = 0., tmax = 0., p, ix, iy}, Do[ref = Table[{N[xs[[p, ix, iy]]], N[ys[[p, ix, iy]]]}, {ix, 1, nn}, {iy, 1, nn}]; dmax = Max[dmax, Max[Abs[Flatten[coords[[p]]] - Flatten[ref]]]]; tmax = Max[tmax, Max[Abs[Flatten[Transpose[coords[[p]]] - Transpose[ref]]]]], {p, 1, np}]; {dmax, tmax}];

sf["=== A. 1-patch Rectangle[{-1.5,-1.2},{1.8,1.3}], degree 8 (E's domain) ==="];
discR = Quiet[SpectralElement`SpectralDomain[Rectangle[{-1.5, -1.2}, {1.8, 1.3}], 8]];
sf["  PatchCount=", SpectralElement`SpectralDomainData[discR, "PatchCount"], "  NodeCount(per direction)=", SpectralElement`SpectralDomainData[discR, "NodeCount"]];
aC = auditKey[discR, "Coordinates"];
aX = auditKey[discR, "X"];
aY = auditKey[discR, "Y"];
agR = pairAgree[aC["Value"], aX["Value"], aY["Value"], 9, 1];
sf["  first pair [[1,1,1]] = ", N[aC["Value"][[1, 1, 1]]], "   X[[1,1,1]]=", N[aX["Value"][[1, 1, 1]]], "  Y[[1,1,1]]=", N[aY["Value"][[1, 1, 1]]]];
sf["  corner pair [[1,1,nn]] = ", N[aC["Value"][[1, 1, 9]]], "   X[[1,1,9]]=", N[aX["Value"][[1, 1, 9]]], "  Y[[1,1,9]]=", N[aY["Value"][[1, 1, 9]]]];
sf["  every entry numeric                     = ", VectorQ[Flatten[Flatten[aC["Value"]]], NumericQ]];
sf["  max|Coordinates - {X,Y} built from X,Y    = ", N[agR[[1]]], "   (exact match to machine precision)"];
sf["  the same thing via Transpose: max|Transpose[C] - Transpose[{X,Y}]| = ", N[agR[[2]]]];
gate["A1 Coordinates head is List", aC["Head"], List, "=="];
gate["A2 Coordinates dims are {1, 9, 9, 2} (the trailing 2 is the pair)", aC["Dims"], {1, 9, 9, 2}, "=="];
gate["A3 the fetch raised ZERO messages", aC["Nmsgs"], 0, "=="];
gate["A4 every coordinate is a number", VectorQ[Flatten[Flatten[aC["Value"]]], NumericQ], True, "=="];
gate["A5 Coordinates agrees with X and Y to machine precision", agR[[1]], 1.*^-14, "<="];
gate["A6 and so does the Transpose form", agR[[2]], 1.*^-14, "<="];
gate["A7 X and Y are still {1, 9, 9} with no messages", aX["Dims"], {1, 9, 9}, "=="];

sf["=== B. 2-patch Annulus[{1,2},{0,2 Pi}], degree 6 ==="];
discA = Quiet[SpectralElement`SpectralDomain[Annulus[{1, 2}, {0, 2 Pi}], 6]];
sf["  PatchCount=", SpectralElement`SpectralDomainData[discA, "PatchCount"], "  NodeCount(per direction)=", SpectralElement`SpectralDomainData[discA, "NodeCount"]];
bC = auditKey[discA, "Coordinates"];
bX = auditKey[discA, "X"];
bY = auditKey[discA, "Y"];
agA = pairAgree[bC["Value"], bX["Value"], bY["Value"], 7, 2];
sf["  every entry numeric                     = ", VectorQ[Flatten[Flatten[bC["Value"]]], NumericQ]];
sf["  max|Coordinates - {X,Y} built from X,Y    = ", N[agA[[1]]]];
sf["  the same thing via Transpose: max|Transpose[C] - Transpose[{X,Y}]| = ", N[agA[[2]]]];
sf["  patch 1 first pair = ", N[bC["Value"][[1, 1, 1]]], "   patch 2 first pair = ", N[bC["Value"][[2, 1, 1]]]];
sf["  the two patches are genuinely different = ", bC["Value"][[1, 1, 1]] =!= bC["Value"][[2, 1, 1]]];
gate["B1 Coordinates head is List", bC["Head"], List, "=="];
gate["B2 Coordinates dims are {2, 7, 7, 2} (the trailing 2 is the pair)", bC["Dims"], {2, 7, 7, 2}, "=="];
gate["B3 the fetch raised ZERO messages", bC["Nmsgs"], 0, "=="];
gate["B4 every coordinate is a number", VectorQ[Flatten[Flatten[bC["Value"]]], NumericQ], True, "=="];
gate["B5 Coordinates agrees with X and Y to machine precision", agA[[1]], 1.*^-14, "<="];
gate["B6 and so does the Transpose form", agA[[2]], 0., "=="];
gate["B7 outer length equals PatchCount", Length[bC["Value"]], 2, "=="];

sf["=== C. the key is still a key, and an unknown key still complains ==="];
inKeyList = MemberQ[SpectralElement`Private`seDataKeys, "Coordinates"];
served = Not[TrueQ[aC["Value"] === $Failed]];
sf["  ""Coordinates"" is in the package key list seDataKeys: ", inKeyList, "   (Keys[disc] does NOT list it: the key is served by the Switch, not stored)"];
sf["  and the fetch answers with data rather than $Failed: ", served];
m1 = Length[$MessageList];
badKey = SpectralElement`SpectralDomainData[discR, "NoSuchKey"];
sf["  an unknown key -> ", badKey, " with ", Length[$MessageList[[m1 + 1 ;; Length[$MessageList]]]], " message(s)"];
gate["C1 Coordinates is in the package key list", inKeyList, True, "=="];
gate["C1b the Coordinates fetch answers with data", served, True, "=="];
gate["C2 an unknown key is still refused with a message", Length[$MessageList[[m1 + 1 ;; Length[$MessageList]]]], 1, "=="];

sf["================ D2 R4 Coordinates PROBE ================"];
sf["runner: ./rr.sh 300 Tests/probes/d2_coords.wl"];
sf["1-patch: head=", aC["Head"], " dims=", aC["Dims"], " nmsgs=", aC["Nmsgs"], " max|C-Transpose[{X,Y}]|=", N[agR[[2]]]];
sf["2-patch: head=", bC["Head"], " dims=", bC["Dims"], " nmsgs=", bC["Nmsgs"], " max|C-Transpose[{X,Y}]|=", N[agA[[2]]]];
sf["failing gates: ", If[$failNames === {}, "none", $failNames]];
sf["total: ", $pass, "/", $pass + $fail, " PASS"];
sfClose[];
Quit[];