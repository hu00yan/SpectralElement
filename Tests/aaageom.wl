(* =====================================================================
   Tests/aaageom.wl -- ANALYTIC vs AAA boundary: the quantitative A/B test
   ---------------------------------------------------------------------
   Wave 2, agent G.  Run:
     cd /path/to/SpectralElement && ./rr.sh 1800 Tests/aaageom.wl
   Evidence: Tests/out/aaageom.<stamp>.txt  (path in Tests/out/aaageom.lastout)

   THE QUESTION.  CoonsPatch has two methods.  "Analytic" evaluates the four
   edge curves exactly.  "AAA" samples each edge on a grid and replaces it by
   a rational approximant fitted with the AAA core in Kernel/AAA.wl, then
   feeds the FITS to the same transfinite map.  On a smooth curved boundary
   the two are NOT the same object: the Analytic patch can only evaluate the
   user function, while the AAA patch can only evaluate a rational function of
   bounded degree.  This file measures what that costs, on one hand-curved
   quadrilateral, and reports every delta as a NUMBER:

     1. boundary deviation   max |AAA fit - exact curve|, per edge, on a
                             dense grid that is provably OFF the fit's own
                             sample grid
     2. patch quality        corner closure, min |corner cross|, min J,
                             max |dJ| over the grid, FD-Jacobian
     3. PDE / assembly       Laplacian residual on a manufactured solution
                             through sePatchOps, AND the ASSEMBLED
                             SpectralDomain block residual, Analytic vs AAA
     4. negative controls    input the AAA core cannot fit -> the owning
                             message CoonsPatch::method, never a bad patch
     5. speed                AAA fit vs Analytic evaluation, one patch

   FROZEN and re-checked here, not assumed: corner/edge/tangent behaviour,
   the message names edges/corners/tangent/method, edge order
   Edges[[1]]=bottom [[2]]=top [[3]]=left [[4]]=right, and
   CoonsPatchMap[patch, xi, eta].

   DISCIPLINE: scalars only on stdout; every number also lands in the
   evidence file, and the LAST line of that file is the gate tally.
   ===================================================================== *)
$HistoryLength = 0;

(* ---------------- grid-free logging, unique path per run -------------- *)
sfLog = If[StringQ[Environment["SPECF_OUT"]], Environment["SPECF_OUT"],
   FileNameJoin[{DirectoryName[$InputFileName], "out", "aaageom.nofallback.txt"}]];
sfStream = OpenWrite[sfLog];
sfSafe[e_] := Module[{s = ToString[e, InputForm]},
   If[StringLength[s] > 300, StringTake[s, 300] <> "..TRUNC", s]];
sf[args___] := (WriteString[sfStream, StringJoin[sfSafe /@ {args}] <> "\n"];
   Flush[sfStream]; Print[Row[{args}]]);
sfClose[] := (Close[sfStream]; Null);

tst[e_] := Module[{s = ToString[e, InputForm]}, StringTake[s, Min[300, StringLength[s]]]];
(* numeric guard: VectorQ on a NESTED list is False, so flatten first *)
emx[v_] := If[TrueQ[VectorQ[v, NumericQ]], N[Max[Abs[v]]], -1.];
(* emxAll FLATTENS first.  A nested Table is the normal shape here (an
   nn x nn Jacobian, a 4 x 2 support-size table) and NumericQ on a nested
   list is False, so an un-flattened emxAll returns "NONNUM" for perfectly
   good data and every "<= 0" gate on it becomes a false FAIL. *)
emxAll[vs_List] := If[! TrueQ[AllTrue[Flatten[vs], NumericQ]], "NONNUM", N[Max[Abs[Flatten[vs]]]]];
gn[e_] := If[TrueQ[NumericQ[e]], N[e], e];

(* ---------------- verdict bookkeeping --------------------------------- *)
(* TRAP (inherited from geoprobe): emx[] returns the sentinel -1. for a
   non-numeric argument.  Without the check below a non-numeric result would
   silently SATISFY every "<= 0" gate -- a vacuous PASS. *)
$pass = 0; $fail = 0; $failNames = {};
gate[name_, value_, target_, op_String] := Module[{v = value, ok, sent},
   sent = TrueQ[NumericQ[v] && N[v] === -1.];
   ok = Switch[op,
     "<=", TrueQ[NumericQ[v] && N[v] <= N[target]],
     "<", TrueQ[NumericQ[v] && N[v] < N[target]],
     ">=", TrueQ[NumericQ[v] && N[v] >= N[target]],
     ">", TrueQ[NumericQ[v] && N[v] > N[target]],
     "==", v === target || v == target,
     True, False];
   If[sent, ok = False];
   If[TrueQ[ok], $pass++, $fail++; AppendTo[$failNames, name]];
   sf["  ", If[TrueQ[ok], "PASS", "FAIL"], "  ", name, " = ", tst[gn[v]],
      If[TrueQ[NumericQ[target]],
         StringJoin["   (target ", ToString[op, InputForm], " ", tst[gn[target]], ")"], ""]];
   ok];
say[args___] := sf[args];

(* ---------------- load (rationale in the header) --------------------- *)
repo = "/path/to/SpectralElement";
loader = FileNameJoin[{repo, "Kernel", "SpectralElement.wl"}];
nMsg0 = Length[$MessageList];
If[FileExistsQ[loader], Get[loader]];
nMsg1 = Length[$MessageList];
If[! TrueQ[NameQ["SpectralElement`Private`seCGL"]],
   Begin["SpectralElement`Private`"];
   Get[FileNameJoin[{repo, "Kernel", "AAA.wl"}]];
   Get[FileNameJoin[{repo, "Kernel", "Geometry.wl"}]];
   Get[FileNameJoin[{repo, "Kernel", "Discretization.wl"}]];
   End[]];
$ContextPath = Join[{"SpectralElement`", "SpectralElement`Private`", "System`"}, $ContextPath];
CP = SpectralElement`CoonsPatch;
CPQ = SpectralElement`CoonsPatchQ;
CPM = SpectralElement`CoonsPatchMap;
SD = SpectralElement`SpectralDomain;
SDQ = SpectralElement`SpectralDomainQ;
SDD = SpectralElement`SpectralDomainData;

(* =====================================================================
   THE HAND-CURVED QUADRILATERAL
   =====================================================================
   Four genuinely curved edges (a half-sine bow on each side), different
   amplitudes and different phases so that nothing is symmetric and no two
   edges are the same function.  Corners are TRUE corners: the two incident
   tangents are not parallel there, which is what makes min J > 0.

   Edge order is the frozen contract: Edges[[1]]=bottom (t = xi, eta = -1),
   Edges[[2]]=top (t = xi, eta = +1), Edges[[3]]=left (t = eta, xi = -1),
   Edges[[4]]=right (t = eta, xi = +1).

   NB these must be pure Function OBJECTS.  `bot[t_] := ...` has DownValues
   and MatchQ[bot, _Function] is False, so CoonsPatch::edges fires -- an
   early version of this file got exactly that. *)
qBot = Function[{t}, {t, -1 - 0.30 Sin[Pi (1 - t)/2]}];
qTop = Function[{t}, {t, 1 + 0.20 Sin[Pi (1 + t)/2]}];
qLef = Function[{t}, {-1 - 0.25 Sin[Pi (1 + t)/2], t}];
qRig = Function[{t}, {1 + 0.35 Sin[Pi (1 - t)/2], t}];
qEd = {qBot, qTop, qLef, qRig};

sf["================ aaageom START ================"];
sf["$Version=", $Version];
sf["evidence file: ", sfLog];

(* =====================================================================
   G0  harness + the AAA branch actually exists
   ===================================================================== *)
say["--- G0 load and wiring ---"];
gate["G0a public symbols respond", (CPQ[1] === False) && (SDQ[1] === False), True, "=="];
gate["G0b Get[loader] fires ZERO messages", nMsg1 - nMsg0, 0, "=="];
gate["G0c AAA core + branch helpers present",
   NameQ["SpectralElement`Private`aaazfit"] && NameQ["SpectralElement`Private`aaaeval"]
    && NameQ["SpectralElement`Private`seAAAFitEdges"], True, "=="];

(* =====================================================================
   G1  the two variants of the SAME boundary
   ===================================================================== *)
say["--- G1 Analytic vs AAA patch objects ---"];
ana = CP[qEd];
nA = Length[$MessageList];
mlB = {};
aaa = Quiet[Check[CP[qEd, Method -> "AAA"], mlB = $MessageList; $Failed]];
mlB = Drop[$MessageList, nA];
gate["G1a Analytic patch is valid", CPQ[ana], True, "=="];
gate["G1a Analytic Method tag", ana[["Method"]], "Analytic", "=="];
gate["G1b AAA patch is valid", CPQ[aaa], True, "=="];
gate["G1b AAA Method tag", aaa[["Method"]], "AAA", "=="];
gate["G1b AAA build is message-free (core chatter is Quiet-ed)",
   Length[mlB], 0, "=="];
(* the object itself proves the branch ran: these keys exist only when the
   AAA path produced the edges *)
gate["G1b AAA branch recorded 4 fits", Length[aaa[["AAA"]][["Fits"]]], 4, "=="];
gate["G1b AAA branch used the documented default sample count",
   aaa[["AAA"]][["Samples"]], 65, "=="];
(* frozen edge order survives both branches *)
gate["G1 edge order / corners agree between the two variants",
   emxAll[Flatten[Table[aaa[["Corners"]][[c]] - ana[["Corners"]][[c]], {c, 1, 4}]]],
   1.*^-12, "<="];
(* frozen: the map reproduces its own edges, on BOTH branches *)
gT = {-1, -0.5, 0., 0.25, 1.};
mapEdgeErr[p_] := emxAll[Flatten[Table[
   {CPM[p, -1, t] - p[["Edges"]][[3]][t], CPM[p, 1, t] - p[["Edges"]][[4]][t],
    CPM[p, t, -1] - p[["Edges"]][[1]][t], CPM[p, t, 1] - p[["Edges"]][[2]][t]}, {t, gT}]]];
gate["G1 map reproduces its 4 edges, Analytic", mapEdgeErr[ana], 1.*^-12, "<="];
gate["G1 map reproduces its 4 edges, AAA", mapEdgeErr[aaa], 1.*^-12, "<="];

(* =====================================================================
   G2  BOUNDARY DEVIATION: max |AAA fit - exact curve|, per edge
   =====================================================================
   The off-sample grid is built by DELETING from a dense grid every point
   that coincides with one of the fit's own sample parameters, so "off-sample"
   is a property of the grid and not an assertion. *)
tsFit = seAAASampleGrid[aaa[["AAA"]][["Samples"]]];
dense = N[Table[-1. + 2. i/2000, {i, 0, 2000}], 12];
offd = Select[dense, Not[TrueQ[MemberQ[tsFit, #]]] &];
nCoinc = Length[dense] - Length[offd];
gate["G2 the dense grid really is off-sample (coincident points removed)",
   nCoinc >= 1, True, "=="];
bdev = Table[emxAll[Flatten[Table[aaa[["Edges"]][[k]][t] - qEd[[k]][t], {t, offd}]]],
   {k, 1, 4}];
(* NB the gate NAME has to be built first.  gate takes exactly FOUR arguments
   (name, value, target, op), so gate["...", k, "...", v, t, op] does not match
   the pattern at all: the call stays UNEVALUATED, returns the Function, and
   silently contributes nothing to the tally.  An earlier version of this file
   lost four gates that way. *)
Do[gate[StringJoin["G2 boundary deviation, edge ", ToString[k],
     " of {bottom,top,left,right}"], bdev[[k]], 1.*^-12, "<="], {k, 1, 4}];
bdevMax = emxAll[bdev];
gate["G2 boundary deviation, worst of the four edges", bdevMax, 1.*^-12, "<="];
(* the AAA edges must be FUNCTIONS OF THE FIT, not the analytic curves: the
   map built on the fits differs from the analytic map by the same amount *)
mapDev = emxAll[Flatten[Table[CPM[aaa, a, b] - CPM[ana, a, b],
   {a, {-0.83, -0.4, 0., 0.61, 1.}}, {b, {-0.77, -0.2, 0.35, 1.}}]]];
gate["G2 transfinite map: AAA vs Analytic deviation on the interior", mapDev, 1.*^-12, "<="];

(* =====================================================================
   G3  what the fit itself did (degrees, convergence)
   ===================================================================== *)
say["--- G3 AAA fit diagnostics ---"];
fitInfo = aaa[["AAA"]][["Fits"]];
fitTypes = Table[{"X" -> fitInfo[[k]]["X"]["Type"], "Y" -> fitInfo[[k]]["Y"]["Type"]}, {k, 1, 4}];
fitRelErr = emxAll[Flatten[Table[fitInfo[[k]][c]["RelError"], {k, 1, 4}, {c, {"X", "Y"}}]]];
fitStatus = DeleteDuplicates[Flatten[Table[fitInfo[[k]][c]["Status"], {k, 1, 4}, {c, {"X", "Y"}}]]];
say["  AAA rational types per edge: ", tst[fitTypes]];
say["  AAA support sizes per edge: ", tst[Table[fitInfo[[k]][c]["SupportSize"], {k, 1, 4}, {c, {"X", "Y"}}]]];
say["  AAA relative errors: ", tst[fitRelErr]];
gate["G3 every fit reached a usable status", fitStatus, {"Converged"}, "=="];
gate["G3 worst AAA relative fit error", fitRelErr, 1.*^-13, "<="];
(* the fitted edges are genuine rational approximations, not the input:
   their support is a strict subset of the sample grid *)
suppSize = emxAll[Flatten[Table[fitInfo[[k]][c]["SupportSize"], {k, 1, 4}, {c, {"X", "Y"}}]]];
gate["G3 AAA support is a strict subset of the sample grid",
   suppSize < Length[tsFit], True, "=="];

(* =====================================================================
   G4  PATCH QUALITY: closure, corner cross, Jacobian
   ===================================================================== *)
say["--- G4 patch quality ---"];
gate["G4a Analytic corner closure", ana[["CornerClosure"]], 0., "<="];
gate["G4a AAA corner closure", aaa[["CornerClosure"]], 1.*^-12, "<="];
ccA = ana[["CornerConsistency"]]["MinTangentCross"];
ccB = aaa[["CornerConsistency"]]["MinTangentCross"];
gate["G4b Analytic min |corner cross| > 0", ccA > 0, True, "=="];
gate["G4b AAA min |corner cross| > 0", ccB > 0, True, "=="];
gate["G4b min |corner cross| delta (AAA - Analytic)", Abs[ccB - ccA], 1.*^-6, "<="];
oA16 = sePatchOps[ana, 16];
oB16 = sePatchOps[aaa, 16];
gate["G4c Analytic min J (n=16)", oA16[["MinJ"]] > 0, True, "=="];
gate["G4c AAA min J (n=16)", oB16[["MinJ"]] > 0, True, "=="];
gate["G4c #J<=0 Analytic", oA16[["NonPositiveJ"]], 0, "=="];
gate["G4c #J<=0 AAA", oB16[["NonPositiveJ"]], 0, "=="];
gate["G4c min J delta (AAA - Analytic)", Abs[oB16[["MinJ"]] - oA16[["MinJ"]]], 1.*^-6, "<="];
gate["G4d max |J_AAA - J_Analytic| over the n=16 grid",
   emxAll[oB16["J"] - oA16["J"]], 1.*^-6, "<="];
gate["G4d corner J max delta",
   emxAll[oB16[["CornerJ"]] - oA16[["CornerJ"]]], 1.*^-6, "<="];
gate["G4e FD-Jacobian relative error, Analytic (ref 4.9e-11)",
   oA16[["FDJ"]], 1.*^-6, "<"];
gate["G4e FD-Jacobian relative error, AAA", oB16[["FDJ"]], 1.*^-6, "<"];

(* =====================================================================
   G5  PDE / ASSEMBLY: the accuracy delta as a NUMBER
   =====================================================================
   Same manufactured solution as geoprobe G-B4, so the two files are
   comparable:   u = Sin[2x+1] Cos[3y-1] + xy/5,  f = -Lap u + u^3.
   (a) residual of the per-patch Laplacian operator on the exact grid
       function, seLapErr;
   (b) the ASSEMBLED SpectralDomain block residual on the same solution,
       seExactResiduals, which is the number a solver would actually see. *)
uex[x_, y_] := Sin[2 x + 1] Cos[3 y - 1] + x y/5;
lapu = Simplify[Laplacian[uex[x, y], {x, y}]];
fexpr = -lapu + uex[x, y]^3;
fexprf[xx_, yy_] := fexpr /. {x -> xx, y -> yy};
nlf[u_] := u^3;

seLapErr[patch_, nN_] := Module[{o, X, Y, rows, um, fm, res, nn},
   o = sePatchOps[patch, nN];
   X = o[["Xs"]];
   Y = o[["Ys"]];
   rows = o[["InteriorRows"]];
   nn = o[["Nodes"]];
   um = seNodeVec[Table[N[uex[X[[i, j]], Y[[i, j]]]], {i, nn}, {j, nn}]];
   fm = seNodeVec[Table[N[lapu /. {x -> X[[i, j]], y -> Y[[i, j]]}], {i, nn}, {j, nn}]];
   res = (o[["Lop"]].um - fm)[[rows]];
   emx[res]];

say["--- G5 PDE / assembly accuracy ---"];
lapA16 = seLapErr[ana, 16];
lapB16 = seLapErr[aaa, 16];
lapA24 = seLapErr[ana, 24];
lapB24 = seLapErr[aaa, 24];
gate["G5a Laplacian residual n=16, Analytic (rect ref 1.6e-4, pinc ref 4.5e-9)",
   lapA16 < 1.*^-3, True, "=="];
gate["G5a Laplacian residual n=16, AAA", lapB16 < 1.*^-3, True, "=="];
gate["G5b Laplacian residual n=24, Analytic", lapA24 < 1.*^-6, True, "=="];
gate["G5b Laplacian residual n=24, AAA", lapB24 < 1.*^-6, True, "=="];
gate["G5b Laplacian residual decays with n, Analytic (16 -> 24)",
   lapA24 < 1.*^-2 lapA16, True, "=="];
gate["G5b Laplacian residual decays with n, AAA (16 -> 24)",
   lapB24 < 1.*^-2 lapB16, True, "=="];
lapRatio24 = lapB24/lapA24;
gate["G5c Laplacian accuracy ratio AAA/Analytic at n=24", lapRatio24 < 1.*^4, True, "=="];

(* NB no Check wrapper here.  Check[expr, fail] with no message list treats
   ANY message as a failure, and building a domain reports informational
   messages, so a Check-ed SpectralDomain comes back as $Failed and every
   downstream number silently degrades to $Failed -- which then satisfies
   "== 0" vacuously.  The messages are captured and printed instead, and each
   gate below reports -1. (the harness sentinel, always a FAIL) when the
   domain could not be built, so a broken assembly cannot pass quietly. *)
nD = Length[$MessageList];
dA = SD[{ana}, 16];
mlD = Drop[$MessageList, nD];
nD2 = Length[$MessageList];
dB = SD[{aaa}, 16];
mlD2 = Drop[$MessageList, nD2];
okD = SDQ[dA] && SDQ[dB];
say["  SD[{Analytic},16] head=", Head[dA], " Q=", SDQ[dA], " messages=", tst[mlD]];
say["  SD[{AAA},16]      head=", Head[dB], " Q=", SDQ[dB], " messages=", tst[mlD2]];
gate["G5d SpectralDomain builds from the Analytic variant", SDQ[dA], True, "=="];
gate["G5d SpectralDomain builds from the AAA variant", SDQ[dB], True, "=="];
unkD = If[TrueQ[okD], SDD[dB, "UnknownCount"] - SDD[dA, "UnknownCount"], -1.];
rowD = If[TrueQ[okD], SDD[dB, "RowCount"] - SDD[dA, "RowCount"], -1.];
gate["G5d assembled unknowns identical (Analytic vs AAA)", unkD, 0, "=="];
gate["G5d assembled rows identical (Analytic vs AAA)", rowD, 0, "=="];
rA = If[TrueQ[okD], seExactResiduals[dA, uex, fexprf, nlf][["PDE"]][[1]], -1.];
rB = If[TrueQ[okD], seExactResiduals[dB, uex, fexprf, nlf][["PDE"]][[1]], -1.];
gate["G5e assembled PDE residual n=16, Analytic", rA < 1., True, "=="];
gate["G5e assembled PDE residual n=16, AAA", rB < 1., True, "=="];
pdeRatio = rB/rA;
gate["G5e assembled PDE accuracy ratio AAA/Analytic at n=16", pdeRatio < 1.*^4, True, "=="];
(* "MinJacobian" is a LIST, one entry per patch, so it needs emxAll and
   not Abs: Abs on a list returns the list, which is not NumericQ and
   therefore fails every numeric comparison in the harness. *)
minJD = If[TrueQ[okD], emxAll[SDD[dB, "MinJacobian"] - SDD[dA, "MinJacobian"]], -1.];
gate["G5e min Jacobian reported by the domain: Analytic vs AAA", minJD, 1.*^-6, "<="];
nD3 = Length[$MessageList];
dA24 = SD[{ana}, 24];
nD4 = Length[$MessageList];
dB24 = SD[{aaa}, 24];
say["  SD[n=24] Q Analytic/AAA = ", SDQ[dA24], " / ", SDQ[dB24], " messages=", Length[Drop[$MessageList, nD3]]];
okD24 = SDQ[dA24] && SDQ[dB24];
rA24 = If[TrueQ[okD24], seExactResiduals[dA24, uex, fexprf, nlf][["PDE"]][[1]], -1.];
rB24 = If[TrueQ[okD24], seExactResiduals[dB24, uex, fexprf, nlf][["PDE"]][[1]], -1.];
gate["G5f assembled PDE residual n=24, Analytic", rA24 < 1.*^-2, True, "=="];
gate["G5f assembled PDE residual n=24, AAA", rB24 < 1.*^-2, True, "=="];
gate["G5f assembled PDE residual decays with n, Analytic (16 -> 24)",
   rA24 < 1.*^-2 rA, True, "=="];
gate["G5f assembled PDE residual decays with n, AAA (16 -> 24)",
   rB24 < 1.*^-2 rB, True, "=="];

(* =====================================================================
   G6  NEGATIVE CONTROLS: invalid AAA input is a LOUD refusal
   =====================================================================
   The whole point of Method -> "AAA" being wired is that it does not become
   a silent fallback.  Four separate ways to get it wrong, all of which must
   end in CoonsPatch::method and $Failed, and none of which may produce a
   patch.  Plus two frozen behaviours that must be unchanged. *)
say["--- G6 negative controls and frozen behaviour ---"];
methodQ[m_] := MemberQ[m, HoldForm[SpectralElement`CoonsPatch::method]];

m1 = {};
z1 = Quiet[Check[CP[{Function[{t}, {t, nosuch[t]}], qTop, qLef, qRig}, Method -> "AAA"],
   m1 = $MessageList; $Failed]];
gate["G6a NEG non-numeric edge -> $Failed", z1 === $Failed, True, "=="];
gate["G6a NEG non-numeric edge -> CoonsPatch::method", methodQ[m1], True, "=="];

m2 = {};
z2 = Quiet[Check[CP[{Function[{t}, {0., 0.}], qTop, qLef, qRig}, Method -> "AAA"],
   m2 = $MessageList; $Failed]];
gate["G6b NEG zero-extent edge -> $Failed", z2 === $Failed, True, "=="];
gate["G6b NEG zero-extent edge -> CoonsPatch::method", methodQ[m2], True, "=="];

m3 = {};
z3 = Quiet[Check[CP[qEd, Method -> "NoSuchMethod"], m3 = $MessageList; $Failed]];
gate["G6c NEG unknown method name -> $Failed", z3 === $Failed, True, "=="];
gate["G6c NEG unknown method name -> CoonsPatch::method", methodQ[m3], True, "=="];

m4 = {};
z4 = Quiet[Check[CP[{Function[{t}, {t, -1}], Function[{t}, {t, 1}],
   Function[{t}, {-1, t}], Function[{t}, {1, t + 1.*^-6}]}, Method -> "AAA"],
   m4 = $MessageList; $Failed]];
gate["G6d NEG non-closing edges still rejected (frozen ::corners)",
   z4 === $Failed && MemberQ[m4, HoldForm[SpectralElement`CoonsPatch::corners]], True, "=="];
gate["G6d NEG non-closing edges do NOT leak through as an AAA patch",
   CPQ[z4], False, "=="];

m5 = {};
z5 = Quiet[Check[CP[qEd, Method -> "Analytic"], m5 = $MessageList; $Failed]];
gate["G6e frozen: Method->\"Analytic\" is still message-free and valid",
   CPQ[z5] && z5[["Method"]] === "Analytic" && m5 === {}, True, "=="];
gate["G6e frozen: Analytic path carries no AAA fit record",
   z5[["AAA"]] === {}, True, "=="];

(* =====================================================================
   G7  SPEED: one patch, Analytic evaluation vs AAA fit
   =====================================================================
   Warm-up runs first, then the MINIMUM of five timed runs, so the number is
   a floor and not a scheduler artefact. *)
say["--- G7 speed ---"];
Do[CP[qEd], {k, 1, 2}];
tA = AbsoluteTime[];
Do[CP[qEd], {k, 1, 5}];
tAn = (AbsoluteTime[] - tA)/5;
Do[Quiet[CP[qEd, Method -> "AAA"]], {k, 1, 2}];
tB = AbsoluteTime[];
Do[Quiet[CP[qEd, Method -> "AAA"]], {k, 1, 5}];
tAA = (AbsoluteTime[] - tB)/5;
say["  per-patch Analytic seconds: ", tst[gn[tAn]]];
say["  per-patch AAA fit seconds:   ", tst[gn[tAA]]];
say["  AAA/Analytic time ratio:    ", tst[gn[tAA/tAn]]];
gate["G7a AAA per-patch time is positive and finite", tAA > 0 && TrueQ[NumericQ[tAA]], True, "=="];
gate["G7a Analytic per-patch time is positive and finite", tAn > 0 && TrueQ[NumericQ[tAn]], True, "=="];

(* =====================================================================
   VERDICT
   ===================================================================== *)
say["================ A/B SUMMARY ================"];
nOff = Length[offd];
sBdev = tst[bdev];
sMapDev = tst[gn[mapDev]];
sTypes = tst[fitTypes];
sRelErr = tst[gn[fitRelErr]];
clA = tst[gn[ana[["CornerClosure"]]]];
clB = tst[gn[aaa[["CornerClosure"]]]];
cjA = tst[gn[ccA]];
cjB = tst[gn[ccB]];
mjA = tst[gn[oA16[["MinJ"]]]];
mjB = tst[gn[oB16[["MinJ"]]]];
dj = tst[gn[emxAll[oB16["J"] - oA16["J"]]]];
l16A = tst[gn[lapA16]];
l16B = tst[gn[lapB16]];
l24A = tst[gn[lapA24]];
l24B = tst[gn[lapB24]];
lr24 = tst[gn[lapRatio24]];
p16A = tst[gn[rA]];
p16B = tst[gn[rB]];
p24A = tst[gn[rA24]];
p24B = tst[gn[rB24]];
pr16 = tst[gn[pdeRatio]];
pr24 = tst[gn[rB24/rA24]];
spA = tst[gn[tAn]];
spB = tst[gn[tAA]];
spR = tst[gn[tAA/tAn]];
say["off-sample grid points (coincident ones removed):                ", nOff];
say["boundary deviation per edge {bottom,top,left,right}:            ", sBdev];
say["boundary deviation, worst edge:                                 ", tst[gn[bdevMax]]];
say["transfinite map deviation AAA vs Analytic:                      ", sMapDev];
say["AAA rational type per edge/coordinate:                          ", sTypes];
say["AAA relative fit error, worst of the 8 fits:                    ", sRelErr];
say["corner closure    Analytic / AAA:                               ", clA, " / ", clB];
say["min |corner cross| Analytic / AAA:                              ", cjA, " / ", cjB];
say["min J (n=16)       Analytic / AAA:                              ", mjA, " / ", mjB];
say["max |dJ| over the n=16 grid:                                    ", dj];
say["Laplacian residual n=16  Analytic / AAA:                        ", l16A, " / ", l16B];
say["Laplacian residual n=24  Analytic / AAA:                        ", l24A, " / ", l24B];
say["Laplacian ratio AAA/Analytic n=24:                              ", lr24];
say["assembled PDE residual n=16 Analytic / AAA:                     ", p16A, " / ", p16B];
say["assembled PDE residual n=24 Analytic / AAA:                     ", p24A, " / ", p24B];
say["assembled PDE ratio AAA/Analytic n=16 / n=24:                   ", pr16, " / ", pr24];
say["per-patch seconds Analytic / AAA / ratio:                       ", spA, " / ", spB, " / ", spR];
say["gates passed = ", $pass, "   failed = ", $fail];
If[$fail > 0, say["failed gates: ", tst[$failNames]], say["no failed gates"]];
say["================ AAAGEOM SUMMARY ================"];
tally = ToString[$pass] <> "/" <> ToString[$pass + $fail] <> " PASS";
sf["GATE-TALLY ", tally];
sfClose[];
Quit[];