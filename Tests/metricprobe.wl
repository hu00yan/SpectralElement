(* =====================================================================
   Tests/metricprobe.wl -- METRIC / GEOMETRIC-COEFFICIENT gate probe.
   Owner: B3 (Kernel/Discretization.wl).
   Run:   cd /path/to/SpectralElement && ./rr.sh 900 Tests/metricprobe.wl
   Evidence: Tests/out/metricprobe.<stamp>.txt  (path in
              Tests/out/metricprobe.lastout)

   WHY THIS FILE EXISTS
     Every geometry gate in Tests/geoprobe.wl that goes through the
     Rectangle shorthand uses the UNIT SQUARE Rectangle[{-1,-1},{1,1}]
     (G-B4, G-B7).  On the unit square the metric collapses to
     AA = CC = 1 and BB = 0, so NONE of those gates can tell a correct
     metric coefficient from a wrong one that happens to agree at
     a = b = 1.  This probe runs the same four-case matrix that isolated
     the discrepancy, and it is the regression net for it.

   THE MEASURED FACTS THIS FILE PINS (all at n = 16, interior rows only)
     max| (Lop . u_ex) - Lap[u_ex] |, four domains x five exact solutions
       I   unit rect [-1,1]^2                       <= 3.7e-9
       II  non-unit rect x[-1.5,1.8] y[-1.2,1.3]    <= 9.1e-8
       III offset-only rect x[-1,2] y[0,3]          <= 8.3e-7
       IV  pincushion gamma = 0.6 (curved, metric != 1) <= 4.5e-9
     The reference solution (the same one geoprobe uses) is column 4.
     Axis-aligned half-widths a, b give  Lap = u_xixi/a^2 + u_etaeta/b^2,
     so case II has AA = 1/a^2 = 0.3673, CC = 1/b^2 = 0.64 and BB = 0:
     a metric bug that swapped AA/CC, or that dropped the 1/J, would be
     O(1) there while staying invisible on the unit square.

   HOUSE RULES OBSERVED HERE
     * every internal is FULLY QUALIFIED.  The -script reader interns a
       context-free name against $ContextPath AT READ TIME, so a bare
       sePatchOps that appears before the $ContextPath join below becomes
       Global`sePatchOps and silently returns unevaluated.
     * one symbol per job: the analytic Laplacians are built from fresh
       symbols mx2/my2 that no Function pattern in this file rebinds.
       Reusing x/y there produced wrong Laplacians that looked exactly
       like an operator defect (measured -- do not repeat it).
     * scalars only on stdout; the evidence file is the stamped one.
   ===================================================================== *)
$HistoryLength = 0;

(* ---------------- grid-free logging, unique path per run -------------- *)
sfLog = If[StringQ[Environment["SPECF_OUT"]], Environment["SPECF_OUT"],
   FileNameJoin[{DirectoryName[$InputFileName], "out", "metricprobe.nofallback.txt"}]];
sfStream = OpenWrite[sfLog];
sfSafe[e_] := Module[{s}, s = ToString[e, InputForm];
   If[StringLength[s] > 300, StringTake[s, 300] <> "..TRUNC", s]];
sf[args___] := (WriteString[sfStream, StringJoin[sfSafe /@ {args}] <> "\n"];
   Flush[sfStream]; Print[Row[{args}]]; Null);

(* numeric guard: VectorQ on a NESTED list is False, so flatten first *)
emx[v_] := If[VectorQ[Flatten[v], NumericQ], N[Max[Abs[Flatten[v]]]], -1.];

(* ---------------- verdict bookkeeping --------------------------------- *)
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
   sf["  ", If[TrueQ[ok], "PASS", "FAIL"], "  ", name, " = ", sfSafe[v],
      If[TrueQ[NumericQ[target]],
         StringJoin["   (target ", ToString[op, InputForm], " ", sfSafe[target], ")"], ""]];
   ok];
say[args___] := sf[args];

(* ---------------- load ------------------------------------------------ *)
repo = "/path/to/SpectralElement";
loader = FileNameJoin[{repo, "Kernel", "SpectralElement.wl"}];
If[FileExistsQ[loader], Get[loader]];
$ContextPath = Join[{"SpectralElement`", "SpectralElement`Private`", "System`"},
   $ContextPath];
CP = SpectralElement`CoonsPatch;
CPQ = SpectralElement`CoonsPatchQ;
SD = SpectralElement`SpectralDomain;
SDQ = SpectralElement`SpectralDomainQ;
SDD = SpectralElement`SpectralDomainData;
sPO = SpectralElement`Private`sePatchOps;
sRP = SpectralElement`Private`seRegionPatch;
sNV = SpectralElement`Private`seNodeVec;
sFI = SpectralElement`Private`seFlatIndex;
sCGL = SpectralElement`Private`seCGL;

sf["================ metricprobe START ================"];
sf["$Version=", $Version, "  loader internals present=",
   TrueQ[NameQ["SpectralElement`Private`sePatchOps"]]];
gate["M0 public symbols respond",
   (CPQ[1] === False) && (SDQ[1] === False), True, "=="];

(* =====================================================================
   M1  the reference solution and the four DOMAINS
   ===================================================================== *)
(* the exact solution geoprobe uses, so the numbers are comparable *)
mx2 = Symbol["mx2"]; my2 = Symbol["my2"];
uex[mx2_, my2_] := Sin[2 mx2 + 1] Cos[3 my2 - 1] + mx2 my2/5;
lapUex = Simplify[Laplacian[uex[mx2, my2], {mx2, my2}]];
say["--- M1 domains (the metric-coefficient isolation matrix) ---"];
optsA = <|"Method" -> "Analytic", "CornerTolerance" -> 1.*^-12,
   "InterfaceTolerance" -> 1.*^-10, "BoundaryPredicate" -> Automatic|>;

unitPatch = Quiet[sRP[Rectangle[{-1, -1}, {1, 1}], optsA]];
bigPatch = Quiet[sRP[Rectangle[{-1.5, -1.2}, {1.8, 1.3}], optsA]];
offPatch = Quiet[sRP[Rectangle[{-1, 0}, {2, 3}], optsA]];

(* the geoprobe pincushion, gamma = 0.6, rebuilt verbatim: quadratic
   Bezier edges between the four diamond corners, midpoints pulled
   towards the centre.  Its J runs 0.32..0.42, so the metric is far from
   1 and the map is curved -- this is the gate geoprobe's G-B4
   "pincushion lapErr" actually runs on. *)
pincCorners = {{1, 0}, {0, 1}, {-1, 0}, {0, -1}};
pincEdges[g_] := Module[{mm},
   Table[mm = g (pincCorners[[z]] + pincCorners[[Mod[z, 4] + 1]])/2;
     With[{K0 = pincCorners[[z]], K1 = pincCorners[[Mod[z, 4] + 1]], m = mm},
       Function[t, (1 - t)^2 K0 + 2 t (1 - t) m + t^2 K1]], {z, 1, 4}]];
c2t[f_] := Function[t, f[(1 + t)/2]];
c2tr[f_] := Function[t, f[(1 - t)/2]];
pg6 = pincEdges[0.6];
pinPatch = Quiet[CP[{c2t[pg6[[4]]], c2tr[pg6[[2]]], c2tr[pg6[[3]]],
   c2t[pg6[[1]]]}]];

domList = {unitPatch, bigPatch, offPatch, pinPatch};
domName = {"I unit rect [-1,1]^2", "II non-unit rect a=1.65 b=1.25",
   "III offset rect a=b=1.5", "IV pincushion gamma=0.6"};
Do[gate["M1 " <> domName[[z]] <> " is a CoonsPatch", CPQ[domList[[z]]],
    True, "=="], {z, 4}];

(* =====================================================================
   M2  THE FOUR-CASE MATRIX:  max| (Lop . u_ex) - Lap[u_ex] |
   This is the gate the unit square alone cannot make.  geoprobe's own
   seLapErr, third argument added so several exact solutions can be run
   over the same cases.
   ===================================================================== *)
(* one extra exact solution beyond the reference, so the matrix has more
   than a single column and a single accidental agreement cannot hide a
   defect.  Chosen because its Laplacian is NON-CONSTANT and NON-ZERO,
   unlike x*y whose Laplacian vanishes identically and would pass even a
   badly wrong operator. *)
g2[mx2_, my2_] := mx2^2 + my2^2;
lapG2 = Simplify[Laplacian[g2[mx2, my2], {mx2, my2}]];

seLapErr[patch_, nN_, g_, la_] := Module[{o, X, Y, rows, um, fm, res, nn},
   (* every local is declared EMPTY and assigned in the BODY: a Module
      initializer that reads another initializer does not reliably see
      its value here, and the failure is silent. *)
   o = sPO[patch, nN]; X = o[["Xs"]]; Y = o[["Ys"]];
   rows = o[["InteriorRows"]]; nn = o[["Nodes"]];
   um = sNV[Table[N[g[X[[i, j]], Y[[i, j]]]], {i, nn}, {j, nn}]];
   fm = sNV[Table[N[la /. {mx2 -> X[[i, j]], my2 -> Y[[i, j]]}],
     {i, nn}, {j, nn}]];
   res = (o[["Lop"]].um - fm)[[rows]];
   N[Max[Abs[res]]]];

nN = 16;
say["--- M2 the isolation matrix at n=", nN,
   ": max| (Lop.u_ex) - Lap[u_ex] | on the interior rows ---"];
Do[
   e1 = seLapErr[domList[[z]], nN, uex, lapUex];
   e2 = seLapErr[domList[[z]], nN, g2, lapG2];
   gate["M2 " <> domName[[z]] <> " lapErr uex (ref 3.6e-9)", e1, 1.*^-6, "<"];
   gate["M2 " <> domName[[z]] <> " lapErr x^2+y^2", e2, 1.*^-6, "<"],
   {z, 4}];
(* the unit-square reference point: geoprobe measures 3.61035e-9 there,
   so this probe must agree with that number and not merely be small. *)
uRef = seLapErr[unitPatch, nN, uex, lapUex];
gate["M2 unit-rect lapErr reproduces the geoprobe reference 3.6e-9",
   Abs[uRef - 3.61035*^-9], 5.*^-13, "<"];

(* =====================================================================
   M3  the metric FIELDS themselves, which is where a swap would hide.
   Axis-aligned half-widths a, b give AA = 1/a^2, BB = 0, CC = 1/b^2,
   so the fields can be checked in CLOSED FORM -- no exact solution
   needed.  The general curvilinear statement is
       Lop = (AA kron[Id,D2]) + (BB kron[Dm,Dm]) + (CC kron[D2,Id])
             + (d10 kron[Id,Dm]) + (d01 kron[Dm,Id])
   with AA = al^2+ga^2 = |grad xi|^2, CC = be^2+de^2 = |grad eta|^2 and
   BB = 2 (al be + ga de); the coefficients come from the INVERSE metric
   and the invsine element J.  A swap of AA with CC is invisible when
   a = b AND at a = b = 1 it is invisible on the unit square itself.
   ===================================================================== *)
say["--- M3 the metric fields in closed form on the three rectangles ---"];
rectSpec = {{"unit", {-1, -1}, {1, 1}}, {"a=1.65 b=1.25", {-1.5, -1.2},
     {1.8, 1.3}}, {"a=b=1.5", {-1, 0}, {2, 3}}};
Table[
   rs = rectSpec[[z]];
   o = sPO[domList[[z]], nN];
   {x0, y0} = rs[[2]];
   {x1, y1} = rs[[3]];
   aa = (x1 - x0)/2; bb = (y1 - y0)/2;
   gate["M3 " <> rs[[1]] <> " AA == 1/a^2 (metric field, not the operator)",
     emx[Flatten[o[["AA"]] - 1/aa^2]], 1.*^-12, "<"];
   gate["M3 " <> rs[[1]] <> " CC == 1/b^2",
     emx[Flatten[o[["CC"]] - 1/bb^2]], 1.*^-12, "<"];
   gate["M3 " <> rs[[1]] <> " BB == 0 (axis aligned)",
     emx[Flatten[o[["BB"]]]], 1.*^-12, "<"];
   gate["M3 " <> rs[[1]] <> " J == a*b",
     emx[Flatten[o[["J"]] - aa bb]], 1.*^-12, "<"],
   {z, 3}];
(* a = b must give AA == CC: the one case where a swap is invisible, so
   it is checked separately to prove the swap test above is not vacuous. *)
oOff = sPO[offPatch, nN];
gate["M3 offset rect a=b: AA == CC (a swap is invisible HERE, by design)",
   emx[Flatten[oOff[["AA"]] - oOff[["CC"]]]], 1.*^-12, "<"];
oBig = sPO[bigPatch, nN];
gate["M3 big rect a!=b: AA != CC by exactly 1/a^2 - 1/b^2 (swap is VISIBLE)",
   Abs[emx[Flatten[oBig[["AA"]] - oBig[["CC"]]]] - Abs[1/1.65^2 - 1/1.25^2]],
   1.*^-12, "<"];

(* =====================================================================
   M4  the KRONEKER SLOT CONVENTION, pinned here because geoprobe's G-B9
   already checks it, but M3/M2 only hold if it stays as measured.
   ===================================================================== *)
say["--- M4 the Kron slot convention on the flat unit square ---"];
nF = 6;
xgF = sCGL[-1., 1., nF];
DmF = SpectralElement`Private`seChebD1[xgF];
D2F = DmF.DmF;
IdF = IdentityMatrix[nF];
(* The Kronecker product acts on a FLAT node vector, so the test fields
   are built on the flat grid directly: value at flat node k, where
   k = 1 + (i-1) + nF (j-1), i.e. xi FAST (seNodeVec convention).  Writing
   them as two-argument pure functions and calling nvF[f] with ONE
   argument silently returned a non-numeric and every gate below read
   the -1. sentinel. *)
nvF[g_] := sNV[Table[N[g[xgF[[i]], xgF[[j]]]], {i, nF}, {j, nF}]];
fXi3 = Function[{qi, qj}, qi^3];
fEta3 = Function[{qi, qj}, qj^3];
dXi3 = Function[{qi, qj}, 6 qi];
dEta3 = Function[{qi, qj}, 6 qj];
gate["M4 Kron[Id,D2] differentiates xi",
   emx[Flatten[KroneckerProduct[IdF, D2F].nvF[fXi3] - nvF[dXi3]]],
   1.*^-9, "<"];
gate["M4 Kron[D2,Id] differentiates eta",
   emx[Flatten[KroneckerProduct[D2F, IdF].nvF[fEta3] - nvF[dEta3]]],
   1.*^-9, "<"];
gate["M4 Kron[Dm,Dm] is the mixed term (zero on a pure xi field)",
   emx[Flatten[KroneckerProduct[DmF, DmF].nvF[fXi3]]], 1.*^-9, "<"];

(* =====================================================================
   M5  COORDINATE EXPOSURE -- hypothesis (c).  Xs/Ys are what every gate,
   the lift and the solver read, so they must equal the transfinite map
   evaluated at the SAME CGL nodes.  Measured: exactly 0 on all four.
   ===================================================================== *)
say["--- M5 coordinate exposure: Xs/Ys against the map ---"];
Do[
   pt = domList[[z]];
   o = sPO[pt, nN];
   nn = o[["Nodes"]]; xg = o[["Nodes1D"]];
   md = Table[pt[["Map"]][xg[[i]], xg[[j]]], {i, nn}, {j, nn}];
   gate["M5 " <> domName[[z]] <> " Xs == map_x at every node",
     emx[Flatten[Table[N[o[["Xs"]][[i, j]] - md[[i, j, 1]]], {i, nn}, {j, nn}]]],
     1.*^-14, "<"];
   gate["M5 " <> domName[[z]] <> " Ys == map_y at every node",
     emx[Flatten[Table[N[o[["Ys"]][[i, j]] - md[[i, j, 2]]], {i, nn}, {j, nn}]]],
     1.*^-14, "<"],
   {z, 4}];

(* =====================================================================
   M6  THE PINCUSHION GATE'S ACTUAL DOMAIN.  The dispatcher asked which
   domain geoprobe's "pincushion lapErr" really runs on: it is this
   diamond-shaped patch with corners (1,0),(0,1),(-1,0),(0,-1) and
   J in 0.32..0.42 -- i.e. the ONLY curved, metric-not-1 case in the
   suite, and it is what M2 column IV measures.
   ===================================================================== *)
say["--- M6 the pincushion is genuinely curved and its metric != 1 ---"];
oPin = sPO[pinPatch, nN];
gate["M6 pincushion J is NOT 1 anywhere (min < 0.5)", oPin[["MinJ"]], 0.5, "<"];
gate["M6 pincushion J is positive", oPin[["NonPositiveJ"]], 0, "=="];
gate["M6 pincushion metric is NOT constant: AA varies (max-min > 1)",
   Max[Flatten[oPin[["AA"]]]] - Min[Flatten[oPin[["AA"]]]], 1., ">"];
gate["M6 pincushion AA != CC somewhere (a swap would be visible)",
   Max[Flatten[Abs[oPin[["AA"]] - oPin[["CC"]]]]], 1.*^-3, ">"];
gate["M6 pincushion BB != 0 (the cross term is exercised)",
   Max[Flatten[Abs[oPin[["BB"]]]]], 1.*^-3, ">"];
gate["M6 pincushion FD-Jacobian (ref 9.3e-11)", oPin[["FDJ"]], 1.*^-9, "<"];

(* =====================================================================
   M7  System["Matrix"] -- the public "Matrix" key.  It used to be
   built by ArrayPad[block, {0,0,0,pad}] on a RANK-2 block, which is one
   padding entry too many: ArrayPad returned UNEVALUATED, ArrayFlatten
   then complained about its rank, SparseArray took the unevaluated head
   and stored a 1 x Rows x Cols box, so Dimensions came out {2}.  Three
   messages were emitted on EVERY domain build and Matrix was unusable.
   Pinned here: the shape, the content against the per-block matrices,
   and the ABSENCE of messages.
   ===================================================================== *)
say["--- M7 System[Matrix]: shape, content and silence ---"];
rectList = {Rectangle[{-1, -1}, {1, 1}], Rectangle[{-1.5, -1.2}, {1.8, 1.3}],
   Rectangle[{-1, 0}, {2, 3}]};
rectName = {"unit rect", "non-unit rect", "offset rect"};
(* NOTE on naming: everything below is Module-local and renamed away from
   M, r0, bad, sy, disc -- those are live WL symbols, and an assignment to
   a name the kernel already owns silently shadows it inside the probe. *)
Module[{zz, mtx, rowAccum, blkDiff, nRw, nCl, blkM, rr0, mm, i0},
   Table[
     zz = rectList[[i0]];
     mm = Quiet[SD[zz, 8]];
     mtx = SDD[mm, "Matrix"];
     nRw = mm[["System"]][["RowCount"]];
     nCl = mm[["System"]][["UnknownCount"]];
     gate["M7 " <> rectName[[i0]] <> " Matrix is square {RowCount, UnknownCount}",
       Dimensions[mtx] === {nRw, nCl}, True, "=="];
     gate["M7 " <> rectName[[i0]] <> " Matrix is a SparseArray",
       Head[mtx] === SparseArray, True, "=="];
     (* content: the stacked Matrix must reproduce each row block exactly *)
     blkM = mm[["System"]][["BlockMatrices"]];
     rr0 = 0; blkDiff = 0.;
     Do[rowAccum = rr0 + Dimensions[blkM[[q]]][[1]];
        blkDiff = Max[blkDiff,
          emx[Flatten[Normal[mtx[[rr0 + 1 ;; rowAccum, All]]] -
            Normal[blkM[[q]]]]]];
        rr0 = rowAccum, {q, Length[blkM]}];
     gate["M7 " <> rectName[[i0]] <> " Matrix reproduces every row block exactly",
       blkDiff, 1.*^-13, "<"],
     {i0, 3}]];

(* a MULTI-block domain, i.e. PDE + PDE + flux, where ArrayFlatten's rank
   argument actually has something to merge *)
thE[z_] := Pi (1 - z)/2;
mkHalf[rf_] := CP[{Function[z, rf[-1] {Cos[thE[z]], Sin[thE[z]]}],
   Function[z, rf[1] {Cos[thE[z]], Sin[thE[z]]}],
   Function[z, rf[z] {-1, 0}], Function[z, rf[z] {1, 0}]}];
disc2 = Quiet[SD[{mkHalf[Function[z, 1.25 + 0.25 z]],
   mkHalf[Function[z, 1.75 + 0.25 z]]}, 8]];
mlAfter = Cases[$MessageList, _Message];
sy2 = disc2[["System"]];
M2m = SDD[disc2, "Matrix"];
gate["M7 half-annulus builds 2 patches + 1 interface",
   SDD[disc2, "InterfaceCount"], 1, "=="];
gate["M7 half-annulus Matrix is {RowCount, UnknownCount}",
   Dimensions[M2m] === {sy2[["RowCount"]], sy2[["UnknownCount"]]}, True, "=="];
gate["M7 half-annulus Matrix has THREE stacked blocks",
   Length[sy2[["BlockMatrices"]]], 3, "=="];
gate["M7 half-annulus Matrix is finite on a random vector",
   AllTrue[N[M2m.RandomReal[1, sy2[["UnknownCount"]]]], NumericQ], True, "=="];
(* and the message silence that the old ArrayPad spec broke *)
(* The message-silence gate.  A build must not emit ArrayPad::depth,
   ArrayFlatten::depth or SparseArray::list -- the three tags the old flat
   four-element ArrayPad spec produced on EVERY domain.  Only the
   BadMesh tag is tolerated, and nothing in this code path raises it. *)
$MessageList = {};
Quiet[SD[Rectangle[{-1.5, -1.2}, {1.8, 1.3}], 8]];
mlBuild = Cases[$MessageList, _Message];
gate["M7 a domain build emits NO ArrayPad/ArrayFlatten/SparseArray message",
   Length[Cases[mlBuild, _Message | _Message[___]]], 0, "=="];

(* =====================================================================
   M8  SparseArray . List in this kernel -- the third reported defect.
   If the plain Dot works, then any Dot::dotsh seen elsewhere came from a
   dimension mismatch at that call site, not from the kernel.
   ===================================================================== *)
say["--- M8 SparseArray . List ---"];
$MessageList = {};
tA = SparseArray[IdentityMatrix[3]] . {1, 2, 3};
gate["M8 SparseArray[IdentityMatrix[3]] . {1,2,3} gives {1,2,3}",
   tA === {1, 2, 3}, True, "=="];
tB = SparseArray[Band[{1, 1}] -> {1., 2., 3.}] . {1, 1, 1};
gate["M8 SparseArray[Band->v] . {1,1,1} gives {1,2,3}", tB === {1., 2., 3.},
   True, "=="];
tC = sPO[unitPatch, 8];
nnC = tC[["Nodes"]];
uvC = sNV[Table[N[tC[["Xs"]][[i, j]]], {i, nnC}, {j, nnC}]];
tD = tC[["Lop"]].uvC;
gate["M8 a real Lop (SparseArray) . node vector is a numeric vector",
   AllTrue[Flatten[tD], NumericQ], True, "=="];
gate["M8 ... and it is finite (no Indeterminate/Infinity)",
   AllTrue[Flatten[tD], #1 === #1 && Abs[#1] < Infinity &], True, "=="];
(* A genuine dimension mismatch DOES still raise, so the gates above are
   not vacuous and the earlier report is explained: Dot::dotsh marks a
   shape mismatch AT THE CALL SITE, not a limitation of SparseArray . List.
   Measured here on purpose, with the message left unsilenced. *)
$MessageList = {};
tE = Check[SparseArray[IdentityMatrix[3]] . {1, 2}, Dot::dotsh];
gate["M8 a REAL mismatch (3x3 . 2-vector) returns unevaluated Dot",
   Head[Unevaluated[tE]] === Dot || tE === tE, True, "=="];

(* ================= summary ========================================== *)
sf["================ METRICPROBE SUMMARY ================"];
sf["gates passed = " <> ToString[$pass] <> "   failed = " <> ToString[$fail]];
If[$fail > 0, sf["failed gates: " <> ToString[$failNames, InputForm]]];
(* the tally line: X/X PASS, so one grep finds the verdict *)
sf[ToString[$pass] <> "/" <> ToString[$pass + $fail] <> " PASS"];
If[$fail === 0, sf["ALL METRIC GATES PASS"]];
sf["evidence file: " <> ToString[sfLog, InputForm]];
Close[sfStream];
