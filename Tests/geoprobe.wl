(* =====================================================================
   Tests/geoprobe.wl -- Wave-1 GEOMETRY + DISCRETIZATION gate probe.
   Owner: B (Kernel/Geometry.wl, Kernel/Discretization.wl).
   Run:   cd /Users/huyan00/mycode/SpectralElement && ./rr.sh 600 Tests/geoprobe.wl
   Evidence: Tests/out/geoprobe.<stamp>.txt  (path in Tests/out/geoprobe.lastout)

   HOW THIS PROBE LOADS THE FILES (loader-independent)
     1. If Kernel/SpectralElement.wl exists it is Get first, so the PUBLIC
        symbols arrive with their usage messages, in the context
        SpectralElement` (API.md 2.3).
     2. Then it tests NameQ["SpectralElement`Private`seCGL"]; if the loader
        did not pull the subfiles in (or no loader exists yet), the probe
        Gets them itself INSIDE Begin["SpectralElement`Private`"] -- the
        same context the loader uses -- so my internals always live in
        SpectralElement`Private` and never in Global`.
     3. Only the PUBLIC API and the se* internals (bare names, resolved via
        $ContextPath) are used below.

   REFERENCE numerics (READ ONLY, wl-verify/specF, never restated as ours):
     p11m4: rect lapErr 3.6e-9 @n=16, 1.0e-11 @n=24; pinc6 minJ 0.32,
            Jcorners 0.42, fdJ 9.3e-11, lapErr 4.5e-9 @n=16; starA2 minJ
            -2.0e-11 with 2 non-positive nodes (documented NEGATIVE);
            annul-quadrant minJ pi/8.
     p11 E0: flat degeneracy g2 = 1.9e-8 @n=24.
     p11 E2: half-annulus minJA = pi/8, minJB = 0.589; G7 flux jump on exact
            grid functions 3.1e-13 .. 7.1e-13; G6 exact-grid pdeA 3.2e-2
            @n=16 -> 7.2e-7 @n=32.

   DISCIPLINE: scalars only, never a raw matrix or node array on stdout.
   ===================================================================== *)
$HistoryLength = 0;

(* ---------------- grid-free logging, unique path per run -------------- *)
sfLog = If[StringQ[Environment["SPECF_OUT"]], Environment["SPECF_OUT"],
   FileNameJoin[{DirectoryName[$InputFileName], "out", "geoprobe.nofallback.txt"}]];
sfStream = OpenWrite[sfLog];
sfSafe[e_] := Module[{s = ToString[e, InputForm]},
   If[StringLength[s] > 300, StringTake[s, 300] <> "..TRUNC", s]];
sf[args___] := (WriteString[sfStream, StringJoin[sfSafe /@ {args}] <> "\n"];
   Flush[sfStream]; Print[Row[{args}]]);
sfClose[] := (Close[sfStream]; Null);

tst[e_] := StringTake[ToString[e, InputForm], Min[300, StringLength[ToString[e, InputForm]]]];
(* numeric guard: VectorQ on a NESTED list is False, so flatten first *)
emx[v_] := If[VectorQ[v, NumericQ], N[Max[Abs[v]]], -1.];
(* same guard for a LIST of residuals, and it refuses to let Max hide a
   non-numeric entry the way Max[..., 0.] would *)
emxAll[vs_List] := If[! TrueQ[AllTrue[vs, NumericQ]], "NONNUM", N[Max[Abs /@ vs]]];
gn[e_] := If[TrueQ[NumericQ[e]], N[e], e];
f3[e_] := Module[{v = Quiet[Check[N[e], $Failed]]},
   If[! TrueQ[NumericQ[v]], Return["NONNUM"]];
   If[TrueQ[v == 0], Return[0]];
   Module[{m = N[Abs[v]], ex = Floor[Log[10, m]]}, N[Sign[v]*Round[m/10^ex, 10^(1 - 3)]]]];

(* ---------------- verdict bookkeeping --------------------------------- *)
(* TRAP: emx[] returns the sentinel -1. when its argument is not numeric.
   Without the sentinel check below, a non-numeric result would silently
   SATISFY every "<= 0" gate -- a vacuous PASS.  A gate value of exactly
   -1. is therefore always a FAIL. *)
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
repo = "/Users/huyan00/mycode/SpectralElement";
loader = FileNameJoin[{repo, "Kernel", "SpectralElement.wl"}];
If[FileExistsQ[loader], Get[loader]];
If[! TrueQ[NameQ["SpectralElement`Private`seCGL"]],
   Begin["SpectralElement`Private`"];
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

(* manufactured solution, exactly as in the reference *)
uex[x_, y_] := Sin[2 x + 1] Cos[3 y - 1] + x y/5;
lapu = Simplify[Laplacian[uex[x, y], {x, y}]];
fexpr = -lapu + uex[x, y]^3;

(* max interior |(Lop.u) - Lap uex| for a CoonsPatch at degree nN.
   X[[i]] is the i-th ROW (a whole xi-line), so uex[X[[i]], Y[[j]]] was a
   length-nn vector, Flatten produced nn^3 = 4913 entries instead of
   nn^2 = 289, Lop.um then failed and every lapErr gate printed a raw
   SparseArray.  Reference layout (p11.wl): nodeVec[Table[g[[i, j]],
   {i, 1, n}, {j, 1, n}]], i.e. X[[i, j]] with i = xi, the FAST index.
   Measured after the fix: rect lapErr n=16 = 3.61035e-9 = reference 3.6e-9. *)
(* NB: every local is declared EMPTY and assigned in the BODY.  A Module
   whose initializer list reads o[["Xs"]] from the local o declared two
   slots earlier does NOT reliably see that value here, and the failure is
   silent -- o[["Xs"]] then raises Part::pspec1 and the gate prints a raw
   SparseArray. *)
seLapErr[patch_, nN_] := Module[{o, X, Y, rows, um, fm, res, nn},
   o = sePatchOps[patch, nN];
   X = o[["Xs"]];
   Y = o[["Ys"]];
   rows = o[["InteriorRows"]];
   nn = o[["Nodes"]];
   um = seNodeVec[Table[N[uex[X[[i, j]], Y[[i, j]]]], {i, nn}, {j, nn}]];
   fm = seNodeVec[Table[N[lapu /. {x -> X[[i, j]], y -> Y[[i, j]]}], {i, nn}, {j, nn}]];
   res = (o[["Lop"]].um - fm)[[rows]];
   N[Max[Abs[res]]]];

sf["================ geoprobe START ================"];
sf["$Version=", $Version];
sf["loader present=", FileExistsQ[loader],
   "   internals in SpectralElement`Private`: ", TrueQ[NameQ["SpectralElement`Private`seCGL"]]];
gate["G0a public symbols respond", (CPQ[1] === False) && (SDQ[1] === False), True, "=="];

(* =====================================================================
   G-B1  corner closure + corner metric consistency, and BOTH negative
         controls (non-closing edges; smooth boundary => tangent
         vertices => J = 0, the reference starA2).
   ===================================================================== *)
say["--- G-B1 corner consistency (+ negative controls) ---"];
rect = CP[{{#1, -1} &, {#1, 1} &, {-1, #1} &, {1, #1} &}];
gate["G-B1a rect CoonsPatchQ", CPQ[rect], True, "=="];
gate["G-B1a rect corner closure", rect[["CornerClosure"]], 0., "<="];
gate["G-B1a rect min |corner cross| (analytic 1)",
   rect[["CornerConsistency"]]["MinTangentCross"], 1., ">="];
gate["G-B1a rect non-degenerate flag", rect[["CornerConsistency"]]["NonDegenerate"], True, "=="];

(* the map must reproduce its own four edges exactly *)
mErr = emxAll[Flatten[Table[{CPM[rect, -1, t] - rect[["Edges"]][[3]][t],
   CPM[rect, 1, t] - rect[["Edges"]][[4]][t],
   CPM[rect, t, -1] - rect[["Edges"]][[1]][t],
   CPM[rect, t, 1] - rect[["Edges"]][[2]][t]}, {t, {-1, -0.5, 0., 0.3, 1.}}]]];
gate["G-B1a map reproduces all 4 edges (to machine precision)", mErr, 1.*^-12, "<="];

(* corner interpolation: corner qi of the object == map at that reference
   corner.  Corner order is the bilinear coefficient order:
   1 bottom(-1) = (-1,-1), 2 bottom(+1) = (+1,-1), 3 top(-1) = (-1,+1),
   4 top(+1) = (+1,+1). *)
cornerXY = {{-1, -1}, {1, -1}, {-1, 1}, {1, 1}};
cErr = emxAll[Flatten[Table[CPM[rect, cornerXY[[qi, 1]], cornerXY[[qi, 2]]]
   - rect[["Corners"]][[qi]], {qi, 1, 4}]]];
gate["G-B1a corner interpolation", cErr, 0., "<="];

(* an affine (hence bilinear-blend) field must come back exactly *)
lin = CP[{Function[t, {2 + 3 t, -3}], Function[t, {2 + 3 t, 1}],
   Function[t, {-1, -1 + 2 t}], Function[t, {5, -1 + 2 t}]}];
linErr = emxAll[Flatten[Table[CPM[lin, x0, y0] - {2 + 3 x0, -1 + 2 y0},
   {x0, {-0.7, 0., 0.45}}, {y0, {-1, 0.2, 1.}}]]];
gate["G-B1a affine field exact under the blend (to machine precision)", linErr, 1.*^-12, "<="];

(* NEGATIVE CONTROL 1: the four edges do not close *)
ml1 = {}; badClose = Quiet[Check[CP[{Function[t, {t, -1}], Function[t, {t, 1}],
   Function[t, {-1, t}], Function[t, {1, t + 1.*^-6}]}], ml1 = $MessageList; $Failed]];
gate["G-B1b NEG corners::corners fires",
   MemberQ[ml1, HoldForm[SpectralElement`CoonsPatch::corners]], True, "=="];
gate["G-B1b NEG non-closing patch rejected ($Failed)", badClose === $Failed, True, "=="];

(* NEGATIVE CONTROL 2: smooth closed boundary -> tangent vertices -> J = 0 *)
rad[ph_] := 1 + 0.2 Sin[3 ph];
(* API.md 4.1: the four edges must be PURE functions of one variable.
   NB Function[xx_, body] -- a PATTERN argument -- is NOT an applicand in
   Wolfram Language: Function[xx_, xx^2][3] stays unevaluated while
   MatchQ[..., _Function] is still True, so the patch silently built a
   garbage map (evidence Tests/out/b2min.*.txt, b2diag3.*.txt).
   Use the {x} form. *)
starEdges = {
   Function[{xx}, With[{ph = -Pi/2 + xx Pi/4}, rad[ph] {Cos[ph], Sin[ph]}]],
   Function[{xx}, With[{ph = Pi/2 - xx Pi/4}, rad[ph] {Cos[ph], Sin[ph]}]],
   Function[{yy}, With[{ph = -3 Pi/4 - (yy + 1) Pi/4}, rad[ph] {Cos[ph], Sin[ph]}]],
   Function[{yy}, With[{ph = yy Pi/4}, rad[ph] {Cos[ph], Sin[ph]}]]};
(* CoonsPatch::tangent is a WARNING: the object must come back so the gates
   below can read NonDegenerate / MinTangentCross.  Quiet[Message[...]] does
   NOT record into $MessageList (measured: 0 new messages, b2diag3.*.txt), so
   the capture has to be an explicit before/after Drop[]. *)
ml2n = Length[$MessageList]; star = CP[starEdges]; ml2 = Drop[$MessageList, ml2n];
gate["G-B1c NEG tangent::tangent fires",
   MemberQ[ml2, HoldForm[SpectralElement`CoonsPatch::tangent]], True, "=="];
gate["G-B1c NEG smooth star min |corner cross| ~ 0",
   star[["CornerConsistency"]]["MinTangentCross"], 1.*^-8, "<"];
gate["G-B1c NEG smooth star flagged NonDegenerate=False",
   star[["CornerConsistency"]]["NonDegenerate"], False, "=="];

(* =====================================================================
   G-B1d  Method -> "AAA" is WIRED (wave 2).  RESTATED: in wave 1 this gate
   asserted that Method -> "AAA" was rejected with CoonsPatch::method, which
   was the correct behaviour then and is now WRONG -- the branch is wired, so
   the assertion has to become its mirror image: the AAA branch must really
   run the fit and hand back a valid CoonsPatch, and the negative control
   that CoonsPatch::method still rejects input the AAA core cannot handle has
   to move to an input that genuinely cannot be fitted.  Restating a gate is
   a contract change, so it is recorded here rather than left to look like an
   unrelated edit.
   ===================================================================== *)
sq = {Function[t, {t, -1}], Function[t, {t, 1}],
   Function[t, {-1, t}], Function[t, {1, t}]};
mlA = Length[$MessageList];
ml3 = {};
aaaSq = Quiet[Check[CP[sq, Method -> "AAA"], ml3 = $MessageList; $Failed]];
mlA = Drop[$MessageList, mlA];
(* 0. only when the branch really ran AND produced a sound patch: a silent
   fallback to "Analytic" would give a valid object too, so the Method tag,
   the closure and the corner cross all have to agree as well. *)
aaaWired = If[TrueQ[CPQ[aaaSq] && aaaSq[["Method"]] === "AAA"
      && N[aaaSq[["CornerClosure"]]] <= 1.*^-12
      && N[aaaSq[["CornerConsistency"]]["MinTangentCross"]] >= 1. - 1.*^-12
      && mlA === {}], 0., 1.];
gate["G-B1d Method->AAA runs the fit and yields a valid CoonsPatch (no fallback)",
   aaaWired, 0., "<="];
(* the fitted edges must still BE the unit square's edges *)
aaaEdgeErr = emxAll[Flatten[Table[aaaSq[["Edges"]][[k]][t] - sq[[k]][t],
   {k, 1, 4}, {t, {-1, -0.5, 0., 0.25, 1.}}]]];
gate["G-B1d Method->AAA fit reproduces the exact edges (ref: analytic == AAA)",
   aaaEdgeErr, 1.*^-12, "<="];
(* NEGATIVE CONTROL (the old G-B1d assertion, moved onto input that the AAA
   core really cannot fit): a non-numeric edge, and an unknown method name.
   Both must still be a LOUD refusal through CoonsPatch::method.
   NB the list must stay at exactly FOUR edges -- Prepend would give five,
   and five edges is CoonsPatch::edges, not the ::method this gate is about. *)
ml3b = {};
aaaBadIn = {Function[t, {t, nosuch[t]}], sq[[2]], sq[[3]], sq[[4]]};
aaaBad = Quiet[Check[CP[aaaBadIn, Method -> "AAA"],
   ml3b = $MessageList; $Failed]];
ml3c = {};
aaaBad2 = Quiet[Check[CP[sq, Method -> "NoSuchMethod"],
   ml3c = $MessageList; $Failed]];
gate["G-B1d NEG invalid AAA input rejected via CoonsPatch::method",
   If[TrueQ[aaaBad === $Failed
      && aaaBad2 === $Failed
      && MemberQ[ml3b, HoldForm[SpectralElement`CoonsPatch::method]]
      && MemberQ[ml3c, HoldForm[SpectralElement`CoonsPatch::method]]], 0., 1.], 0., "<="];

(* =====================================================================
   G-B2  geometry gates on the reference pincushion (gamma = 0.6)
   ===================================================================== *)
say["--- G-B2 pincushion gamma=0.6 (reference p11m4) ---"];
pinc[g_] := Module[{K = {{1, 0}, {0, 1}, {-1, 0}, {0, -1}}, mm},
  Table[mm = g (K[[k]] + K[[Mod[k, 4] + 1]])/2;
    With[{K0 = K[[k]], K1 = K[[Mod[k, 4] + 1]], m = mm},
     Function[t, (1 - t)^2 K0 + 2 t (1 - t) m + t^2 K1]], {k, 1, 4}]];
c2t[f_] := Function[t, f[(1 + t)/2]];
c2tr[f_] := Function[t, f[(1 - t)/2]];
pg = pinc[0.6];
ml4 = {}; pincPatch = Quiet[Check[CP[{c2t[pg[[4]]], c2tr[pg[[2]]],
   c2tr[pg[[3]]], c2t[pg[[1]]]}], ml4 = $MessageList; $Failed]];
gate["G-B2 pincushion built without messages", ml4 === {}, True, "=="];
gate["G-B2 pincushion corner closure", pincPatch[["CornerClosure"]], 0., "<="];
gate["G-B2 pincushion min |corner cross| > 0",
   pincPatch[["CornerConsistency"]]["MinTangentCross"], 0.1, ">="];
pOps16 = sePatchOps[pincPatch, 16];
gate["G-B2 pincushion minJ (ref 0.32)", pOps16[["MinJ"]], 0.32, "<="];
gate["G-B2 pincushion J at vertices (ref 0.42)", pOps16[["CornerJ"]][[1]], 0.42, "<="];
gate["G-B2 pincushion J at all 4 vertices equal (to machine precision)",
   Max[pOps16[["CornerJ"]]] - Min[pOps16[["CornerJ"]]], 1.*^-12, "<="];
gate["G-B2 pincushion #J<=0 (ref 0)", pOps16[["NonPositiveJ"]], 0, "=="];
gate["G-B2 pincushion FD-Jacobian (ref 9.3e-11)", pOps16[["FDJ"]], 1.*^-9, "<"];

(* the negative control must be degenerate in the DISCRETE Jacobian too *)
sOps16 = sePatchOps[star, 16];
gate["G-B2 NEG smooth star minJ <= 0 (ref -2e-11)", sOps16[["MinJ"]], 0., "<"];
gate["G-B2 NEG smooth star #J<=0 (ref 2)", sOps16[["NonPositiveJ"]], 2, "=="];
gate["G-B2 NEG smooth star Laplacian is poisoned",
   seLapErr[star, 16], 1., ">"];

(* =====================================================================
   G-B3  flat degeneracy: Lop(rect) == the flat Kronecker Laplacian.
         NB the Kronecker sum is ONE physical expression -- a newline after
         a complete expression would terminate it and the leading `+' would
         be discarded (this bug produced g2 = 35196 in the reference).
   ===================================================================== *)
say["--- G-B3 flat degeneracy (reference g2 = 1.9e-8 at n=24) ---"];
rOps = sePatchOps[rect, 24];
gate["G-B3 max|Lop - (I (x) D2 + D2 (x) I)|", seFlatDegeneracy[rOps], 1.*^-6, "<"];
gate["G-B3 rect minJ (ref 1)", rOps[["MinJ"]], 1., "<="];
gate["G-B3 rect corner closure", rect[["CornerClosure"]], 0., "<="];
gate["G-B3 rect FD-Jacobian", rOps[["FDJ"]], 1.*^-9, "<"];

(* =====================================================================
   G-B4  Laplacian accuracy on the manufactured solution
   ===================================================================== *)
say["--- G-B4 Laplacian accuracy on exact grid functions ---"];
gate["G-B4 rect lapErr n=16 (ref 3.6e-9)", seLapErr[rect, 16], 1.*^-6, "<"];
gate["G-B4 rect lapErr n=24 (ref 1.0e-11)", seLapErr[rect, 24], 1.*^-6, "<"];
gate["G-B4 pincushion lapErr n=16 (ref 4.5e-9)", seLapErr[pincPatch, 16], 1.*^-6, "<"];
gate["G-B4 pincushion lapErr n=24 (ref 4.5e-11)", seLapErr[pincPatch, 24], 1.*^-6, "<"];

(* =====================================================================
   G-B5  two-patch half-annulus: interface DETECTION, shared unknowns,
         flux row on exact grid functions (reference G7)
   ===================================================================== *)
say["--- G-B5 half-annulus r[1,2] theta[0,pi], radial split at r=1.5 ---"];
thE[xx_] := Pi (1 - xx)/2;
rrA[yy_] := 1.25 + 0.25 yy;
rrB[yy_] := 1.75 + 0.25 yy;
mkHalf[rr_] := CP[{Function[t, rr[-1] {Cos[thE[t]], Sin[thE[t]]}],
   Function[t, rr[1] {Cos[thE[t]], Sin[thE[t]]}],
   Function[t, rr[t] {-1, 0}],
   Function[t, rr[t] {1, 0}]}];
pA = mkHalf[rrA]; pB = mkHalf[rrB];
gate["G-B5 patch A corner closure", pA[["CornerClosure"]], 0., "<="];
gate["G-B5 patch B corner closure", pB[["CornerClosure"]], 0., "<="];
discAB = Quiet[SD[{pA, pB}, 16]];
gate["G-B5 SpectralDomainQ", SDQ[discAB], True, "=="];
gate["G-B5 patch count", SDD[discAB, "PatchCount"], 2, "=="];
gate["G-B5 interfaces detected (expect exactly 1)", SDD[discAB, "InterfaceCount"], 1, "=="];
ifsAB = SDD[discAB, "InterfacePairs"];
gate["G-B5 interface is an eta-edge pair Top/Bottom",
   ifsAB[[1, "EdgeA"]] === "Top" && ifsAB[[1, "EdgeB"]] === "Bottom", True, "=="];
gate["G-B5 interface sample deviation", ifsAB[[1, "Deviation"]], 1.*^-12, "<"];
gate["G-B5 shared unknowns n-1", ifsAB[[1, "SharedNodes"]], 15, "=="];
gate["G-B5 interface pairing orientation Same", ifsAB[[1, "Orientation"]] === "Same", True, "=="];
gate["G-B5 flux orientation sigma=+1 (NDopA - NDopB)",
   SDD[discAB, "FluxRows"][[1, "Sigma"]], 1, "=="];
gate["G-B5 unknowns 2(n-1)^2 + (n-1) = 465", SDD[discAB, "UnknownCount"], 465, "=="];
gate["G-B5 rows == unknowns", SDD[discAB, "RowCount"], 465, "=="];
gate["G-B5 PDE rows per patch", SDD[discAB, "InteriorRowCounts"][[1]], 225, "=="];
gate["G-B5 flux rows", Length[SDD[discAB, "FluxRows"][[1, "FaceRowsA"]]], 15, "=="];
gate["G-B5 minJ patch A = r (Pi/2)(1/4) at r=1 = Pi/8 (ref)", SDD[discAB, "MinJacobian"][[1]], N[Pi/8] + 1.*^-10, "<="];
gate["G-B5 minJ patch B = r (Pi/2)(1/4) at r=1.5 = 3Pi/16 (ref 0.589)", SDD[discAB, "MinJacobian"][[2]], N[3 Pi/16] + 1.*^-10, "<="];
gate["G-B5 patch A FD-Jacobian", SDD[discAB, "FDJacobian"][[1]], 1.*^-8, "<"];
gate["G-B5 patch B FD-Jacobian", SDD[discAB, "FDJacobian"][[2]], 1.*^-8, "<"];

(* the two patches must read and write ONE shared vector: the 15 shared
   columns of M_A and of M_B are the same 15 global columns *)
(* Two traps here, both of which made this gate vacuous:
   (a) colOf declared nn = SDD[...] and k = 1 + ... + nn (ixy[[2]] - 1) in
       the SAME Module initializer list.  A Module initializer does not see
       an earlier initializer's value, so k was a bare Part on the symbol nn
       (Part::pkspec1) and colOf returned garbage for every node.
   (b) colOf[#, #2] & /@ Position[...] hands the pure function ONE argument
       per list element, and an element of Position[..., {2}] is the single
       pair {ix, iy} -- so # was bound to the whole pair and #2 never fired
       (Function::slotn).  Pass the patch index explicitly.
   (c) both "which column is it" idioms were unusable: the Condition form
       x_ /; ! TrueQ[x_ == 0] is Condition::condp (pattern on the right of
       a condition, matches everything), and the predicate form
       Position[row, _?(# =!= 0 &)] on a Normal-ed sparse row also returns
       spurious matches ({0} and {} alongside the real {451}).  A selection
       matrix row holds a single 1, so ask for the largest magnitude
       instead -- no pattern matching involved. *)
colOf[p_, ixy_] := Module[{nn, k, row, mag},
   nn = SDD[discAB, "NodeCount"];
   k = 1 + (ixy[[1]] - 1) + nn (ixy[[2]] - 1);
   row = Normal[SDD[discAB, "Selections"][[p]][[k]]];
   mag = Abs[row];
   If[Max[mag] === 0, -1, Ordering[mag, -1][[1]]]];
shA = colOf[1, #] & /@ Position[SDD[discAB, "Class"][[1]], "Shared", {2}];
shB = colOf[2, #] & /@ Position[SDD[discAB, "Class"][[2]], "Shared", {2}];
gate["G-B5 A has 15 shared nodes", Length[shA], 15, "=="];
gate["G-B5 B has 15 shared nodes", Length[shB], 15, "=="];
gate["G-B5 A and B share the SAME 15 columns (C0 pointwise)",
   Sort[DeleteDuplicates[shA]] === Sort[DeleteDuplicates[shB]], True, "=="];
gate["G-B5 A's shared columns are distinct", Length[DeleteDuplicates[shA]], 15, "=="];

(* G7: the flux row applied to the EXACT grid functions of uex *)
gate["G-B5 G7 flux jump, exact grid fns (ref 3.1e-13)", seFluxJump[discAB, 1, uex], 1.*^-11, "<"];
fr1 = SDD[discAB, "FluxRows"][[1]];
lfAB = seLiftFrom[discAB, uex];
gate["G-B5 G7 through the ASSEMBLED matrix + lift",
   N[Max[Abs[fr1[["Matrix"]].seExactGlobal[discAB, uex]
     + (fr1[["NDopA"]].lfAB[[1]] - fr1[["NDopB"]].lfAB[[2]])]]], 1.*^-11, "<"];

(* =====================================================================
   G-B6  assembled block residuals on the exact solution
         (reference G6 exact-grid pdeA 3.2e-2 @n=16 -> 7.2e-7 @n=32)
   ===================================================================== *)
say["--- G-B6 assembled block residuals, -Lop.u + u^3 - f ---"];
nlf[u_] := u^3;
(* seFvec / seExactResiduals pattern-match f_Function and call f[x, y], so
   the right-hand side must be handed over as a FUNCTION of two arguments;
   the bare expression fex left the whole call unevaluated. *)
fexprf[xx_, yy_] := fexpr /. {x -> xx, y -> yy};
rr16 = seExactResiduals[discAB, uex, fexprf, nlf];
gate["G-B6 n=16 PDE residual A (ref 3.2e-2)", rr16[["PDE"]][[1]], 1., "<"];
gate["G-B6 n=16 PDE residual B", rr16[["PDE"]][[2]], 1., "<"];
gate["G-B6 n=16 flux residual", rr16[["Flux"]][[1]], 1.*^-12, "<"];
disc32 = Quiet[SD[{pA, pB}, 32]];
rr32 = seExactResiduals[disc32, uex, fexprf, nlf];
gate["G-B6 n=32 PDE residual A (ref 7.2e-7)", rr32[["PDE"]][[1]], 1.*^-5, "<"];
gate["G-B6 n=32 PDE residual B", rr32[["PDE"]][[2]], 1.*^-5, "<"];
gate["G-B6 n=32 flux residual", rr32[["Flux"]][[1]], 1.*^-11, "<"];
gate["G-B6 PDE residual DECAYS with n (spectral)",
   rr32[["PDE"]][[1]] < 1.*^-3 rr16[["PDE"]][[1]], True, "=="];
gate["G-B6 n=32 unknowns 2*31^2+31 = 1953", SDD[disc32, "UnknownCount"], 1953, "=="];
gate["G-B6 n=32 G7 flux jump", seFluxJump[disc32, 1, uex], 1.*^-11, "<"];

(* =====================================================================
   G-B7  region shorthands
   ===================================================================== *)
say["--- G-B7 region shorthands ---"];
rectDisc = Quiet[SD[Rectangle[{-1, -1}, {1, 1}], 24]];
gate["G-B7 Rectangle patch count", SDD[rectDisc, "PatchCount"], 1, "=="];
gate["G-B7 Rectangle interfaces", SDD[rectDisc, "InterfaceCount"], 0, "=="];
gate["G-B7 Rectangle minJ (ref 1)", SDD[rectDisc, "MinJacobian"][[1]], 1., "<="];
gate["G-B7 Rectangle reproduces G-B3 (flat degeneracy)",
   seFlatDegeneracy[SDD[rectDisc, "PatchOps"][[1]]], 1.*^-6, "<"];
gate["G-B7 Rectangle reproduces G-B4 (lapErr n=24)",
   seLapErr[seRegionPatch[Rectangle[{-1, -1}, {1, 1}],
     <|"Method" -> "Analytic", "CornerTolerance" -> 1.*^-12|>], 24], 1.*^-6, "<"];
gate["G-B7 Rectangle Dirichlet nodes = 4n", Length[SDD[rectDisc, "BoundaryRows"][[1]]], 96, "=="];
gate["G-B7 Rectangle unknowns (n-1)^2", SDD[rectDisc, "UnknownCount"], 529, "=="];
gate["G-B7 Rectangle boundary edges", Length[SDD[rectDisc, "BoundaryEdges"][[1]]], 4, "=="];

annPi = Quiet[SD[Annulus[{1., 2.}, {0, Pi}], 16]];
gate["G-B7 Annulus span=Pi -> 1 patch", SDD[annPi, "PatchCount"], 1, "=="];
gate["G-B7 Annulus span=Pi minJ = r (Pi/2)(1/2) at r=1 = Pi/4", SDD[annPi, "MinJacobian"][[1]], N[Pi/4] + 1.*^-10, "<="];
gate["G-B7 Annulus span=Pi no interfaces", SDD[annPi, "InterfaceCount"], 0, "=="];
gate["G-B7 Annulus span=Pi FD-Jacobian", SDD[annPi, "FDJacobian"][[1]], 1.*^-8, "<"];
ann2Pi = Quiet[SD[Annulus[{1., 2.}, {0, 2 Pi}], 16]];
gate["G-B7 Annulus span=2Pi builds", SDQ[ann2Pi], True, "=="];
gate["G-B7 Annulus span=2Pi -> 2 angular patches", SDD[ann2Pi, "PatchCount"], 2, "=="];
gate["G-B7 Annulus span=2Pi -> 2 radial interfaces", SDD[ann2Pi, "InterfaceCount"], 2, "=="];
gate["G-B7 Annulus span=2Pi every minJ > 0", Min[SDD[ann2Pi, "MinJacobian"]] > 0, True, "=="];
gate["G-B7 Annulus span=2Pi unknowns 2*225+2*15", SDD[ann2Pi, "UnknownCount"], 480, "=="];
(* The span-2-pi annulus interfaces are TANGENTIAL (theta = const), unlike the
   half-annulus's radial cut, so the flux row differentiates in xi -- across
   the WHOLE patch, where uex oscillates -- and the jump is therefore
   truncation-limited, not machine-limited.  MEASURED on both interfaces:
       n =  8 -> 2.44, 2.43
       n = 16 -> 1.50e-1, 5.6e-2      <-- what n=16 can do
       n = 32 -> 1.4e-6, 4.4e-7
       n = 48 -> 3.7e-13               (max over both interfaces)
   The n=16 bound therefore only asserts that the two traces pair up and that
   sigma = +1 (sigma = -1 would degenerate the difference into a sum and give
   ~2x the trace magnitude, O(1)); the n=32 gate carries the spectral claim.
   The operator itself is exact: on g = x*y it returns -r (the analytic
   -(1/r) d/dtheta) to 3.3e-15 on both patches at both interfaces. *)
gate["G-B7 Annulus span=2Pi G7 on both interfaces, n=16 tangential cut (measured 1.5e-1)",
   Max[seFluxJump[ann2Pi, #, uex] & /@ {1, 2}], 0.5, "<"];
ann2Pi32 = Quiet[SD[Annulus[{1., 2.}, {0, 2 Pi}], 32]];
gate["G-B7 Annulus span=2Pi G7 CONVERGES spectrally (n=32, measured 1.4e-6)",
   Max[seFluxJump[ann2Pi32, #, uex] & /@ {1, 2}], 1.*^-5, "<"];
annR = Quiet[SD[Annulus[{2., 4.}, {0, Pi}], 16]];
gate["G-B7 Annulus r[2,4] minJ = 2*(Pi/2)*1 = Pi", SDD[annR, "MinJacobian"][[1]], N[Pi] + 1.*^-10, "<="];

mlD = {}; diskD = Quiet[Check[SD[Disk[{0, 0}, 2], 16], mlD = $MessageList; $Failed]];
gate["G-B7 Disk issues SpectralDomain::nreg",
   MemberQ[mlD, HoldForm[SpectralElement`SpectralDomain::nreg]], True, "=="];
gate["G-B7 Disk rejected", diskD === $Failed, True, "=="];
mlR = {}; r0D = Quiet[Check[SD[Annulus[{0, 2}, {0, Pi}], 16], mlR = $MessageList; $Failed]];
gate["G-B7 Annulus r1=0 issues SpectralDomain::nreg",
   MemberQ[mlR, HoldForm[SpectralElement`SpectralDomain::nreg]], True, "=="];
mlX = {}; pgD = Quiet[Check[SD[Polygon[{{0, 0}, {1, 0}, {1, 1}}], 16], mlX = $MessageList; $Failed]];
gate["G-B7 Polygon issues SpectralDomain::nreg",
   MemberQ[mlX, HoldForm[SpectralElement`SpectralDomain::nreg]], True, "=="];

(* =====================================================================
   G-B8  message-name contract (API.md 4.4) and the data-key contract
   ===================================================================== *)
say["--- G-B8 message names and data keys ---"];
msgDefined[nm_] := Module[{m = {}},
   Quiet[Check[MessageName[nm], m, $Failed]];
   ! MemberQ[m, Message::name]];
ownMsg = {SpectralElement`CoonsPatch::corners, SpectralElement`CoonsPatch::method,
   SpectralElement`CoonsPatch::tangent, SpectralElement`CoonsPatch::edges,
   SpectralElement`SpectralDomain::nreg, SpectralElement`SpectralDomain::iface,
   SpectralElement`SpectralDomain::degen, SpectralElement`SpectralDomain::junc,
   SpectralElement`SpectralDomain::key};
missing = Select[ownMsg, msgDefined[#] === False &];
gate["G-B8 all owned message names exist", Length[missing], 0, "=="];
mlK = {}; kk = Quiet[Check[SDD[discAB, "NoSuchKey"], mlK = $MessageList; $Failed]];
gate["G-B8 unknown data key issues SpectralDomain::key",
   MemberQ[mlK, HoldForm[SpectralElement`SpectralDomain::key]], True, "=="];
gate["G-B8 unknown data key returns $Failed", kk === $Failed, True, "=="];
reqKeys = {"Nodes", "PatchCount", "Degree", "UnknownCount", "InterfacePairs",
   "InteriorRows", "BoundaryRows", "FluxRows", "PatchMap", "Jacobian"};
badK = Select[reqKeys, TrueQ[Quiet[Check[SDD[discAB, #], $Failed]]] === $Failed &];
gate["G-B8 every API.md key resolves", Length[badK], 0, "=="];

(* =====================================================================
   G-B9  the discretisation primitives, checked independently so that a
         Kronecker / index-order slip cannot hide behind a big number
   ===================================================================== *)
say["--- G-B9 CGL grid, differentiation matrix, Kronecker order ---"];
(* API.md L346 / p11.wl L52: cgl[a_,b_,nn_] := Table[(a+b)/2 - (b-a)/2
   Cos[k Pi/(nn-1)], {k,0,nn-1}].  With a = -1, b = 1 that is ASCENDING
   (-1 first, +1 last) -- NOT Trefethen's descending convention, which the
   three old gate names/targets assumed. *)
xg9 = seCGL[-1., 1., 25];
gate["G-B9 CGL first node = -1 (ascending grid)", 1. + xg9[[1]], 1.*^-14, "<="];
gate["G-B9 CGL last node = +1 (ascending grid)", 1. - xg9[[25]], 1.*^-14, "<="];
gate["G-B9 CGL symmetric about 0 (to machine precision)", Max[Abs[xg9 + Reverse[xg9]]], 1.*^-12, "<="];
gate["G-B9 CGL strictly ASCENDING", Min[Differences[xg9]], 0., ">"];
D9 = seChebD1[xg9];
gate["G-B9 D1 annihilates constants", emx[D9.Table[1., {25}]], 1.*^-12, "<"];
gate["G-B9 D1 x = 1", Max[Abs[D9.xg9 - 1.]], 1.*^-12, "<"];
gate["G-B9 D1 x^2 = 2x", emx[D9.(xg9^2) - 2 xg9], 1.*^-11, "<"];
gate["G-B9 D1 x^3 = 3x^2", emx[D9.(xg9^3) - 3 xg9^2], 1.*^-10, "<"];
gate["G-B9 D1 Exp[x] = Exp[x]", emx[D9.Exp[xg9] - Exp[xg9]], 1.*^-7, "<"];
gate["G-B9 D1 Cos[3x] = -3 Sin[3x]",
   emx[D9.Cos[3 xg9] + 3 Sin[3 xg9]], 1.*^-6, "<"];
gate["G-B9 D1 row sums vanish (Trefethen)", emx[Map[Total, D9]], 1.*^-12, "<"];
nn9 = 9; xg9b = seCGL[-1., 1., nn9]; D9b = seChebD1[xg9b];
I9 = SparseArray[IdentityMatrix[nn9]]; D2b = D9b.D9b;
(* nodeVec[m_] = Flatten[Transpose[m]] makes the ROW index of m the FAST
   index (measured, b2diag3.*.txt).  p11.wl therefore builds its field
   tables as Table[..., {i, 1, n}, {j, 1, n}] with i = xi; the old gate table
   was {eta outer, xi inner}, which silently swapped xi and eta and turned
   the three D1/D2 gates into exact-integer failures (2.0 / 1.0).  Kronecker:
   the SECOND argument acts on the FAST index = xi (API.md L349). *)
T9 = Table[xi + 2 eta, {xi, xg9b}, {eta, xg9b}];
u9 = seNodeVec[T9];
T9q = Table[xi^2 + 2 eta^2, {xi, xg9b}, {eta, xg9b}];
u9q = seNodeVec[T9q];
gate["G-B9 nodeVec is Flatten[Transpose] (row index = xi is fast)",
   seNodeVec[{{1, 2}, {3, 4}}], {1, 3, 2, 4}, "=="];
gate["G-B9 nodeVec puts the row index on the fast axis (u = xi + 2 eta)",
   Abs[u9[[3]] - (xg9b[[3]] + 2 xg9b[[1]])], 1.*^-14, "<="];
gate["G-B9 Kron[Id,D1] differentiates xi (2nd argument = fast index)",
   emx[KroneckerProduct[I9, SparseArray[D9b]].u9 - 1.], 1.*^-11, "<"];
gate["G-B9 Kron[D1,Id] differentiates eta (1st argument = slow index)",
   emx[KroneckerProduct[SparseArray[D9b], I9].u9 - 2.], 1.*^-11, "<"];
gate["G-B9 Kron[Id,D2] differentiates xi (2nd argument = fast index)",
   emx[KroneckerProduct[I9, SparseArray[D2b]].u9q - 2.], 1.*^-9, "<"];
gate["G-B9 Kron[D2,Id] differentiates eta (1st argument = slow index)",
   emx[KroneckerProduct[SparseArray[D2b], I9].u9q - 4.], 1.*^-9, "<"];

(* =====================================================================
   VERDICT
   ===================================================================== *)
say["================ GEOPROBE SUMMARY ================"];
say["gates passed = ", $pass, "   failed = ", $fail];
If[$fail > 0, say["failed gates: ", tst[$failNames]],
   say["ALL GEOMETRY/DISCRETIZATION GATES PASS"]];
say["evidence file: ", sfLog];
sfClose[];
Quit[];
