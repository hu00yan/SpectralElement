(* ==================================================================== *)
(* Tests/bench.wl -- SOLVER GATES + the SpectralNDSolve vs NDSolve BENCH *)
(* Owner: agent D.  Run: ./rr.sh 3000 Tests/bench.wl                   *)
(* Evidence: the path in Tests/out/bench.lastout                       *)
(*                                                                   *)
(* STYLE RULE obeyed here: every statement sits on ONE line, so every  *)
(* line is individually bracket-balanced.  A multi-line bracket group  *)
(* in a generated script is the single most error-prone thing to hand *)
(* count, and it cost this file three wasted runs before the rule was  *)
(* adopted.                                                          *)
(*                                                                   *)
(* PROBLEMS (all with a MANUFACTURED solution, so the reported error  *)
(* is an error against a known answer, never a self-comparison):      *)
(*   P1 LINEAR    -Laplacian[u] == fLin        Rectangle (shorthand)  *)
(*   P2 NONLINEAR -Laplacian[u] + u^3 == fNl   Rectangle (shorthand) *)
(*   P3 LINEAR    -Laplacian[u] == fLin        Annulus   (shorthand) *)
(*   P4 NONLINEAR -Laplacian[u] + u^3 == fNl   Annulus   (shorthand) *)
(*   P5 NONLINEAR -Laplacian[u] + u^3 == fNl   TWO coupled CoonsPatches, *)
(*                                               so the interface     *)
(*                                               (flux) rows are used *)
(*   uexz = Sin[2x+1] Cos(3y-1) + xy/5                                   *)
(*   fLin = -Laplacian[uexz] ,  fNl = fLin + uexz^3                      *)
(* For each: wall clock around the PUBLIC call (AbsoluteTiming), max  *)
(* nodal error against uexz on EVERY node of EVERY patch, final      *)
(* residual, Newton history.  Then the SAME problem with NDSolve's    *)
(* built-in FEM, evaluated at the SAME points, at two mesh/Accuracy- *)
(* Goal settings, so speed and accuracy ratios are like for like.     *)
(* ==================================================================== *)
$HistoryLength = 0;

sfLog = If[StringQ[Environment["SPECF_OUT"]], Environment["SPECF_OUT"], FileNameJoin[{DirectoryName[$InputFileName], "out", "bench.nofallback.txt"}]];
sfStream = OpenWrite[sfLog];
(* sfSafe ran ToString[..., InputForm] on STRINGS as well, so every literal
   in the evidence file arrived wrapped and quote-doubled ("  ""PASS""  ")
   and the table rows printed as unevaluated StringPad[...].  A string is
   now written as itself; only non-strings get InputForm. *)
sfSafe[e_] := If[StringQ[e], e, Module[{s = ToString[e, InputForm]}, If[StringLength[s] > 300, StringTake[s, 300] <> "..TRUNC", s]]];
sf[args___] := Module[{s = StringJoin[sfSafe /@ {args}]}, WriteString[sfStream, s <> "\n"]; Flush[sfStream]; Print[s]];
sfClose[] := Module[{Close[sfStream]}];

tst[e_] := Module[{s = ToString[e, InputForm]}, StringTake[s, Min[300, StringLength[s]]]];
gn[e_] := If[TrueQ[NumericQ[e]], N[e], e];
emx[v_] := If[TrueQ[VectorQ[Flatten[v], NumericQ]], N[Max[Abs[Flatten[v]]]], -999.];
f3[e_] := Module[{v = Quiet[Check[N[e], $Failed]], m = 0., ex = 0}, If[! TrueQ[NumericQ[v]], Return["NONNUM"]]; If[TrueQ[v == 0], Return[0]]; m = N[Abs[v]]; ex = Floor[Log[10, m]]; N[Sign[v] Round[m/10^ex, 10^-2]]];

$pass = 0; $fail = 0; $failNames = {};
gate[name_, value_, target_, op_String] := Module[{v = value, ok = False, sent = TrueQ[NumericQ[value] && N[value] === -999.]}, ok = Switch[op, "<=", TrueQ[NumericQ[v] && N[v] <= N[target]], "<", TrueQ[NumericQ[v] && N[v] < N[target]], ">=", TrueQ[NumericQ[v] && N[v] >= N[target]], ">", TrueQ[NumericQ[v] && N[v] > N[target]], "==", TrueQ[v === target || v == target], True, False]; If[sent, ok = False]; If[TrueQ[ok], $pass++, $fail++]; If[! TrueQ[ok], AppendTo[$failNames, name]]; sf["  ", If[TrueQ[ok], "PASS", "FAIL"], "  ", name, " = ", tst[gn[v]], If[TrueQ[NumericQ[target]], StringJoin["   (target ", op, " ", ToString[gn[target], InputForm], ")"], ""]]; ok];

(* this file lives in Tests/, so the repo root is two levels up from it *)
repo = DirectoryName[DirectoryName[$InputFileName]];
Get[FileNameJoin[{repo, "Kernel", "SpectralElement.wl"}]];
gate["G0a loader defines SpectralNDSolve", Length[DownValues[SpectralElement`SpectralNDSolve]], 1, ">="];
gate["G0b loader defines SpectralNDSolveValue", Length[DownValues[SpectralElement`SpectralNDSolveValue]], 1, ">="];
gate["G0c SpectralNDSolve::nlnum has text", StringLength[SpectralElement`SpectralNDSolve::nlnum], 20, ">="];
gate["G0d SpectralNDSolve::ncond has text", StringLength[SpectralElement`SpectralNDSolve::ncond], 20, ">="];
gate["G0e loading raised no message", Length[Cases[$MessageList, HoldForm[MessageName[___]]]], 0, "=="];

uexz[x_, y_] := Sin[2 x + 1] Cos[3 y - 1] + x y/5;
fLin = -Laplacian[uexz[x, y], {x, y}];
fNl = -Laplacian[uexz[x, y], {x, y}] + uexz[x, y]^3;
regR = Rectangle[{-1.5, -1.2}, {1.8, 1.3}];
bdR = Abs[x + 1.5] < 1.*^-8 || Abs[x - 1.8] < 1.*^-8 || Abs[y + 1.2] < 1.*^-8 || Abs[y - 1.3] < 1.*^-8;
annR = Annulus[{1, 2}, {0, Pi}];
(* MEASURED DEFECT, fixed: bdA named only the two circular arcs r = 1 and
   r = 2.  Annulus[{1,2},{0,Pi}] is the UPPER half-annulus, so its boundary
   also contains the two radial edges on y = 0, and those unmatched edges
   take the API.md 4.3 homogeneous-Dirichlet default u == 0 -- while uexz
   does not vanish there: at theta = 0, uexz(r,0) = Sin[2r+1] Cos[-1], whose
   peak is exactly Cos[1] = 0.5403.  The measured P3 nodal error was
   0.5402947682285932 == Cos[1] to fifteen digits, which is that boundary
   mismatch and nothing else; P5 showed 1.032 == 2 Cos[1] for the same
   reason.  A manufactured solution has to satisfy the boundary data that is
   actually imposed, so the radial edges are named now. *)
bdA = Abs[Sqrt[x^2 + y^2] - 1] < 1.*^-8 || Abs[Sqrt[x^2 + y^2] - 2] < 1.*^-8 || Abs[y] < 1.*^-8;
thE[tt_] := Pi (1 - tt)/2;
(* MEASURED DEFECT, fixed: mkHalf[g_] takes the inner radius as g[-1] and the
   outer as g[1], and g = a + b tt runs over [a-b, a+b].  Patch 1 was written
   g = 1. + 0.5 tt, i.e. r in [0.5, 1.5] -- NOT [1, 1.5] -- so the discretized
   domain reached r = 0.5, where bdA imposes nothing and the API.md 4.3
   homogeneous default u == 0 applies while uexz does not vanish.  That is an
   O(1), degree-INDEPENDENT error and it is what G6e was measuring (1.0322 at
   degree 10 and 1.0465 at degree 16, i.e. no convergence at all).  The two
   radii that actually tile [1,2] and share the single interface circle
   r = 1.5 are a +- b = 1, 1.5 and a +- b = 1.5, 2. *)
mkHalf[g_] := {Function[tt, g[-1] {Cos[thE[tt]], Sin[thE[tt]]}], Function[tt, g[1] {Cos[thE[tt]], Sin[thE[tt]]}], Function[tt, g[tt] {-1, 0}], Function[tt, g[tt] {1, 0}]};
twoPatch = {SpectralElement`CoonsPatch[mkHalf[Function[tt, 1.25 + 0.25 tt]]], SpectralElement`CoonsPatch[mkHalf[Function[tt, 1.75 + 0.25 tt]]]};
eqLin = {-Laplacian[u[x, y], {x, y}] == fLin, DirichletCondition[u[x, y] == uexz[x, y], bdR]};
eqNl = {-Laplacian[u[x, y], {x, y}] + u[x, y]^3 == fNl, DirichletCondition[u[x, y] == uexz[x, y], bdR]};
eqAnL = {-Laplacian[u[x, y], {x, y}] == fLin, DirichletCondition[u[x, y] == uexz[x, y], bdA]};
eqAnN = {-Laplacian[u[x, y], {x, y}] + u[x, y]^3 == fNl, DirichletCondition[u[x, y] == uexz[x, y], bdA]};

(* exactNodal built a {np, nn, nn} Table whose LAST index varies fastest, so
   Flatten ran eta-fast, while seGather -- the vector it is compared against,
   and every selection matrix in the kernel -- is XI-fast (k = 1 + (ix-1) +
   nn (iy-1), seFlatIndex).  The two Flatten calls therefore lined up
   scrambled nodes and reported an O(1) "error" for a perfect solution:
   0.8419692105614234 at degree 16, which is exactly the G6a failure, while
   the same comparison in xi-fast order is 4.4654946407263196*^-11.  It now
   emits the {np, nn^2} xi-fast layout that seGather returns, and every
   Module-local is assigned in the BODY (an initializer cannot see an
   earlier initializer in this kernel). *)
exactNodal[disc_] := Module[{o, np, nn, out, p, ix, iy, kk}, o = Lookup[disc, "PatchOps"]; np = Length[o]; nn = Lookup[disc, "NodeCount"]; out = Table[0., {p, 1, np}, {k, 1, nn^2}]; Do[kk = 1 + (ix - 1) + nn (iy - 1); out[[p, kk]] = N[uexz[o[[p]]["Xs"][[ix, iy]], o[[p]]["Ys"][[ix, iy]]]]; , {iy, 1, nn}, {ix, 1, nn}, {p, 1, np}]; out];
gatherNodal[info_] := Module[{d = Lookup[info, "Disc"], lf = Lookup[Lookup[info, "Parts"], "Lift"], z = Lookup[info, "Global"]}, SpectralElement`Private`seGather[d, lf, z]];
nodalErr[info_] := Module[{g = gatherNodal[info], e = exactNodal[Lookup[info, "Disc"]]}, emx[Flatten[Flatten[g] - Flatten[e]]]];
evalPoints[info_] := Module[{np = Length[Lookup[Lookup[info, "Disc"], "PatchOps"]], nn = Dimensions[Lookup[Lookup[info, "Disc"], "PatchOps"][[1]]["Xs"]][[1]], out, o, p, ix, iy}, o = Lookup[Lookup[info, "Disc"], "PatchOps"]; out = {}; Do[AppendTo[out, {o[[p]]["Xs"][[ix, iy]], o[[p]]["Ys"][[ix, iy]]}]; , {iy, 1, nn}, {ix, 1, nn}, {p, 1, np}]; out];
specRun[label_, eq_, om_, n_, opts_] := Module[{m0 = Length[$MessageList], t = 0., res, info, mseen}, {t, res} = AbsoluteTiming[SpectralElement`SpectralNDSolve[eq, u, {x, y} \[Element] om, n, opts]]; info = SpectralElement`Private`seLastSolve; mseen = Cases[$MessageList[[m0 + 1 ;; Length[$MessageList]]], HoldForm[MessageName[s_, t___]] :> s]; <|"Label" -> label, "Time" -> t, "Info" -> info, "Public" -> res, "Err" -> nodalErr[info], "Pts" -> evalPoints[info], "Msgs" -> mseen|>];

sf["=== P1 LINEAR on Rectangle (region shorthand) ==="];
P1 = specRun["P1-LIN-RECT-n16", eqLin, regR, 16, {}];
sf["  ", P1["Label"], "  t=", N[P1["Time"]], "  nodalErr=", f3[P1["Err"]], "  res=", f3[Lookup[P1["Info"], "FinalResidual"]], "  method=", Lookup[P1["Info"], "Method"], "  public=", tst[Lookup[P1, "Public"]], "  opc=", Lookup[P1["Info"], "OpCoefficient"], "  msgs=", If[P1["Msgs"] === {}, "none", tst[P1["Msgs"]]]];
gate["G2 operator sign: -Laplacian+u^3 assembles with opc = -1", Lookup[Lookup[P1, "Info"], "OpCoefficient"], -1., "=="];
gate["G3 method dispatch: linear equation -> LinearSolve", Lookup[Lookup[P1, "Info"], "Method"], "Linear", "=="];
(* G1: API.md 4.3 pins the shape as {{u -> Function[...]{...}}}.  In WL that
   is a List holding a ONE-element List holding the Rule, so the old pattern
   {{_Rule, _Function}} demanded a TWO-element inner list and could never
   match a correct answer (it was a false failure, not a real defect -- the
   dumps showed the shape was right).  The pattern below is the contract
   itself: outer list, inner list, Rule whose rhs is a Function. *)
pubShape = Lookup[P1, "Public"];
gate["G1 SpectralNDSolve returns {{u -> Function}}", MatchQ[pubShape, {{_Rule}}] && MatchQ[pubShape[[1, 1, 2]], _Function], True, "=="];
gate["G1c that Rule is u -> fn", TrueQ[MatchQ[pubShape[[1, 1]], _Rule]] && TrueQ[pubShape[[1, 1, 1]] === u] && TrueQ[Head[pubShape[[1, 1, 2]]] === Function], True, "=="];
gate["G1b G0a-G0e style: loading was clean, so the solver is usable", $pass, 5, ">="];

(* Degrees for the nonlinear / annulus cases raised to 16 after MEASURING:
   at degree 10 the nonlinear rectangle error was 1.375e-5 and the
   nonlinear annulus error 4.27e-2, i.e. the gate was measuring truncation
   error rather than anything about the solver, and the two problems ran at
   two different degrees so the accuracy numbers were not comparable.  All
   five problems now run at the same degree 16 as P1/P3; thresholds below
   are set from the measured values with roughly 10x headroom. *)
sf["=== P2 NONLINEAR on Rectangle ==="];
P2 = specRun["P2-NL-RECT-n16", eqNl, regR, 16, MaxIterations -> 8];
sf["  ", P2["Label"], "  t=", N[P2["Time"]], "  nodalErr=", f3[P2["Err"]], "  res=", f3[Lookup[P2["Info"], "FinalResidual"]], "  iters=", Lookup[P2["Info"], "Iterations"], "  dels=", tst[N[Lookup[P2["Info"], "Dels"]]]];
gate["G3b method dispatch: nonlinear equation -> Newton", Lookup[Lookup[P2, "Info"], "Method"], "Newton", "=="];
gate["G2b nonlinear flag", Lookup[Lookup[P2, "Info"], "NonlinearQ"], True, "=="];
gate["G2c Newton converged", Lookup[Lookup[P2, "Info"], "Converged"], True, "=="];

sf["=== P3 LINEAR on Annulus (region shorthand) ==="];
P3 = specRun["P3-LIN-ANN-n16", eqAnL, annR, 16, {}];
sf["  ", P3["Label"], "  t=", N[P3["Time"]], "  nodalErr=", f3[P3["Err"]], "  res=", f3[Lookup[P3["Info"], "FinalResidual"]], "  msgs=", If[P3["Msgs"] === {}, "none", tst[P3["Msgs"]]]];

sf["=== P4 NONLINEAR on Annulus ==="];
P4 = specRun["P4-NL-ANN-n16", eqAnN, annR, 16, MaxIterations -> 8];
sf["  ", P4["Label"], "  t=", N[P4["Time"]], "  nodalErr=", f3[P4["Err"]], "  res=", f3[Lookup[P4["Info"], "FinalResidual"]], "  iters=", Lookup[P4["Info"], "Iterations"], "  dels=", tst[N[Lookup[P4["Info"], "Dels"]]]];

sf["=== P5 NONLINEAR on two coupled patches (flux rows exercised) ==="];
P5 = specRun["P5-NL-2PATCH-n16", eqAnN, twoPatch, 16, MaxIterations -> 8];
sf["  ", P5["Label"], "  t=", N[P5["Time"]], "  nodalErr=", f3[P5["Err"]], "  res=", f3[Lookup[P5["Info"], "FinalResidual"]], "  patchCount=", Lookup[Lookup[P5, "Info"], "Disc"]["PatchCount"], "  msgs=", If[P5["Msgs"] === {}, "none", tst[P5["Msgs"]]]];
gate["G14 P5 really used two patches", Lookup[Lookup[P5, "Info"], "Disc"]["PatchCount"], 2, "=="];

sf["=== G5 Newton quadratic convergence (P2) ==="];
dels = Lookup[Lookup[P2, "Info"], "Dels"];
(* QUADRATIC-CONVERGENCE METRIC (corrected, with the reason recorded).
   The old metric was  -log10(e_k) / -log10(e_k+1) >= 1.8.  For e_{k+1} =
   C e_k^2 that ratio tends to 2 only ASYMPTOTICALLY, and only once
   -log10(e_k) >> -log10(C); with a first step of O(1) the measured ratios
   are ~0.4 and the gate was failing a sequence that is in fact textbook
   quadratic.  The invariant of quadratic convergence is that the number of
   CORRECT DIGITS doubles each step, i.e. the DIFFERENCES of -log10|e| have
   ratio 2.  Measured on this run the digit gains are 1.35, 1.92, 3.80,
   7.57 -- ratios 1.43, 1.98, 1.99, i.e. converged to 2. *)
dl = -Log[10, Abs[dels]];
dg = Differences[dl];
(* List/List is NOT elementwise in WL -- it returns an unevaluated
   Times[{..},{..}], so Max[] saw a non-numeric expression and the gate
   failed on a perfectly good sequence.  Map[Divide, ...] is the fix. *)
dgl = Length[dg];
gr = MapThread[Divide, {dg[[2 ;; dgl]], dg[[1 ;; dgl - 1]]}];
sf["  dels = ", tst[N[dels]]];
sf["  -log10|dels| = ", tst[N[dl]]];
sf["  NEW DIGITS per step = ", tst[N[dg]]];
sf["  digit-growth ratios (quadratic -> 2) = ", tst[N[gr]]];
sf["  reference p11 sequence = {1.157, 0.0520, 2.78e-4, 7.41e-9, 1.90e-13, 8.77e-14}"];
gate["G5a Newton history recorded (>= 4 deltas)", Length[dels], 4, ">="];
gate["G5b Newton final step < 1e-12", Last[dels], 1.*^-12, "<"];
gate["G5c Newton cheap (<= 12 iterations)", Length[dels], 12, "<="];
gate["G5d quadratic: the digit gain roughly doubles (max ratio >= 1.8)", Max[gr], 1.8, ">="];
gate["G5e superlinear: every step after the first gains more digits than the one before", Min[dg[[2 ;;]]], dg[[1]], ">"];

sf["=== G6 spectral accuracy against the manufactured solution (degree as given) ==="];
gate["G6a P1 LINEAR  Rectangle max nodal error", P1["Err"], 1.*^-8, "<"];
gate["G6b P2 NONLIN  Rectangle max nodal error", P2["Err"], 1.*^-8, "<"];
gate["G6c P3 LINEAR  Annulus   max nodal error", P3["Err"], 1.*^-2, "<"];
gate["G6d P4 NONLIN  Annulus   max nodal error", P4["Err"], 1.*^-2, "<"];
gate["G6e P5 NONLIN  2 patches max nodal error", P5["Err"], 1.*^-2, "<"];
gate["G6f P1 residual at the computed solution", Lookup[Lookup[P1, "Info"], "FinalResidual"], 1.*^-10, "<"];
gate["G6g P2 residual at the computed solution", Lookup[Lookup[P2, "Info"], "FinalResidual"], 1.*^-10, "<"];
gate["G6h no unexpected message from P1..P5", Length[Join[P1["Msgs"], P2["Msgs"], P3["Msgs"], P4["Msgs"], P5["Msgs"]]], 0, "=="];

sf["=== G10/G11 negative controls ==="];
m0 = Length[$MessageList];
rFail = SpectralElement`SpectralNDSolve[eqNl, u, {x, y} \[Element] regR, 16, MaxIterations -> 1, Tolerance -> 1.*^-30];
(* The tag in $MessageList is held and its exact shape varies (MEASURED: a
   bare tag appears as HoldForm[Part::partw], a tagged one as
   HoldForm[MessageName[SpectralNDSolve, method], ...]).  Neither a
   fully-qualified MessageName nor MessageName["SpectralNDSolve", "nlnum", ___]
   with a STRING first argument can be relied on, and Cases with Set
   semantics would bind its pattern variable across entries.  Asking whether
   the tag NAME occurs anywhere in the printed form of an entry is the only
   shape-independent test. *)
sawTag[ml_, name_] := TrueQ[Cases[ml, _?(StringContainsQ[ToString[#, InputForm], name] &)] =!= {}];
nlSeen = sawTag[$MessageList[[m0 + 1 ;; Length[$MessageList]]], "nlnum"];
sf["  capped Newton returned ", Head[rFail], "   ::nlnum seen = ", nlSeen];
gate["G10 ::nlnum fires when Newton is capped", nlSeen, True, "=="];
gate["G10b capped Newton returns $Failed", rFail === $Failed, True, "=="];

m0 = Length[$MessageList];
rN = SpectralElement`SpectralNDSolve[{DirichletCondition[u[x, y] == uexz[x, y], bdR]}, u, {x, y} \[Element] regR, 16];
ncSeen = sawTag[$MessageList[[m0 + 1 ;; Length[$MessageList]]], "ncond"];
ncCount = Length[$MessageList[[m0 + 1 ;; Length[$MessageList]]]];
sf["  no-PDE call returned ", Head[rN], "   ::ncond seen = ", ncSeen, "   newMsgs=", ncCount];
gate["G11 ::ncond fires when there is no PDE for the boundary data", ncSeen, True, "=="];
gate["G11b that call returns $Failed", rN === $Failed, True, "=="];

sf["=== G12 reuse of a pre-built SpectralDiscretization ==="];
dPre = SpectralElement`SpectralDomain[regR, 16];
m0 = Length[$MessageList];
{tRe, rRe} = AbsoluteTiming[SpectralElement`SpectralNDSolve[eqLin, u, {x, y} \[Element] dPre, 16]];
iRe = SpectralElement`Private`seLastSolve;
gate["G12 the SAME pre-built association is consumed as-is", TrueQ[Lookup[Lookup[iRe, "Region"], "Degree"] === 16], True, "=="];
gate["G12b reuse returns the same shape as the from-scratch run", Head[rRe], Head[P1["Public"]], "=="];
gate["G12c reuse reproduces the from-scratch answer", Abs[nodalErr[iRe] - P1["Err"]] <= 10.^(-8) + 0.02 Abs[P1["Err"]], True, "=="];
gate["G12d reuse raised no message", Length[Cases[$MessageList[[m0 + 1 ;; Length[$MessageList]]], HoldForm[MessageName[___]]]], 0, "=="];

sf["=== NDSolve FEM comparison: same problem, same points, matched goals ==="];
sf["  Option semantics probed, not assumed: on a PDE over an ElementMesh, AccuracyGoal is the"];
sf["  requested accuracy of the SOLUTION and PrecisionGoal the requested precision of its"];
sf["  values; NDSolve derives the working precision from them.  Both are passed explicitly so"];
sf["  the comparison is at a stated, matched target rather than at an implicit default."];
sf["=== PRE-FEM VERDICT (all gates that do not need NDSolve) ==="];
sf["runner: ./rr.sh 3000 Tests/bench.wl"];
sf["failing gates so far: ", If[$failNames === {}, "none", $failNames]];
sf["subtotal: ", $pass, "/", $pass + $fail, " PASS"];
Needs["NDSolve`FEM`"];
regA = RegionIntersection[RegionDifference[Disk[{0, 0}, 2], Disk[{0, 0}, 1]], Rectangle[{-2, 0}, {2, 2}]];
(* MEASURED: femRun's stored "t" field did not agree with its own "tMesh" and
   "tSolve" fields (t = 0.0228 while tMesh + tSolve = 7.5), so every speed
   comparison and the summary table were reading a number that was not the
   FEM cost.  The total is now formed here, from the two fields that are
   printed, so the speedup column cannot silently disagree with the row above
   it. *)
femTotal[r_] := Lookup[r, "tMesh"] + Lookup[r, "tSolve"];
femRun[label_, eq_, reg_, pts_, mcm_, ag_] := Module[{m0 = Length[$MessageList], tm = 0., ts = 0., mh, us, err = -999., ne = 0, ms}, {tm, mh} = AbsoluteTiming[ToElementMesh[reg, "MaxCellMeasure" -> mcm]]; ne = Length[First[First[mh["MeshElements"]]]]; {ts, us} = AbsoluteTiming[NDSolveValue[eq, u, {x, y} \[Element] mh, AccuracyGoal -> ag, PrecisionGoal -> ag]]; err = emx[Table[us[pts[[j, 1]], pts[[j, 2]]] - uexz[pts[[j, 1]], pts[[j, 2]]], {j, 1, Length[pts]}]]; ms = Sort[DeleteDuplicates[Cases[$MessageList[[m0 + 1 ;; Length[$MessageList]]], HoldForm[MessageName[s_, t___]] :> s]]]; <|"Label" -> label, "tMesh" -> tm, "tSolve" -> ts, "t" -> tm + ts, "nElem" -> ne, "Err" -> err, "AG" -> ag, "MC" -> mcm, "Msgs" -> ms|>];
N1a = femRun["FEM-LIN-RECT-coarse", eqLin, regR, P1["Pts"], 0.05, 8];
N1b = femRun["FEM-LIN-RECT-fine", eqLin, regR, P1["Pts"], 0.03, 10];
N2a = femRun["FEM-NL-RECT-coarse", eqNl, regR, P2["Pts"], 0.05, 8];
N2b = femRun["FEM-NL-RECT-fine", eqNl, regR, P2["Pts"], 0.03, 10];
N4a = femRun["FEM-NL-ANN-coarse", eqAnN, regA, P4["Pts"], 0.05, 8];
N4b = femRun["FEM-NL-ANN-fine", eqAnN, regA, P4["Pts"], 0.03, 10];
femAll = {N1a, N1b, N2a, N2b, N4a, N4b};
(* f3 rounds to TWO significant digits, so a 0.0224 s mesh build printed as
   "tMesh=2.24" and the timing columns of this log disagreed with the
   unrounded summary underneath them.  Every wall-clock field below is
   printed with N[] instead, so the row and the table it feeds are the same
   number. *)
Do[sf["  ", femAll[[k]]["Label"], "  AG=", femAll[[k]]["AG"], "  maxCellMeasure=", femAll[[k]]["MC"], "  nElem=", femAll[[k]]["nElem"], "  tMesh=", N[femAll[[k]]["tMesh"]], "  tSolve=", N[femAll[[k]]["tSolve"]], "  tTotal=", N[femTotal[femAll[[k]]]], "  nodalErr=", f3[femAll[[k]]["Err"]], "  msgs=", If[femAll[[k]]["Msgs"] === {}, "none", tst[femAll[[k]]["Msgs"]]]], {k, 1, Length[femAll]}];
gate["G13 NDSolve FEM comparison produced finite numbers (linear rect)", TrueQ[NumericQ[N1b["Err"]] && N1b["Err"] > 0], True, "=="];
gate["G13b NDSolve FEM comparison produced finite numbers (nonlinear rect)", TrueQ[NumericQ[N2b["Err"]] && N2b["Err"] > 0], True, "=="];
gate["G13c NDSolve FEM comparison produced finite numbers (nonlinear annulus)", TrueQ[NumericQ[N4b["Err"]] && N4b["Err"] > 0], True, "=="];
gate["G13d spectral linear is more accurate than FEM linear at the SAME points", P1["Err"] < N1b["Err"], True, "=="];
gate["G13e spectral nonlinear is more accurate than FEM nonlinear at the SAME points", P2["Err"] < N2b["Err"], True, "=="];
gate["G13f spectral nonlinear is faster than FEM+mesh on the SAME problem", P2["Time"] < femTotal[N2b], True, "=="];

sf["=== SUMMARY: SpectralNDSolve vs NDSolve (the numbers a reader checks) ==="];
sf["  problem            | spectral t | spectral err | FEM fine t | FEM fine err | speedup | err ratio"];
sf["  (FEM fine t is ToElementMesh + NDSolveValue wall time, formed from the tMesh and tSolve fields printed above)"];
sf["  (speedup = FEM fine t / spectral t, so > 1 means the spectral solve was faster; err ratio = FEM err / spectral err)"];
rep = {{"LINEAR Rectangle", P1, N1b}, {"NONLIN Rectangle", P2, N2b}, {"NONLIN Annulus", P4, N4b}};
Do[r = rep[[k]]; sf["  ", StringPad[r[[1]], 17], " | ", StringPad[N[r[[2]]["Time"]], 11], " | ", StringPad[N[r[[2]]["Err"]], 13], " | ", StringPad[N[femTotal[r[[3]]]], 10], " | ", StringPad[N[r[[3]]["Err"]], 13], " | ", StringPad[N[femTotal[r[[3]]]/r[[2]]["Time"]], 8], " | ", N[r[[3]]["Err"]/r[[2]]["Err"]]]; , {k, 1, Length[rep]}];

sf["================ D BENCH DELIVERY ================"];
sf["runner: ./rr.sh 3000 Tests/bench.wl"];
sf["failing gates: ", If[$failNames === {}, "none", $failNames]];
sf["total: ", $pass, "/", $pass + $fail, " PASS"];
sfClose[];
Quit[];
