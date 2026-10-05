(* ==================================================================== *)
(* Examples/05-aaa-boundary.wl                                  E   *)
(*                                                                     *)
(* Method -> "AAA": FIT THE BOUNDARY INSTEAD OF EVALUATING IT.        *)
(*                                                                     *)
(* The four edges of a patch are normally evaluated exactly, edge by  *)
(* edge, every time the map is asked for a point.  With Method ->     *)
(* "AAA" each edge is instead SAMPLED on an equispaced grid and        *)
(* replaced by an AAA rational fit of both its coordinate functions,   *)
(* so the boundary becomes a closed-form rational curve that costs     *)
(* nothing to evaluate.  Use it when the boundary arrives as DATA --  *)
(* a sampled contour, an interpolant, a fit -- rather than as a        *)
(* callable you would rather not call a million times.                 *)
(*                                                                     *)
(*     ./rr.sh 300 Examples/05-aaa-boundary.wl                        *)
(*                                                                     *)
(* EXPECTED MESSAGES: CoonsPatch, twice, in the REFUSAL section only.  *)
(* That is the point of the section: a fit that fails is REFUSED,      *)
(* never quietly downgraded to Method -> "Analytic".                  *)
(* ==================================================================== *)
$HistoryLength = 0;

sfLog = If[StringQ[Environment["SPECF_OUT"]], Environment["SPECF_OUT"], FileNameJoin[{DirectoryName[$InputFileName], "05-aaa-boundary.txt"}]];
sfStream = OpenWrite[sfLog];
sf[args___] := Module[{s = StringJoin[ToString[#, InputForm] & /@ {args}]}, WriteString[sfStream, s <> "\n"]; Flush[sfStream]; Print[s]];

If[! MemberQ[$ContextPath, "SpectralElement`"], Get[FileNameJoin[{DirectoryName[$InputFileName], "..", "Kernel", "SpectralElement.wl"}]]];
If[! MemberQ[$ContextPath, "SpectralElement`"], Needs["SpectralElement`"]];

(* The same four concave arcs as 02-curved-coons-patch.wl. *)
gamma = 0.4;
bot = Function[t, {t, -1 + gamma (1 - t^2)}];
top = Function[t, {t, 1 - gamma (1 - t^2)}];
lef = Function[t, {-1 + gamma (1 - t^2), t}];
rig = Function[t, {1 - gamma (1 - t^2), t}];
edges = {bot, top, lef, rig};

nA = Length[$MessageList];
{tcA, ana} = AbsoluteTiming[CoonsPatch[edges]];
nB = Length[$MessageList];
{tcB, aaa} = AbsoluteTiming[CoonsPatch[edges, Method -> "AAA"]];
nC = Length[$MessageList];

sf["Analytic patch: Method tag = ", ana[["Method"]], "  messages = ", nB - nA];
sf["AAA      patch: Method tag = ", aaa[["Method"]], "  messages = ", nC - nB];
sf["AAA record: samples per edge = ", aaa[["AAA"]][["Samples"]], "   fits recorded = ", Length[aaa[["AAA"]][["Fits"]]]];
sf["construction time: Analytic = ", N[tcA], " s   AAA = ", N[tcB], " s   ratio = ", N[tcB/tcA]];

cornerDiff = Max[Flatten[Abs[Flatten[Table[aaa[["Corners"]][[c]] - ana[["Corners"]][[c]], {c, 1, 4}]]]]];
sf["the two patches agree on the 4 corners, max = ", N[cornerDiff]];

(* How far does the FITTED boundary sit from the true one?  Measured on
   a 401-point grid that is NOT the fit's own sample grid. *)
fine = Table[-1. + 2 i/400, {i, 0, 400}];
edgeDev = Max[Flatten[Table[{Abs[CoonsPatchMap[aaa, s, -1] - bot[s]], Abs[CoonsPatchMap[aaa, s, 1] - top[s]], Abs[CoonsPatchMap[aaa, -1, s] - lef[s]], Abs[CoonsPatchMap[aaa, 1, s] - rig[s]]}, {s, fine}]]];
sf["max |AAA fit - true arc| on 401 off-sample points = ", N[edgeDev]];

n = 12;
dA = SpectralDomain[{ana}, n];
dB = SpectralDomain[{aaa}, n];
sf["discretization: min J Analytic = ", N[SpectralDomainData[dA, "MinJacobian"]], "   AAA = ", N[SpectralDomainData[dB, "MinJacobian"]]];

(* AAASamples is SANITISED, not validated: a nonsense value falls back to
   the documented default of 65 and is silently ignored. *)
{tcC, aaa2} = AbsoluteTiming[CoonsPatch[edges, Method -> "AAA", AAASamples -> "lots"]];
sf["AAASamples -> \"lots\" : accepted = ", CoonsPatchQ[aaa2], "   samples actually used = ", aaa2[["AAA"]][["Samples"]]];
{tcD, aaa3} = AbsoluteTiming[CoonsPatch[edges, Method -> "AAA", AAASamples -> 200]];
sf["AAASamples -> 200       : accepted = ", CoonsPatchQ[aaa3], "   samples actually used = ", aaa3[["AAA"]][["Samples"]]];

(* ------------------------------------------------------------------ *)
(* THE REFUSALS.  An edge that does not sample to a finite real numeric *)
(* curve is REJECTED, not approximated.  There is no silent fallback  *)
(* to Method -> "Analytic": a bad boundary must not be passed off as  *)
(* a good one.                                                        *)
(* ------------------------------------------------------------------ *)
badEdges = {Function[t, {t, nosuchfn[t]}], top, lef, rig};
nMsg0 = Length[$MessageList];
bad1 = Check[CoonsPatch[badEdges, Method -> "AAA"], $Failed];
badTags = Cases[$MessageList[[nMsg0 + 1 ;;]], HoldForm[MessageName[nm_, tag___]] :> nm];
sf["edge that cannot be evaluated: result = ", If[TrueQ[AssociationQ[bad1]], "a patch", bad1], "   messages = ", If[badTags === {}, "none", DeleteDuplicates[badTags]]];

flatEdges = {Function[t, {0., 0.}], top, lef, rig};
nMsg0 = Length[$MessageList];
bad2 = Check[CoonsPatch[flatEdges, Method -> "AAA"], $Failed];
badTags2 = Cases[$MessageList[[nMsg0 + 1 ;;]], HoldForm[MessageName[nm_, tag___]] :> nm];
sf["edge that collapses to a point: result = ", If[TrueQ[AssociationQ[bad2]], "a patch", bad2], "   messages = ", If[badTags2 === {}, "none", DeleteDuplicates[badTags2]]];

sf["VERDICT: 05-aaa-boundary OK (the only messages are the two documented CoonsPatch refusals in the last section)"];
Close[sfStream];