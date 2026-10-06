(* ==================================================================== *)
(* Tests/probes/d2_nodc.wl -- GATE for the no-DirichletCondition defect. *)
(* Owner: agent D, round 3.                                           *)
(*                                                                   *)
(* DEFECT: SpectralNDSolve with NO DirichletCondition never returned   *)
(* (900 s guard, Tests/out/installprobe.104951_54302.txt).  API.md    *)
(* 4.3 says that case means homogeneous Dirichlet (u == 0) on the whole *)
(* exterior boundary, so it must SOLVE.  Root cause and numbers:      *)
(* Tests/out/d2_r3diag.*.txt plus the TRAP notes on seLiftNode        *)
(* (Kernel/Discretization.wl) and seLinSolve (Kernel/Solve.wl).       *)
(*                                                                   *)
(* MANUFACTURED PROBLEM (never a self-comparison): on                 *)
(* Rectangle[{-1,-1},{1,1}],                                         *)
(*    uexh = Sin[Pi x] Sin[Pi y]  -- vanishes on the WHOLE boundary,   *)
(*                                     so "u == 0 on the boundary"    *)
(*                                     IS its own true Dirichlet data *)
(*    fh   = -Laplacian[uexh] = 2 Pi^2 Sin[Pi x] Sin[Pi y]            *)
(* The solver gets the PDE and nothing else.                          *)
(*                                                                   *)
(* Two traps this file walked into first, recorded so the next reader  *)
(* does not repeat them (both MEASURED, both silent):                 *)
(*  1. A Module INITIALIZER cannot see an earlier initializer in the   *)
(*     same list, so every helper below assigns in the BODY.  Written *)
(*     as initializers they returned the SYMBOL Class / NodeCount and *)
(*     every count came out 0 or Missing, with no message.            *)
(*  2. This package's DirichletCondition takes TWO arguments --       *)
(*     DirichletCondition[u[x, y] == value, bdPredicate] -- NOT the   *)
(*     three-argument NDSolve form.  Written with {x, 1} the condition *)
(*     is simply not seen by seDirConditions (Cases[...,             *)
(*     DirichletCondition[_, _]]) and the solve quietly runs with NO   *)
(*     Dirichlet data at all, which is a different problem entirely. *)
(*                                                                   *)
(* Run: ./scratch/D2/run.sh 300 Tests/probes/d2_nodc.wl                *)
(* ==================================================================== *)
$HistoryLength = 0;
sfLog = If[StringQ[Environment["SPECF_OUT"]], Environment["SPECF_OUT"], FileNameJoin[{DirectoryName[$InputFileName], "out", "d2_nodc.nofallback.txt"}]];
sfStream = OpenWrite[sfLog];
sfSafe[e_] := If[StringQ[e], e, Module[{s = ToString[e, InputForm]}, If[StringLength[s] > 300, StringTake[s, 300] <> "..TRUNC", s]]];
sf[args___] := Module[{s = StringJoin[sfSafe /@ {args}]}, WriteString[sfStream, s <> "\n"]; Flush[sfStream]; Print[s]];
sfClose[] := Module[{Close[sfStream]}];
$pass = 0; $fail = 0; $failNames = {};
gate[name_, value_, target_, op_String] := Module[{v = value, ok = False, sent = TrueQ[NumericQ[value] && N[value] === -999.]}, ok = Switch[op, "<=", TrueQ[NumericQ[v] && N[v] <= N[target]], "<", TrueQ[NumericQ[v] && N[v] < N[target]], ">=", TrueQ[NumericQ[v] && N[v] >= N[target]], ">", TrueQ[NumericQ[v] && N[v] > N[target]], "==", TrueQ[v === target || v == target], True, False]; If[sent, ok = False]; If[! TrueQ[ok], AppendTo[$failNames, name]; $fail++, $pass++]; sf["  ", If[! TrueQ[ok], "FAIL", "PASS"], "  ", name, " = ", sfSafe[v], If[! TrueQ[ok], "   (want ", op, " ", sfSafe[target], ")"]; ok]];

(* this file lives in Tests/probes/, so the repo root is three levels up *)
repo = DirectoryName[DirectoryName[DirectoryName[$InputFileName]]];
Get[FileNameJoin[{repo, "Kernel", "SpectralElement.wl"}]];
gp = SpectralElement`Private`seGather;
lp = SpectralElement`Private`seLiftFrom;
ld = SpectralElement`Private`seDirLiftFn;
lc = SpectralElement`Private`seLiftConst;
so = SpectralElement`Private`seStackOperator;
ar = SpectralElement`Private`seAssembleRHS;
op = SpectralElement`Private`seOperatorParts;

(* the manufactured homogeneous problem and its manufactured data *)
uexh[x_, y_] := Sin[Pi x] Sin[Pi y];
fh = -Laplacian[uexh[x, y], {x, y}];
regH = Rectangle[{-1, -1}, {1, 1}];
eqH = -Laplacian[u[x, y], {x, y}] == fh;
bdH = Abs[x + 1.] < 1.*^-8 || Abs[x - 1.] < 1.*^-8 || Abs[y + 1.] < 1.*^-8 || Abs[y - 1.] < 1.*^-8;

(* the symbols a tagged 0.[...] carries are Head[0.] and Head[0] *)
taggedQ[e_] := MemberQ[{0, 0.}, Head[e]];

(* the nodal vector of the solved patch, xi-fast like seGather *)
nodalOf[info_] := gp[Lookup[info, "Disc"], Lookup[Lookup[info, "Parts"], "Lift"], Lookup[info, "Global"]];
(* max |u| over the nodes the discretization calls Dirichlet (= the exterior
   boundary here), and over the Interior ones; every local assigned in the body *)
bndStats[info_] := Module[{d, cl, nn, gv, nb = 0, ni = 0, mb = 0., mi = 0., p, ix, iy, kk, c, v}, d = Lookup[info, "Disc"]; cl = Lookup[d, "Class"]; nn = Lookup[d, "NodeCount"]; gv = nodalOf[info]; Do[c = cl[[p]][[ix, iy]]; If[c === "Dirichlet" || c === "Shared", nb++; v = Abs[N[gv[[p, 1 + (ix - 1) + nn (iy - 1)]]]]; If[! TrueQ[NumericQ[v]], v = Infinity]; mb = Max[mb, v], True, Nothing], {ix, 1, nn}, {iy, 1, nn}, {p, 1, Length[cl]}]; {nb, mb}];
interiorMax[info_] := Module[{d, cl, nn, gv, mi = 0., p, ix, iy, kk, c, v}, d = Lookup[info, "Disc"]; cl = Lookup[d, "Class"]; nn = Lookup[d, "NodeCount"]; gv = nodalOf[info]; Do[c = cl[[p]][[ix, iy]]; If[c === "Interior", v = Abs[N[gv[[p, 1 + (ix - 1) + nn (iy - 1)]]]]; If[! TrueQ[NumericQ[v]], v = Infinity]; mi = Max[mi, v], True, Nothing], {ix, 1, nn}, {iy, 1, nn}, {p, 1, Length[cl]}]; mi];
(* the manufactured solution sampled on the same nodes, xi-fast *)
exactNodal[d_] := Module[{o, np, nn, out, p, ix, iy, kk}, o = Lookup[d, "PatchOps"]; np = Length[o]; nn = Lookup[d, "NodeCount"]; out = Table[0., {p, 1, np}, {k, 1, nn^2}]; Do[kk = 1 + (ix - 1) + nn (iy - 1); out[[p, kk]] = N[uexh[o[[p]]["Xs"][[ix, iy]], o[[p]]["Ys"][[ix, iy]]]]; , {iy, 1, nn}, {ix, 1, nn}, {p, 1, np}]; out];
nodalErr[info_] := Module[{d, g, e}, d = Lookup[info, "Disc"]; g = nodalOf[info]; e = exactNodal[d]; N[Max[Abs[Flatten[Flatten[g] - Flatten[e]]]]]];

(* ==================================================================== *)
(* A. the defect itself: no DirichletCondition at all                     *)
(* ==================================================================== *)
sf["=== A. no DirichletCondition: the homogeneous default of API.md 4.3 ==="];
m0 = Length[$MessageList];
{tA, rA} = AbsoluteTiming[SpectralElement`SpectralNDSolve[eqH, u, {x, y} \[Element] regH, 16]];
iA = SpectralElement`Private`seLastSolve;
msgSliceA = $MessageList[[m0 + 1 ;; Length[$MessageList]]];
sf["  wall clock around the PUBLIC call = ", N[tA], " s"];
sf["  shape {{u -> fn}} = ", MatchQ[rA, {{_Rule}}] && MatchQ[rA[[1, 1, 2]], _Function]];
sf["  seLastSolve Ok                   = ", Lookup[iA, "Ok"]];
sf["  Method / Converged               = ", Lookup[iA, "Method"], " / ", Lookup[iA, "Converged"]];
sf["  DirichletConditions counted      = ", Lookup[iA, "DirichletConditions"], "   BoundaryNodes = ", Lookup[iA, "BoundaryNodes"]];
sf["  final residual                   = ", N[Lookup[iA, "FinalResidual"]]];
bA = bndStats[iA];
sf["  #Dirichlet+Shared nodes / max|u| there = ", bA[[1]], " / ", bA[[2]]];
sf["  max|u| over INTERIOR nodes        = ", interiorMax[iA]];
sf["  max nodal error vs the manufactured uexh = ", nodalErr[iA]];
ufn = rA[[1, 1, 2]];
sf["  returned Function at (1,0)         = ", ufn[1., 0.]];
sf["  returned Function at (-1,0.5)      = ", ufn[-1., 0.5]];
sf["  returned Function at (0,-1)        = ", ufn[0., -1.]];
sf["  returned Function at (0.25,0.5)    = ", ufn[0.25, 0.5], "   (uexh there = ", uexh[0.25, 0.5], ")"];
sf["  raw messages during the no-DC solve = ", ToString[msgSliceA, InputForm]];
nmsgA = Length[msgSliceA];
gate["N1 the no-DC solve returned {{u -> fn}}", MatchQ[rA, {{_Rule}}] && TrueQ[Lookup[iA, "Ok"]], True, "=="];
gate["N2 it returned in seconds, not at the guard", tA, 60., "<="];
gate["N3 it covered the whole exterior boundary (64 nodes at n=16)", bA[[1]], 64, "=="];
gate["N4 u == 0 on the WHOLE exterior boundary (exact)", bA[[2]], 0., "=="];
gate["N5 max|u| on the boundary <= 1e-12", bA[[2]], 1.*^-12, "<="];
gate["N6 the interior matches the manufactured solution", nodalErr[iA], 1.*^-6, "<="];
gate["N7 the interior is a clean nonzero numeric field", interiorMax[iA], 1.*^-3, ">"];
gate["N8 the returned Function answers 0 on the boundary", Max[Abs[ufn[1., 0.]], Abs[ufn[-1., 0.5]], Abs[ufn[0., -1.]]], 1.*^-12, "<="];
gate["N9 no message during the no-DC solve", nmsgA, 0, "=="];

(* ==================================================================== *)
(* A2. the same default through the NONLINEAR path (Newton), which reads  *)
(* the lift on every row of every iteration                          *)
(* ==================================================================== *)
sf["=== A2. no DirichletCondition, NONLINEAR (Newton reads the lift too) ==="];
eqHnl = -Laplacian[u[x, y], {x, y}] + u[x, y]^3 == fh + uexh[x, y]^3;
{tA2, rA2} = AbsoluteTiming[SpectralElement`SpectralNDSolve[eqHnl, u, {x, y} \[Element] regH, 16]];
iA2 = SpectralElement`Private`seLastSolve;
bA2 = bndStats[iA2];
sf["  wall = ", N[tA2], " s   Ok = ", Lookup[iA2, "Ok"], "   method = ", Lookup[iA2, "Method"], "   iterations = ", Lookup[iA2, "Iterations"]];
sf["  Newton |dels| = ", N[Lookup[iA2, "Dels"]]];
sf["  final residual = ", N[Lookup[iA2, "FinalResidual"]]];
sf["  #Dirichlet+Shared / max|u| there = ", bA2[[1]], " / ", bA2[[2]];
sf["  max nodal error vs the manufactured uexh = ", nodalErr[iA2]];
gate["N10 the no-DC NONLINEAR solve returned {{u -> fn}}", MatchQ[rA2, {{_Rule}}] && TrueQ[Lookup[iA2, "Ok"]], True, "=="];
gate["N11 it returned in seconds", tA2, 60., "<="];
gate["N12 u == 0 on the whole exterior boundary there too", bA2[[2]], 0., "=="];
gate["N13 it matches the manufactured solution", nodalErr[iA2], 1.*^-6, "<="];
gate["N14 Newton converged quadratically (dels present)", Length[Lookup[iA2, "Dels"]]], 3, ">="];

(* ==================================================================== *)
(* B. the lift and the constant it produces, no-DC: NUMERIC              *)
(* ==================================================================== *)
sf["=== B. the lift / lift-constant for the no-DC case ==="];
discH = Lookup[iA, "Disc"];
lf0 = lp[discH, ld[{}, x, y]];
lf0b = lp[discH, 0];
parts0 = op[eqH, u, {x, y}];
A0h = so[discH, parts0["OperatorCoefficient"]];
c0h = lc[discH, parts0["OperatorCoefficient"], lf0];
rhsh = ar[discH, parts0["RHS"], x, y];
sf["  Lift recorded by the solve == seLiftFrom[disc, seDirLiftFn[{},x,y]] : ", Lookup[Lookup[iA, "Parts"], "Lift"] === lf0];
sf["  seLiftFrom[disc, seDirLiftFn[{},x,y]] length = ", Length[Flatten[lf0]]];
sf["  its distinct entries                = ", Sort[ToString[#, InputForm] & /@ DeleteDuplicates[Flatten[lf0]]]];
sf["  it is numeric                       = ", VectorQ[Flatten[lf0], NumericQ]];
sf["  P's own call seLiftFrom[disc, 0] is numeric = ", VectorQ[Flatten[lf0b], NumericQ]];
sf["  it contains NO 0./0-headed expression= ", FreeQ[Flatten[lf0], _?taggedQ]];
sf["  seLiftConst c0                      = ", Length[c0h], " entries, numeric = ", VectorQ[Flatten[c0h], NumericQ]];
sf["  c0 contains NO 0./0-headed expression = ", FreeQ[Flatten[c0h], _?taggedQ]];
sf["  c0 max|.|                           = ", N[Max[Abs[Flatten[c0h]]]]];
sf["  rhs - c0 is numeric                 = ", VectorQ[Flatten[rhsh - c0h], NumericQ]];
tB = AbsoluteTiming[zb = LinearSolve[A0h, rhsh - c0h]];
sf["  LinearSolve[A0, rhs - c0] wall      = ", N[tB[[1]], 4], " s, length ", Length[zb]];
gate["B1 the no-DC lift is a clean numeric vector", VectorQ[Flatten[lf0], NumericQ], True, "=="];
gate["B2 no 0./0-headed object survives in the lift", FreeQ[Flatten[lf0], _?taggedQ], True, "=="];
gate["B3 no 0./0-headed object survives into seLiftConst", FreeQ[Flatten[c0h], _?taggedQ], True, "=="];
gate["B4 c0 is numeric (was 49 of 49 non-numeric)", VectorQ[Flatten[c0h], NumericQ], True, "=="];
gate["B5 rhs - c0 is numeric", VectorQ[Flatten[rhsh - c0h], NumericQ], True, "=="];
gate["B6 LinearSolve on that RHS is fast", tB[[1]], 30., "<="];

(* ==================================================================== *)
(* C. machine AND arbitrary-precision Dirichlet data, same property      *)
(* ==================================================================== *)
(* TRAP recorded here after it cost a run: in Wolfram Language
   Cos(3 b - 1) is the PRODUCT of the symbol Cos and (3 b - 1) -- f(x) means
   f*x, NOT f[x].  Written that way the "solution" is a polynomial times the
   bare symbol Cos, every node value is non-numeric, and the probe blamed the
   solver.  The brackets below are the whole difference. *)
sf["=== C. the machine and the arbitrary-precision lift paths ==="];
gz[a_, b_] := Sin[2 a + 1] Cos[3 b - 1] + a b/5;
gAp[a_, b_] := SetPrecision[Sin[2 a + 1] Cos[3 b - 1] + a b/5, 40];
liftReport[g_] := Module[{d, l, p, cc, fl}, d = SpectralElement`SpectralDomain[regH, 8]; l = lp[d, g]; p = op[-Laplacian[u[x, y], {x, y}] == 0, u, {x, y}]; cc = lc[d, p["OperatorCoefficient"], l]; fl = Flatten[l]; <|"Len" -> Length[fl], "Head" -> Head[fl[[1]]], "LiftNumeric" -> VectorQ[fl, NumericQ], "C0Numeric" -> VectorQ[Flatten[cc], NumericQ], "C0Max" -> N[Max[Abs[Flatten[cc]]]], "NoTaggedZero" -> FreeQ[Flatten[cc], _?taggedQ]|>];
rCM = liftReport[Function[{a, b}, gz[a, b]]];
rCA = liftReport[Function[{a, b}, gAp[a, b]]];
rC0 = liftReport[0];
rCN = liftReport[ld[{}, x, y]];
sf["  machine-precision DC lift: len ", rCM["Len"], " head ", rCM["Head"], " liftNum ", rCM["LiftNumeric"], " c0Num ", rCM["C0Numeric"], " c0max ", rCM["C0Max"], " noTaggedZeroFound=", rCM["NoTaggedZero"]];
sf["  arbitrary-precision (SetPrecision 40): len ", rCA["Len"], " head ", rCA["Head"], " liftNum ", rCA["LiftNumeric"], " c0Num ", rCA["C0Numeric"], " c0max ", rCA["C0Max"], " noTaggedZeroFound=", rCA["NoTaggedZero"]];
sf["  bare constant 0: len ", rC0["Len"], " head ", rC0["Head"], " liftNum ", rC0["LiftNumeric"], " c0Num ", rC0["C0Numeric"], " c0max ", rC0["C0Max"], " noTaggedZeroFound=", rC0["NoTaggedZero"]];
sf["  seDirLiftFn[{},x,y]: len ", rCN["Len"], " head ", rCN["Head"], " liftNum ", rCN["LiftNumeric"], " c0Num ", rCN["C0Numeric"], " c0max ", rCN["C0Max"], " noTaggedZeroFound=", rCN["NoTaggedZero"]];
gate["C1 machine DC lift -> numeric lift, numeric c0, no tagged zero", Not[TrueQ[rCM["LiftNumeric"] && rCM["C0Numeric"] && rCM["NoTaggedZero"]]], False, "=="];
gate["C2 arbitrary-precision DC lift -> numeric lift, numeric c0, no tagged zero", Not[TrueQ[rCA["LiftNumeric"] && rCA["C0Numeric"] && rCA["NoTaggedZero"]]], False, "=="];
gate["C3 the bare constant 0 gives a numeric lift and c0", Not[TrueQ[rC0["LiftNumeric"] && rC0["C0Numeric"] && rC0["NoTaggedZero"]]], False, "=="];
gate["C4 seDirLiftFn[{},x,y] gives a numeric lift and c0", Not[TrueQ[rCN["LiftNumeric"] && rCN["C0Numeric"] && rCN["NoTaggedZero"]]], False, "=="];

(* ==================================================================== *)
(* D. control: an ORDINARY DirichletCondition solve is untouched         *)
(* ==================================================================== *)
sf["=== D. control: a normal DirichletCondition solve still works ==="];
mD = Length[$MessageList];
eqD = {-Laplacian[u[x, y], {x, y}] == -Laplacian[gz[x, y], {x, y}], DirichletCondition[u[x, y] == gz[x, y], bdH]};
{tD, rD} = AbsoluteTiming[SpectralElement`SpectralNDSolve[eqD, u, {x, y} \[Element] regH, 16]];
iD = SpectralElement`Private`seLastSolve;
dD = Lookup[iD, "Disc"];
exactGz[d_] := Module[{o, np, nn, out, p, ix, iy, kk}, o = Lookup[d, "PatchOps"]; np = Length[o]; nn = Lookup[d, "NodeCount"]; out = Table[0., {p, 1, np}, {k, 1, nn^2}]; Do[kk = 1 + (ix - 1) + nn (iy - 1); out[[p, kk]] = N[gz[o[[p]]["Xs"][[ix, iy]], o[[p]]["Ys"][[ix, iy]]]]; , {iy, 1, nn}, {ix, 1, nn}, {p, 1, np}]; out];
gD = nodalOf[iD];
eD = exactGz[dD];
errD = N[Max[Abs[Flatten[Flatten[gD] - Flatten[eD]]]]];
liftD = Lookup[Lookup[iD, "Parts"], "Lift"];
c0D = Lookup[iD, "LiftConst"];
sf["  wall = ", N[tD], " s   Ok = ", Lookup[iD, "Ok"], "   max nodal error vs gz = ", errD];
sf["  its lift max|.| (nonzero, unlike the no-DC case) = ", N[Max[Abs[Flatten[liftD]]]]];
sf["  its c0 max|.| = ", N[Max[Abs[Flatten[c0D]]]], "   numeric = ", VectorQ[Flatten[c0D], NumericQ]];
sf["  DirichletConditions counted = ", Lookup[iD, "DirichletConditions"]];
sf["  raw messages during the DC solve = ", ToString[$MessageList[[mD + 1 ;; Length[$MessageList]]], InputForm]];
gate["D1 the DC solve still succeeds", TrueQ[Lookup[iD, "Ok"]], True, "=="];
gate["D2 the DC solve keeps its spectral accuracy", errD, 1.*^-8, "<="];
gate["D3 the DC lift is nonzero (the fix did not flatten it to 0)", Max[Abs[Flatten[liftD]]], 1.*^-3, ">"];
gate["D4 the DC lift-constant is numeric", VectorQ[Flatten[c0D], NumericQ], True, "=="];

(* ==================================================================== *)
(* E. Dirichlet data that is NOT a number is refused, loudly              *)
(* ==================================================================== *)
sf["=== E. non-numeric Dirichlet data is refused, not hung on ==="];
gBad[a_, b_] := gGhost[a, b];
mE = Length[$MessageList];
eqE = {-Laplacian[u[x, y], {x, y}] == 1, DirichletCondition[u[x, y] == gBad[x, y], bdH]};
{tE, rE} = AbsoluteTiming[SpectralElement`SpectralNDSolve[eqE, u, {x, y} \[Element] regH, 12]];
rawE = $MessageList[[mE + 1 ;; Length[$MessageList]]];
sf["  wall = ", N[tE], " s   answer head = ", Head[rE], "   answer === $Failed : ", TrueQ[rE === $Failed]];
sf["  raw $MessageList slice = ", ToString[rawE, InputForm]];
gate["E1 it returned instead of hanging", tE, 60., "<="];
gate["E2 it returned $Failed", TrueQ[rE === $Failed], True, "=="];
gate["E3 and it said why (a message was raised)", TrueQ[rawE =!= {}], True, "=="];
gate["E4 the message names the lift", StringFreeQ[ToString[rawE, InputForm], "nlift"], False, "=="];

sf["================ D2 R3 no-DirichletCondition PROBE ================"];
sf["runner: ./scratch/D2/run.sh 300 Tests/probes/d2_nodc.wl"];
sf["no-DC wall = ", N[tA], " s;  max|u| on the exterior boundary (64 nodes) = ", bA[[2]], ";  nodal error = ", nodalErr[iA]];
sf["failing gates: ", If[$failNames === {}, "none", $failNames]];
sf["total: ", $pass, "/", $pass + $fail, " PASS"];
sfClose[];
Quit[];