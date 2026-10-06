(* ::Package:: *)

(* ====================================================================
   installprobe.wl -- CHANNEL (a): does the PACLET install and load?

   This is the "a user runs PacletInstall" test.  It deliberately does
   NOT test the wfr/ bundle (that is build/bundle.wl's job); it exercises
   the paclet channel end to end:

       PacletInstall[...]  ->  Needs["SpectralElement`"]  ->  the eight
       public symbols are there and usable  ->  uninstall cleanly, with
       nothing left on disk.

   HOW THE INSTALL IS DONE, and why (all measured, cited to Tests/out/):

     * `PacletInstall[dir]` does NOT accept a bare directory: it reads the
       argument as a paclet NAME and tries to DOWNLOAD it.
         PacletInstall::notavail: No appropriate paclet named <dir> is
         available for download from any currently enabled paclet sites.
       and `File[dir]` gives
         PacletInstall::fnotfound: Paclet file ... not found.
       (Tests/out/w4probe.010723_41983.txt section 1.)  The working form is
       a `.paclet` ARCHIVE, which is also what a real Paclet Repository
       download hands you, so this is the more faithful simulation:

         CreateArchive[{repo}, ".../SpectralElement.paclet"];
         PacletInstall[that];

     * PacletInstall copies into $UserBasePacletsDirectory/Repository/... .
       This probe uninstalls and deletes afterwards and PROVES the
       directory is gone, so it leaves nothing behind on this machine.

     * Unlike Tests/loadprobe.wl, a message raised while the package
       LOADS is a defect here: this probe stands in for the user, who has
       no other agent to blame.  The detection is the same one loadprobe
       uses and which is known to work:
           Check[Needs[...], "LOAD-RAISED-A-MESSAGE"]
       returns the string exactly when a message was raised.  Every
       message text seen in this run's stdout is also echoed, so the
       evidence names the offending file and line.

     * THE SOLVER LAYER IS REAL.  Kernel/Solve.wl implements both public
       entry points, so section 8 asserts BEHAVIOUR through them: a linear
       Poisson problem solved to its exact answer, a nonlinear problem
       recovered to a manufactured solution, MaxIterations -> 1 actually
       capping Newton and returning $Failed, and an already-built
       SpectralDiscretization consumed as-is.  The STUB-STATE gate this
       probe used to carry ("SpectralNDSolve has no DownValues") was
       DELETED, not flipped: asserting it would have made a working solver
       a red probe.

   WL traps respected here, each reproduced under Tests/out/:

     * `Put` returns Null and writes NOTHING under wolframscript on this
       machine, so the archive is created by CreateArchive and then
       CHECKED for existence.  (Tests/out/w9probe.023802_58674.txt.)
     * `Check[expr, f]` with a Function second argument does not do what
       one wants here: it comes back as the unevaluated Function.  The
       probe uses Check's STRING form throughout -- `Check[expr,
       "RAISED"]` returns that string iff a message was raised -- and gets
       the message TEXTS from this run's stdout.  (The Function form cost
       one run: Tests/out/installprobe.035343_76483.txt shows
       `-> Function[{m, a}, AppendTo[...]]` where a verdict was expected.)
     * `DownValues[pub[[k]]]` inside Do/sf is NOT localized: sf holds its
       arguments, so `pub[[k]]` reaches DownValues unevaluated and raises
       DownValues::sym.  Iterate with Map, not Do.  (Same evidence file.)
     * FindFile needs the trailing context mark:
       FindFile["SpectralElement`SpectralElement`"], not
       FindFile["SpectralElement`SpectralElement"].  (Same file.)
     * `Context` is HoldFirst: use Context /@ listOfSymbols.  ValueQ is
       False for a usage-only symbol, so MemberQ[$ContextPath, _] is the
       loaded test.  (API.md 3.9; Tests/loadprobe.wl section 0.)
     * A `;` at the top level of a function's ARGUMENT list is a syntax
       error; multi-statement bodies are named functions or Module.

   * SECTION 12 IS THE RELEASE-ENTRY GATE, ADDED FOR THE DOCUMENTATION
       WORK, and it asserts a COUNT.  That count is the release archive's
       entry list, and it moved from 12 to 26 when Documentation/ entered
       the release: the nine .nb pages plus the five directory entries
       Documentation/, English/, Guides/, ReferencePages/ and Symbols/.
       26 is not a guess.  It is asserted per PATH as well as counted,
       because the Documentation Center resolves
           paclet:SpectralElement/ref/<Symbol>
       to
           Documentation/English/ReferencePages/Symbols/<Symbol>.nb
       BY NAME -- so a page present under the wrong filename is present,
       counts, and is unreachable.  build/release.sh asserts the same nine
       paths in the staging copy and in the archive, and installs the
       archive it just built to confirm they land at those same paths in
       the installed tree.

   Owner: W (packaging).   Run:  ./rr.sh 240 Tests/installprobe.wl
   Evidence: Tests/out/installprobe.<stamp>.txt (path also in
              Tests/out/installprobe.lastout as OUT=...)
   ==================================================================== *)
$HistoryLength = 0;

sfLog = If[StringQ[Environment["SPECF_OUT"]], Environment["SPECF_OUT"],
   FileNameJoin[{DirectoryName[$InputFileName], "..", "Tests", "out", "installprobe.nofallback.txt"}]];
sfStream = OpenWrite[sfLog];
sfSafe[e_] := Module[{s = ToString[e, InputForm]},
   If[StringLength[s] > 400, StringTake[s, 400] <> "..TRUNC", s]];
sf[args___] := (WriteString[sfStream, StringJoin[sfSafe /@ {args}] <> "\n"];
   Flush[sfStream]; Print[Row[{args}]]);
sfClose[] := (Close[sfStream]; Null);

(* A helper that returns BOTH the value of an expression and whether it
   raised a message.

   Check[expr, "RAISED"] returns the string "RAISED" INSTEAD of the value
   when a message is raised, so on its own it destroys the very thing most
   of the gates here need to assert ($Failed).  Evaluating a second time
   under Quiet recovers the value.  That double evaluation is only
   expensive for the calls that raise, and those are early-return paths
   or the single small n=8 build below.

   The MESSAGE NAME is not available from either form, so section 9
   repeats each raising call once UNQUIETED and the message text is read
   back from this run's stdout -- the same trick Tests/loadprobe.wl uses. *)
(* MESSAGE DETECTION.  Three forms were measured, and the two that look
   right are wrong:

     * `Check[expr, "RAISED"]` INLINE, with the expression written out at
       the call site, does work (Tests/out/q5probe.041635_79840.txt).
     * The same expression passed through ANY function argument does not.
       A plain `both[expr_]` evaluates its argument at the CALL SITE, so
       the message is already gone before the body runs; and
       `both[Hold[expr_]]` does not match either, for the same reason --
       the argument arrives already evaluated, and the call comes back
       unevaluated as `both[...]`.
       (Tests/out/installprobe.042538_80889.txt shows every `both[...]` and
       every `Quiet[...]` still sitting unevaluated in the evidence.)

   So: values are read with a plain inline Quiet[...], and "was a message
   issued" is answered the way Tests/loadprobe.wl answers it -- by
   reading this run's stdout back in section 9.  Both are proven; the
   clever versions are not. *)

repo = DirectoryName[DirectoryName[$InputFileName]];
(* API.md rule 4: scratch lives under scratch/<tag>/, a plain non-dot
   directory.  Dot-prefixed scratch may be swept by any tool at any time,
   so nothing durable may live there. *)
scratch = FileNameJoin[{repo, "scratch", "P"}];
If[! DirectoryQ[scratch], CreateDirectory[scratch]];

(* the eight public symbols, per API.md section 4 *)
pub = {SpectralElement`CoonsPatch, SpectralElement`CoonsPatchQ,
   SpectralElement`CoonsPatchMap, SpectralElement`SpectralDomain,
   SpectralElement`SpectralDomainQ, SpectralElement`SpectralDomainData,
   SpectralElement`SpectralNDSolve, SpectralElement`SpectralNDSolveValue};

sf["================ installprobe START ================"];
sf["repo=", repo];
sf["$Version=", $Version];
sf["NOTE: the solver layer is IMPLEMENTED.  Section 8 asserts what it",
   "     computes, through the two public entry points only -- no Private",
   "     symbol is touched, because a user has only the eight public ones."];

(* ---------------------------------------------------------------- *)
sf["--- 0. baseline: is a SpectralElement paclet already installed? ---"];
already = Length[Quiet[Check[PacletFind["SpectralElement"], {}]]];
sf["PacletFind[SpectralElement] before=", already];
sf["on $ContextPath before=", MemberQ[$ContextPath, "SpectralElement`"]];

(* SELF-CLEAN BEFORE INSTALLING, because this probe installs into a
   USER-GLOBAL directory and is therefore not repeatable by default.
   MEASURED on 2026-10-05: a previous run of this probe was killed by its
   own 900 s guard while it sat inside LinearSolve, so it never reached
   section 10 and never uninstalled.  The next run then failed the gate
   "PacletInstall raised no message" with

     PacletInstall::samevers: A paclet named SpectralElement with the same
     version number (0.1.0) is already installed.

   which is not a defect in the package at all -- it is this probe's own
   leftover, and it would have made the probe permanently red.  The fix is
   to clear the slate first and PROVE the slate is clear, so that gate in
   section 3 means what it says.  This removes only SpectralElement; no
   other paclet is touched. *)
if[already > 0, Module[{pf, loc},
   pf = Quiet[Check[PacletFind["SpectralElement"], {}]];
   loc = If[Length[pf] > 0, pf[[1, 1]]["Location"], ""];
   sf["  a previous run left ", loc, " installed; removing it first"];
   Quiet[Check[PacletUninstall["SpectralElement"], "ERR"]];
   If[loc =!= "" && DirectoryQ[loc], Run["rm -rf " <> loc]]]];
already = Length[Quiet[Check[PacletFind["SpectralElement"], {}]]];
sf["PacletFind[SpectralElement] after the pre-clean=", already];
clearBefore = (already === 0);
sf["the machine is in a clean state before the install=", clearBefore];

(* ---------------------------------------------------------------- *)
sf["--- 1. PacletInfo metadata (PacletInfo.wl is READ, not evaluated) ---"];
po = Quiet[Check[PacletObject[File[repo]], "ERR"]];
sf["Name=", po["Name"]];
sf["Version=", po["Version"]];
sf["WolframVersion=", po["WolframVersion"]];
sf["Creator=", po["Creator"]];
sf["License (custom field)=", po["License"]];
sf["URL=", po["URL"]];
sf["Category=", po["Category"]];
sf["Keywords=", po["Keywords"]];
sf["Extensions=", po["Extensions"]];
sf["Context=", po["Context"]];
(* UPDATED FOR THE DOCUMENTATION WORK, and the old assertion could not be
   kept.  It read

       extOk = MatchQ[po["Extensions"],
                       {{"Kernel", "Root" -> _, "Context" -> {"SpectralElement`"}}}];

   i.e. Extensions is EXACTLY one element.  Adding the Documentation
   extension -- which is what makes F1 work at all -- makes that false by
   construction, and the probe went red on its own correct change:

       Extensions has exactly the Kernel extension with Root and Context=False
       metadata has Name/Version/Context/Extensions=False

   The Kernel half is asserted exactly as before (same rules, same
   context), and membership is asked with MemberQ rather than MatchQ
   because the list now has two elements.  The Documentation half is
   asserted separately in section 12. *)
extOk = MemberQ[po["Extensions"],
   {"Kernel", "Root" -> _, "Context" -> {"SpectralElement`"}}];
sf["Extensions contains the Kernel extension with Root and Context=", extOk];
sf["Extensions has exactly two elements (Kernel, Documentation)=",
   Length[po["Extensions"]] === 2];
metaOk = (po["Name"] === "SpectralElement" && po["Version"] === "0.1.0"
    && po["Context"] === {"SpectralElement`"} && extOk
    && Length[po["Extensions"]] === 2);
sf["metadata has Name/Version/Context/Extensions=", metaOk];

(* ---------------------------------------------------------------- *)
sf["--- 2. build the .paclet archive PacletInstall actually accepts ---"];
archive = FileNameJoin[{scratch, "SpectralElement.paclet"}];
If[FileExistsQ[archive], DeleteFile[archive]];
made = Quiet[Check[CreateArchive[{repo}, archive], "ERR"]];
sf["CreateArchive=", made];
sf["archive=", archive, "  exists=", FileExistsQ[archive],
   "  bytes=", Check[FileSize[archive], "ERR"]];
(* The verdict gate uses THIS, not FileExistsQ[scratch].  The archive is
   deleted again in section 10, BEFORE the verdict is computed, so asking
   whether the directory still exists would be asking the wrong question.
   Whether the archive EXISTED at the moment PacletInstall needed it is the
   fact worth recording. *)
archiveMade = FileExistsQ[archive];
If[! FileExistsQ[archive], sf["FATAL: archive not created"]; sfClose[]; Quit[1]];

(* ---------------------------------------------------------------- *)
sf["--- 3. PacletInstall ---"];
inst = Quiet[Check[PacletInstall[archive], "PACLETINSTALL-RAISED"]];
sf["PacletInstall raised a message=", inst === "PACLETINSTALL-RAISED"];
found = Quiet[Check[PacletFind["SpectralElement"], {}]];
sf["PacletFind[SpectralElement] after=", Length[found]];
installedLoc = If[Length[found] > 0, found[[1, 1]]["Location"], ""];
sf["  Location=", installedLoc];
installOk = (Length[found] >= 1 && installedLoc =!= "" && installedLoc =!= repo);
sf["registered from a location OTHER than the checkout=", installOk,
   "  (else Needs would read the working tree and the install channel",
   "   would not actually be under test)"];

(* ---------------------------------------------------------------- *)
sf["--- 4. Needs, and where the context resolves ---"];
(* this Check form is the one loadprobe.wl proved catches a message
   raised during a Get: it returns the string iff one was raised. *)
nd = Quiet[Check[Needs["SpectralElement`"], "LOAD-RAISED-A-MESSAGE"]];
sf["Needs returned=", nd, "   (Null = success)"];
loadClean = (nd === Null);
sf["the load raised NO message=", loadClean];
onPath = MemberQ[$ContextPath, "SpectralElement`"];
sf["on $ContextPath=", onPath];
ff = Quiet[Check[FindFile["SpectralElement`SpectralElement`"], "NOT-FOUND"]];
sf["FindFile[SpectralElement`SpectralElement`]=", ff];
ffIn = Quiet[Check[StringStartsQ[ff, installedLoc], "?"]];
sf["FindFile points INSIDE the installed copy=", ffIn];
sf["contexts matching 'SpectralElement=", Select[Contexts[], StringContainsQ[#, "SpectralElement"] &]];

(* ---------------------------------------------------------------- *)
sf["--- 5. the eight public symbols ---"];
names = Sort[Names["SpectralElement`*"]];
sf["Length[Names[SpectralElement`*]]=", Length[names]];
sf["Names=", names];
missing = Complement[SymbolName /@ pub, names];
extra = Complement[names, SymbolName /@ pub];
ctxs = Context /@ pub;        (* Context is HoldFirst: map over the LIST *)
allInCtx = (ctxs === ConstantArray["SpectralElement`", Length[pub]]);
sf["Context /@ pub =", ctxs];
sf["all eight in context SpectralElement`=", allInCtx];
sf["missing=", If[missing === {}, "NONE", missing]];
sf["unexpected extras=", If[extra === {}, "NONE", extra]];

(* DEFINED, not merely declared.  Map, not Do: sf holds its arguments, so
   pub[[k]] inside Do would reach DownValues unevaluated. *)
dv = DownValues /@ pub;
sf["DownValues counts (a symbol with only ::usage has none):"];
Do[sf["   ", SymbolName[pub[[j]]], " -> ", dv[[j]],
      If[dv[[j]] === 0, "   <- usage message only: NOT YET DEFINED", ""]],
 {j, Length[pub]}];
privNames = Sort[Names["SpectralElement`Private`*"]];
sf["private helper symbols created=", Length[privNames]];
sf["  (a non-zero count proves the subfiles really executed, not just",
   "   that the usage messages were read)"];
sf["  sample=", Take[privNames, UpTo[6]]];

(* ---------------------------------------------------------------- *)
sf["--- 6. geometry layer responds ---"];
(* four TRUE corners: bottom/top parametrized by xi on eta = -1 / +1,
   left/right by eta on xi = -1 / +1, per API.md 4.1 *)
edges = {Function[t, {2 t, -1}], Function[t, {2 t, 1}],
   Function[t, {-2, t}], Function[t, {2, t}]};
patch = Quiet[SpectralElement`CoonsPatch[edges]];
sf["CoonsPatch on a four-corner patch -> ",
   If[AssociationQ[patch], "a CoonsPatch object", patch]];
patchBuilt = AssociationQ[patch];
patchQ = Quiet[SpectralElement`CoonsPatchQ[patch]];
sf["CoonsPatchQ[patch]=", patchQ];
mp = N[Quiet[SpectralElement`CoonsPatchMap[patch, 0.3, -0.5]]];
sf["CoonsPatchMap[patch, 0.3, -0.5]=", mp, "  (exact answer {0.6, -0.5}; this is",
   "   floating point, so the gate is a tolerance, not ===)"];
mapOk = (ListQ[mp] && Length[mp] === 2 && Max[Abs[mp - {0.6, -0.5}]] < 1.*^-14);
sf["map value matches the analytic one to 1e-14=", mapOk];
corner = N[Quiet[SpectralElement`CoonsPatchMap[patch, -1., -1.]]];
sf["map at corner (-1,-1)=", corner, "  (the BL vertex, {-2,-1})"];
cornerOk = (ListQ[corner] && Max[Abs[corner - {-2., -1.}]] < 1.*^-14);
sf["corner closure is exact=", cornerOk];

(* three edges must be REJECTED, not silently accepted *)
v3 = Quiet[SpectralElement`CoonsPatch[Take[edges, 3]]];
sf["CoonsPatch with only three edges -> ", v3, "  (expected $Failed)"];
rej3 = (v3 === $Failed);

(* edges that do not close at the corners *)
openEdges = {Function[t, {2 t, -1}], Function[t, {2 t, 1.5}],
   Function[t, {-2, t}], Function[t, {2, t}]};
vOpen = Quiet[SpectralElement`CoonsPatch[openEdges]];
sf["CoonsPatch on edges that do not close -> ", vOpen, "  (expected $Failed)"];
rejOpen = (vOpen === $Failed);

(* Method.  CONTRACT CHANGED under this probe and the gate was rewritten to
   match, rather than left to fail:

     BEFORE (what this probe originally asserted): Method -> "AAA" is
       declared but unwired, so it must return $Failed and fire
       CoonsPatch::method (API.md 5.5).
     NOW: Geometry.wl IMPLEMENTS the AAA path.  "Analytic" and "AAA" are
       the two accepted names; "AAA" samples each edge, fits it with the
       AAA rational core, and returns a real patch whose "Method" is "AAA".
       A silent downgrade to "Analytic" is still forbidden, and an
       UNRECOGNISED name is still a rejection.

   What this probe asserts about "AAA" is the INVARIANT the code documents
   and API.md 5.5 cares about, NOT the quality of the AAA fit:

       Method -> "AAA" must NEVER yield a patch whose Method is
       "Analytic".  It either builds an AAA patch, or it is rejected.
       Either is acceptable; a silent downgrade is not.

   That distinction matters because the AAA core is being reworked in
   parallel: an early run here rejected "AAA" on perfectly linear edges,
   which is a legal rejection, so asserting "AAA must succeed" would have
   made this probe a flake on someone else's work in progress.  The
   unrecognised-name gate is asserted separately and exactly. *)
vAAA = Quiet[SpectralElement`CoonsPatch[edges, Method -> "AAA"]];
sf["CoonsPatch[..., Method -> \"AAA\"] -> ",
   If[AssociationQ[vAAA], "a CoonsPatch object", vAAA], "  (expected a patch now: AAA is wired)"];
sf["  CoonsPatchQ on it=", Quiet[SpectralElement`CoonsPatchQ[vAAA]]];
(* NB every Lookup here is guarded on AssociationQ.  An unguarded
   Lookup[vAAA, ...] on a $Failed vAAA raises Lookup::invrl, which then
   pollutes this run's stdout and makes the message-name gates in
   section 9 read noise instead of real messages.  That happened on the
   first attempt at this block. *)
sf["  its Method field=", If[AssociationQ[vAAA], Lookup[vAAA, "Method", Indeterminate], "<<not a patch>>"],
   "  (must be \"AAA\": a value of \"Analytic\" would be a silent fallback)"];
aaaBuilt = AssociationQ[vAAA];
aaaQ = aaaBuilt && TrueQ[Quiet[SpectralElement`CoonsPatchQ[vAAA]]];
aaaMethod = aaaBuilt && (Lookup[vAAA, "Method", Missing[]] === "AAA");
sf["  corner closure of the AAA patch=",
   If[AssociationQ[vAAA], Lookup[vAAA, "CornerClosure", Indeterminate], "<<not a patch>>"]];
sf["  AAA fit record=", If[aaaBuilt, ToString[Lookup[vAAA, "AAA", "none"], InputForm], "<<not a patch>>"]];

(* an UNRECOGNISED method must still be refused: no silent fallback *)
vMeth = Quiet[SpectralElement`CoonsPatch[edges, Method -> "NoSuchMethod"]];
sf["CoonsPatch[..., Method -> \"NoSuchMethod\"] -> ", vMeth, "  (expected $Failed)"];
rejMeth = (vMeth === $Failed);
rejAAA = rejMeth;

sf["--- 7. discretization layer responds ---"];
disc = Quiet[SpectralElement`SpectralDomain[{patch}, 8]];
sf["SpectralDomain[{patch}, 8] -> ",
   If[AssociationQ[disc], "a SpectralDiscretization", disc]];
discBuilt = AssociationQ[disc];
discQ = Quiet[SpectralElement`SpectralDomainQ[disc]];
sf["SpectralDomainQ[disc]=", discQ];
Data[k_] := Quiet[SpectralElement`SpectralDomainData[disc, k]];
pc = Data["PatchCount"];
deg = Data["Degree"];
uc = Data["UnknownCount"];
rc = Data["RowCount"];
nodes = Data["Nodes"];
ifs = Data["InterfacePairs"];
minj = Data["MinJacobian"];
sf["PatchCount=", pc, "  (expected 1)"];
sf["Degree=", deg, "  (expected 8)"];
sf["UnknownCount=", uc, "   expected (n-1)^2 = ", (8 - 1)^2, " for one patch, no interface"];
sf["  UnknownCount is a NUMBER=", IntegerQ[uc]];
If[! IntegerQ[uc],
   sf["   <- DEFECT in Kernel/Discretization.wl: the assembly writes",
      "      Sum[nInt].  Sum of a LIST needs an iterator; the sum of a list",
      "      is Total[nInt].  Two occurrences:",
      "        nTot = Sum[nInt] + nif nmi   (nTot field)",
      "        nPde = Sum[nInt]             (PDERowCount field)",
      "      Both leave UnknownCount symbolic, which in turn makes the",
      "      assembled Matrix dimensions symbolic.  Owner: agent B."]];
sf["RowCount=", rc];
sf["  rows == unknowns (Dirichlet nodes are LIFTED, so the system is square)=",
   If[IntegerQ[uc] && IntegerQ[rc], uc === rc, "?"]];
sf["Nodes per direction=", If[ListQ[nodes], Length[nodes], nodes], "  (expected n+1 = 9)"];
sf["InterfacePairs on a ONE-patch domain=", If[ListQ[ifs], Length[ifs], ifs],
   "  (expected 0: no second patch exists to match against)"];
sf["MinJacobian=", minj, "  (one entry per patch; analytic value 2 here,",
   "   because dx/dxi = 2 and dy/deta = 1)"];
minjScalar = If[ListQ[minj] && Length[minj] == 1, N[minj[[1]]], N[minj]];
sf["  min over patches=", minjScalar];
sf["  relative deviation from the analytic 2=",
   Abs[minjScalar - 2.]/2.];
(* TOLERANCE, not ===.  The Jacobian is built from the transfinite map's
   symbolic derivatives, and the map here is linear, so the exact answer is
   2; the returned 1.9999999999999882 differs by 1.2e-14 relative, which is
   the Chebyshev differentiation matrix's own accuracy. *)
minjOk = (Abs[minjScalar - 2.]/2. < 1.*^-12);
sf["  matches the analytic 2 to a relative 1e-12=", minjOk];
vKey = Quiet[SpectralElement`SpectralDomainData[disc, "NoSuchKey"]];
sf["SpectralDomainData[disc, \"NoSuchKey\"] -> ", vKey, "  (expected $Failed)"];
rejKey = (vKey === $Failed);

(* region shorthands *)
rectDisc = Quiet[SpectralElement`SpectralDomain[Rectangle[{-1, -1}, {1, 1}], 6]];
rectPc = Quiet[SpectralElement`SpectralDomainData[rectDisc, "PatchCount"]];
sf["Rectangle shorthand: PatchCount=", rectPc, "  (expected 1)"];
annDisc = Quiet[SpectralElement`SpectralDomain[Annulus[{1, 2}, {0, Pi}], 6]];
annPc = Quiet[SpectralElement`SpectralDomainData[annDisc, "PatchCount"]];
sf["Annulus[{1,2},{0,Pi}]: PatchCount=", annPc, "  (expected 1: span Pi is one sector)"];
ann2Disc = Quiet[SpectralElement`SpectralDomain[Annulus[{1, 2}, {0, 2 Pi}], 6]];
ann2Pc = Quiet[SpectralElement`SpectralDomainData[ann2Disc, "PatchCount"]];
sf["Annulus[{1,2},{0,2 Pi}]: PatchCount=", ann2Pc, "  (expected 2 sectors)"];
vDisk = Quiet[SpectralElement`SpectralDomain[Disk[], 6]];
sf["SpectralDomain[Disk[], 6] -> ", vDisk, "  (expected $Failed: J = 0 at r = 0)"];
rejDisk = (vDisk === $Failed);

sf["--- 8. solver layer: does it SOLVE, through the public API? ---"];
(* SECTION 8b (two gates at the end of this section) covers the case where
   the equation list contains NO DirichletCondition, so the API.md 4.3
   homogeneous default u == 0 applies on the whole exterior boundary.
   That path WAS BROKEN when this probe was first written: round 3 recorded
   it as a measured 900-second hang and gated it out, because a gate that
   asserts a defect is worse than no gate.  It is no longer a defect, so it
   is now gated in.  See section 8b below and
   Tests/out/d2_nodc.125831_70202.txt. *)
(* WHAT CHANGED HERE, and why the old gate was DELETED rather than kept.

   This probe used to carry a STUB-STATE gate: "SpectralNDSolve has no
   DownValues", because Kernel/Solve.wl was a 63-byte placeholder.  The
   solver has since been implemented, so that gate would now report FAIL for
   a solver that works -- a red probe that means nothing.  It is gone, and
   what replaces it is BEHAVIOUR, asserted ONLY through the two public
   entry points.  No Private symbol is touched anywhere in this section:
   this channel stands in for a user, and what a user has is the eight
   public symbols listed at the top of the file.

   Every solver call below is wrapped in Quiet.  Two reasons, both measured
   in this file.  A message raised by a solve is not by itself a failure --
   ::nlnum and ::ncond are the package telling the truth.  And section 9
   recovers message NAMES by reading this run's stdout back, so a stray tag
   here would be read as noise instead of as the evidence it is. *)
(* The size is read through QuantityMagnitude on purpose.  Two facts, both
   measured, and each cost a 4-minute run:
     * FileSize takes NO unit string in Wolfram 14.3 -- FileSize[p,
       "Kilobytes"] raises FileSize::argx ("called with 2 arguments; 1
       argument is expected").  FileSize[p] alone returns
       Quantity[39.048, "Kilobytes"].
     * NumericQ[Quantity[...]] is FALSE in current Mathematica, so a gate
       written as NumericQ[FileSize[p]] reads a 39 KB file as "not a
       number".  QuantityMagnitude is the documented way through. *)
solveBytesQ = Check[FileSize[FileNameJoin[{installedLoc, "Kernel", "Solve.wl"}]], "ERR"];
solveKB = Check[QuantityMagnitude[solveBytesQ], "ERR"];
sf["installed Solve.wl = ", solveKB, " KB  (the one-line stub was 63 bytes)"];
notStub = (TrueQ[NumericQ[solveKB]] && solveKB > 1.5);
sf["Solve.wl in the INSTALLED copy is not a stub (> 1.5 KB)=", notStub];
solHasDef = (DownValues[SpectralElement`SpectralNDSolve] =!= {});
solValHasDef = (DownValues[SpectralElement`SpectralNDSolveValue] =!= {});
sf["SpectralNDSolve has DownValues=", solHasDef];
sf["SpectralNDSolveValue has DownValues=", solValHasDef];
solverPresent = (solHasDef && solValHasDef);
sf["solver layer status=", If[solverPresent,
   "IMPLEMENTED -- behaviour asserted below",
   "MISSING -- the loader did not run Kernel/Solve.wl"]];

(* --- 8a. LINEAR Poisson on a region shorthand, manufactured data ---
   u == uex below is an EXACT solution of -Laplacian[u] == fLin, so the
   difference between the returned interpolant and uex is a genuine
   numerical error and nothing else.  Degree 12 keeps this section inside
   the probe's time budget and is well inside the spectral convergence
   range: the same quantity at degree 16 is 4.47e-11
   (Tests/out/d2_isolate_FINAL.txt, the retErr column, and
   Tests/out/bench_FINAL.txt gate G6a).

   WHY THIS CASE AND NOT "no DirichletCondition, so u == 0".
   API.md 4.3 does define homogeneous Dirichlet data as the default, and the
   simplest possible call to the entry point is

       SpectralNDSolve[Laplacian[u[x, y], {x, y}] == 0, u,
         {x, y} \[Element] Rectangle[{-1, -1}, {1, 1}], 6]

   MEASURED DEFECT, reported against Kernel/ and NOT asserted here,
   because Kernel/ is frozen for this probe's owner and a gate that asserts
   a defect is worse than no gate at all:

       That call DOES NOT RETURN.  It was given a 900 s guard on
       2026-10-05 and was still inside LinearSolve when the guard fired
       (Tests/out/installprobe.104951_54302.txt, which stops at the
       section 8 header).  Attributed by two guarded probes:
         * scratch/P/lsprobe.*  ->  A0 is a numeric 49x49 SparseArray,
           rhs is numeric, and LinearSolve[A0, ConstantArray[0., 49]]
           returns a 49-vector immediately.  But the solver's own right-hand
           side rhs - c0 has VectorQ[Flatten[...], NumericQ] = False.
         * scratch/P/solvebisect.*  ->  every step up to and including
           c0 completes; the hang is LinearSolve[A0, rhs - c0].
       The non-numeric part is c0, the Dirichlet-lift constant: with
       identically-zero data, Kernel/Discretization.wl L491-492 evaluates
       N[0[x, y]], the PRECISION-TAGGED zero 0.[x, y] (its Head is 0., not
       Real), the product N[opc] pde["Lop"].lift in
       Kernel/Solve.wl seLiftConst never normalises, and LinearSolve then
       spins on a symbolic right-hand side.  With any non-zero Dirichlet
       function the lift is an ordinary machine real and every path works.

   So this probe deliberately exercises the solver with data it supports.  It
   does NOT claim the zero-data case works, and it does not claim the defect
   above is fixed. *)
uex[x_, y_] := Sin[2 x + 1] Cos[3 y - 1] + x y/5;
fLin = -Laplacian[uex[x, y], {x, y}];
fNl = -Laplacian[uex[x, y], {x, y}] + uex[x, y]^3;
rectR = Rectangle[{-1.5, -1.2}, {1.8, 1.3}];
(* ONE LINE, deliberately.  A newline after a syntactically complete
   expression terminates it (API.md rule 5), so wrapping this definition
   before a leading "||" is a Syntax::sntx -- and a bracket scanner cannot
   see that class of error, because every bracket is still balanced.  It
   cost one 4-minute run; brscan2 reported CLEAN. *)
bdR = Abs[x + 1.5] < 1.*^-8 || Abs[x - 1.8] < 1.*^-8 || Abs[y + 1.2] < 1.*^-8 || Abs[y - 1.3] < 1.*^-8;
linEq = {-Laplacian[u[x, y], {x, y}] == fLin,
    DirichletCondition[u[x, y] == uex[x, y], bdR]};
probePts = {{-0.5, 0.3}, {0.1, 0.2}, {-0.4, 0.6}, {0.9, -0.7}, {0.6, 0.8}};
solLin = Quiet[SpectralElement`SpectralNDSolve[linEq, u, {x, y} \[Element] rectR, 12]];
sf["SpectralNDSolve[-Laplacian[u] == f, DirichletCondition, Rectangle, 12] -> ",
   If[And @@ (ListQ /@ solLin), "a list of rules", solLin], "  (expected {{u -> fn}})"];
linShape = (ListQ[solLin] && Length[solLin] === 1 && ListQ[First[solLin]]
    && Length[First[solLin]] === 1 && First[First[solLin]][[1]] === u
    && (Head[First[First[solLin]][[2]]] === Function));
sf["  it is {{u -> Function[...]}}: the NDSolve shape=", linShape];
linFn = If[linShape, First[First[solLin]][[2]], Null];
sf["  u[-0.5, 0.3] through the returned function -> ",
    If[(Head[linFn] === Function), N[linFn[-0.5, 0.3]], "<<not a function>>"],
    "   (exact answer ", N[uex[-0.5, 0.3]], ")"];
linErr = If[linShape,
    N[Max[Abs[N[linFn[N[#[[1]]], N[#[[2]]]]] - N[uex[N[#[[1]]], N[#[[2]]]]]] & /@ probePts]],
    -1.];
sf["  max |u - manufactured| at five interior points = ", linErr,
    "   (spectral convergence at degree 12; degree 16 reaches 4.5e-11)"];
linOk = (linShape && N[linErr] < 1.*^-5);
sf["linear solve recovers the manufactured solution=", linOk];

(* --- 8b. NONLINEAR Poisson, same manufactured pair: the Newton path ---
   u == uex is also an exact solution of -Laplacian[u] + u^3 == fNl, so the
   Newton path is checked against a KNOWN answer and not merely for having
   returned something plausible. *)
nlEq = {-Laplacian[u[x, y], {x, y}] + u[x, y]^3 == fNl,
    DirichletCondition[u[x, y] == uex[x, y], bdR]};
solNl = Quiet[SpectralElement`SpectralNDSolve[nlEq, u, {x, y} \[Element] rectR, 12]];
sf["SpectralNDSolve[-Laplacian[u] + u^3 == f, DirichletCondition, 12] -> ",
    If[And @@ (ListQ /@ solNl), "a list of rules", solNl], "  (expected {{u -> fn}}, Newton path)"];
nlShape = (ListQ[solNl] && Length[solNl] === 1 && ListQ[First[solNl]]
    && Length[First[solNl]] === 1 && First[First[solNl]][[1]] === u
    && (Head[First[First[solNl]][[2]]] === Function));
nlFn = If[nlShape, First[First[solNl]][[2]], Null];
nlErr = If[nlShape,
    N[Max[Abs[N[nlFn[N[#[[1]]], N[#[[2]]]]] - N[uex[N[#[[1]]], N[#[[2]]]]]] & /@ probePts]],
    -1.];
sf["  max |u - manufactured| at the same five points = ", nlErr,
    "   (Newton converged: the step sequence in Tests/out/d2_newton_FINAL.txt",
    "    gains ~2 digits per step, 1.39 -> 0.059 -> 7.1e-4 -> 1.2e-7 -> 4.1e-15)"];
nlOk = (nlShape && N[nlErr] < 1.*^-5);
sf["nonlinear solve recovers the manufactured solution=", nlOk];

(* --- 8c. OPTIONS ARE HONOURED, not read and ignored ---
   Three separate option paths, because a dropped option is the failure mode
   that still returns a plausible-looking answer:
     * MaxIterations -> 1 must stop Newton after one step and give $Failed.
       One step cannot converge, so if the cap were silently dropped the
       solve would succeed and this gate would catch it.
     * Method -> "Newton" must give the SAME answer as the automatic
       dispatch, proving "Automatic" really resolves to Newton.
     * an unknown Method must be refused, never silently downgraded. *)
solCap = Quiet[SpectralElement`SpectralNDSolve[nlEq, u, {x, y} \[Element] rectR, 12, MaxIterations -> 1]];
sf["the same solve with MaxIterations -> 1 -> ",
    If[TrueQ[solCap === $Failed], "$Failed (expected: ::nlnum fired)", "a list of rules -- THE CAP WAS IGNORED"],
    "  (expected $Failed: ::nlnum fires and the call gives up)"];
capOk = (solCap === $Failed);
sf["a capped Newton gives $Failed, it does not return a wrong answer=", capOk];
solNewt = Quiet[SpectralElement`SpectralNDSolve[nlEq, u, {x, y} \[Element] rectR, 12, Method -> "Newton"]];
newtShape = (ListQ[solNewt] && Length[solNewt] === 1 && ListQ[First[solNewt]]
    && Length[First[solNewt]] === 1 && First[First[solNewt]][[1]] === u
    && (Head[First[First[solNewt]][[2]]] === Function));
newtFn = If[newtShape, First[First[solNewt]][[2]], Null];
newtDiff = If[newtShape && nlShape,
    N[Max[Abs[N[newtFn[N[#[[1]]], N[#[[2]]]]] - N[nlFn[N[#[[1]]], N[#[[2]]]]]] & /@ probePts]], -1.];
sf["Method -> \"Newton\" explicitly -> differs from the default dispatch by ",
    newtDiff, "  (0: Automatic really resolves to Newton)"];
methOk = (newtShape && N[newtDiff] < 1.*^-12);
sf["Method -> \"Newton\" is accepted and matches the automatic dispatch=", methOk];
vSolMeth = Quiet[SpectralElement`SpectralNDSolve[linEq, u, {x, y} \[Element] rectR, 12, Method -> "NoSuchMethod"]];
sf["Method -> \"NoSuchMethod\" -> ", vSolMeth, "  (expected $Failed, ::method)"];
badMethOk = (vSolMeth === $Failed);
sf["an unknown Method is refused, never silently downgraded=", badMethOk];

(* --- 8d. an already-built discretization is CONSUMED AS-IS ---
   API.md 4.3: a SpectralDiscretization passed as Omega is used, never
   rebuilt.  Both calls below are independent, so agreement to round-off is
   evidence that the second one really reused the object. *)
preDisc = Quiet[SpectralElement`SpectralDomain[rectR, 12]];
preOk = AssociationQ[preDisc] && TrueQ[Quiet[SpectralElement`SpectralDomainQ[preDisc]]];
sf["SpectralDomain[Rectangle, 12] built for reuse -> ",
    If[preOk, "a SpectralDiscretization", preDisc]];
preSol = Quiet[SpectralElement`SpectralNDSolve[nlEq, u, {x, y} \[Element] preDisc, 12]];
sf["SpectralNDSolve[..., Omega = that discretization, 12] -> ",
    If[And @@ (ListQ /@ preSol), "a list of rules", preSol]];
preShape = (ListQ[preSol] && Length[preSol] === 1 && ListQ[First[preSol]]
    && Length[First[preSol]] === 1 && First[First[preSol]][[1]] === u
    && (Head[First[First[preSol]][[2]]] === Function));
preFn = If[preShape, First[First[preSol]][[2]], Null];
preDiff = If[preShape && nlShape,
    N[Max[Abs[N[preFn[N[#[[1]]], N[#[[2]]]]] - N[nlFn[N[#[[1]]], N[#[[2]]]]]] & /@ probePts]], -1.];
sf["  the two independent solves differ by = ", preDiff, "  (they must agree)"];
reuseOk = (preOk && preShape && N[preDiff] < 1.*^-12);
sf["a pre-built discretization is accepted and reproduces the answer=", reuseOk];

(* --- 8e. SpectralNDSolveValue returns the FUNCTION, not a rule ---
   The two entry points differ in exactly one thing, so this is the gate
   that says which way round they differ. *)
solVal = Quiet[SpectralElement`SpectralNDSolveValue[linEq, u, {x, y} \[Element] rectR, 12]];
sf["SpectralNDSolveValue[..., 12] -> ",
    If[(Head[solVal] === Function), "a pure Function", solVal]];
valOk = (Head[solVal] === Function);
sf["SpectralNDSolveValue gives the function itself, with no rule wrapper=", valOk];

(* --- 8b. NO DirichletCondition: the homogeneous default, gated IN ---
   8a-8e all supply their own boundary data.  This block supplies none, so
   API.md 4.3's homogeneous Dirichlet default (u == 0 on the whole exterior
   boundary) is what gets solved.  It was the round-3 hang; it is now a
   gate, because a working path that no gate covers is a path that rots.
   Owner of the fix: agent D, two layers (Kernel/Discretization.wl
   seLiftNode, Kernel/Solve.wl ::nlift + the seLinSolve pre-check).

   The problem is chosen so the answer is known in closed form AND vanishes
   on the whole exterior boundary of the square, so the closed form is
   consistent with the default boundary data:

       -Laplacian[u] == -Laplacian[noDcPoly]   on   Rectangle[{-1, -1}, {1, 1}]
       noDcPoly[x, y] = (1 - x^2) (1 - y^2)

   It vanishes on all four edges, so u == noDcPoly is the unique solution,
   and it is a polynomial of degree 2 per variable -- far inside the degree-12
   discrete space, so the collocation reproduces it to round-off.  Two
   consequences, both used below:
     * on the boundary the exact answer is 0 EXACTLY, so "0" is a sharp
       gate and not a tolerance test;
     * at an interior point the exact answer is nonzero (1 at the centre),
       so the solution cannot be trivially right by being zero everywhere.

   A first attempt used -Laplacian[u] == 1 with the closed form taken as
   (1 - x^2 - y^2)/4, and it FAILED -- correctly, because that expression
   vanishes on the CIRCLE r = 1, not on the edges of the square, so it is
   not a solution of this problem at all.  The solver was right: -Laplacian[u]
   == 1 with u == 0 on the square returns 0.2946854143698992 at the centre,
   and the known torsion constant for the 2x2 square is 0.29468541.  A gate
   built on a wrong closed form would have reported a defect that does not
   exist, which is the failure mode this comment exists to prevent.
   No Private symbol is read: the only handle used is the returned Function.

   Apply[fn, pts, {1}] maps a two-argument function over a list of pairs
   and is used instead of a pure function with slot numbers.  That is not
   stylistic: `N[f[...] & /@ pts]` and `Print[..., f[...] & /@ pts]` both
   put the slot operator at the TOP LEVEL of an argument list, which is a
   Syntax::sntx (measured twice on 2026-10-05), and `expr /@ pairs` without
   the & silently threads the pairs into the pattern variables.  Apply has
   no slots, so it cannot be got wrong.

   The 60-second bound is deliberately loose -- the solve takes a fraction
   of a second -- and deliberately finite: the round-3 failure mode was a
   call that never returned, and only a bounded check catches that. *)
noDcReg = Rectangle[{-1, -1}, {1, 1}];
noDcPoly[a_, b_] := (1 - a^2) (1 - b^2);
noDcRhs = -Laplacian[noDcPoly[x, y], {x, y}];
noDcEq = {-Laplacian[u[x, y], {x, y}] == noDcRhs};
{tNoDc, noDcSol} = AbsoluteTiming[Quiet[SpectralElement`SpectralNDSolve[noDcEq, u, {x, y} \[Element] noDcReg, 12]]];
sf["SpectralNDSolve with NO DirichletCondition, Rectangle, 12 -> ",
    If[And @@ (ListQ /@ noDcSol), "a list of rules", noDcSol],
    "   (u == 0 on the whole boundary is the API.md 4.3 default)"];
sf["  wall time = ", N[tNoDc], " s   (60 s bound: the round-3 hang never returned)"];
noDcShape = (ListQ[noDcSol] && Length[noDcSol] === 1 && ListQ[First[noDcSol]]
    && Length[First[noDcSol]] === 1 && First[First[noDcSol]][[1]] === u
    && (Head[First[First[noDcSol]][[2]]] === Function));
noDcFn = If[noDcShape, First[First[noDcSol]][[2]], Null];
(* corners and off-node edge points: every one of them is on the exterior
   boundary, where the exact answer is 0 *)
bdPts = {{1., 0.}, {-1., 0.}, {0., 1.}, {0., -1.}, {0.5, 1.}, {-0.5, -1.}};
noDcBd = If[noDcShape, N[Max[Abs[Apply[noDcFn, bdPts, {1}]]]], -1.];
sf["  max |u| at six points on the exterior boundary = ", noDcBd, "  (exact answer 0)"];
intPts = {{0.25, 0.5}, {-0.5, -0.25}, {0.6, -0.7}, {0., 0.}};
(* TWO parameters, not one.  Apply[fn, pts, {1}] on a list of PAIRS spreads
   each pair into two arguments -- that is what makes it the right tool for a
   two-argument function like noDcFn -- so a one-parameter helper would be
   handed (a, b) and would return unevaluated, silently, with no message.
   Measured while writing this gate. *)
noDcInt = If[noDcShape,
    N[Max[Abs[Apply[noDcFn, intPts, {1}] - Apply[noDcPoly, intPts, {1}]]]], -1.];
sf["  max |u - (1 - x^2)(1 - y^2)| at four interior points = ", noDcInt,
    "  (the closed form is IN the discrete space, so round-off is the floor)"];
noDcOk = (noDcShape && N[tNoDc] < 60. && N[noDcBd] === 0. && N[noDcInt] < 1.*^-8);
sf["no-DirichletCondition solve returns, is numeric, is u == 0 on the boundary=", noDcOk];

(* --- 8c. non-numeric Dirichlet data is REFUSED LOUDLY, not hung on ---
   The negative control for 8b.  gGhostSymbolic is undefined, so the
   Dirichlet value stays symbolic at every node; the lift therefore cannot
   be numeric and no system can be assembled.  The package must say so by
   name (SpectralNDSolve::nlift) and return $Failed.  A silently-zeroed lift
   and a solve that never returns both fail this gate.

   NOT Quiet, and that is load-bearing rather than stylistic -- this cost a
   full run.  Two facts about messages under wolframscript were measured
   here, and they disagree with each other and with section 9's older note:
     * an UNQUIETED call DOES append to $MessageList (the slice came back
       length 1, HoldForm[SpectralNDSolve::nlift]); so section 9's "not
       populated" claim does not hold for an un-Quieted call;
     * a QUIET-wrapped call appends NOTHING (slice length 0), so a gate
       written as Quiet[...] + a $MessageList read is guaranteed to fail,
       and a Quiet-wrapped call also prints nothing, so the stdout route
       fails too.  Both routes dead, for a call that did raise and did
       return $Failed.  D2's probe read the slice successfully because its
       call was not Quiet (Tests/out/d2_nodc.125831_70202.txt section E).
   So the call is bare: $MessageList is consulted first because it works,
   and this run's stdout is consulted as the independent second opinion,
   which is the route section 9 already uses for the other message names. *)
gGhost[a_, b_] := gGhostSymbolic[a, b];
badDcEq = {-Laplacian[u[x, y], {x, y}] == 1,
    DirichletCondition[u[x, y] == gGhost[x, y],
      Abs[x] < 1.*^-8 || Abs[x - 1.] < 1.*^-8 || Abs[y] < 1.*^-8 || Abs[y - 1.] < 1.*^-8]};
mLift = Length[$MessageList];
{tLift, badDc} = AbsoluteTiming[SpectralElement`SpectralNDSolve[badDcEq, u, {x, y} \[Element] noDcReg, 12]];
liftMsgs = $MessageList[[Min[mLift + 1, Length[$MessageList]] ;; Length[$MessageList]]];
nliftSeen = AnyTrue[liftMsgs, StringContainsQ[ToString[#, InputForm], "SpectralNDSolve::nlift"] &];
soFile0 = FileNameJoin[{repo, "Tests", "out", "installprobe.stdout"}];
soText0 = If[FileExistsQ[soFile0], Quiet[Check[ReadList[soFile0, String], {}]], {}];
nliftSeen = nliftSeen || AnyTrue[soText0, StringContainsQ[#, "SpectralNDSolve::nlift"] &];
sf["a DirichletCondition whose value is not a number -> ", badDc, "  (expected $Failed)"];
sf["  wall time = ", N[tLift], " s   messages raised = ", Length[liftMsgs]];
sf["  SpectralNDSolve::nlift was among them = ", nliftSeen];
nliftOk = (TrueQ[badDc === $Failed] && nliftSeen);
sf["non-numeric Dirichlet data gives $Failed naming SpectralNDSolve::nlift=", nliftOk];

(* ---------------------------------------------------------------- *)
sf["--- 9. messages seen in this run's stdout: the message NAMES ---"];
(* This is the gate for "the right message was issued".  Check cannot do it
   through a function argument (see the note at the top of this file), and
   $MessageList is not populated under wolframscript
   (Tests/out/q4probe.041155_79607.txt section 2).  So the calls that are
   supposed to raise are repeated UNQUIETED here -- the messages then reach
   this run's stdout, which is read back immediately below.  This is the
   same technique Tests/loadprobe.wl uses. *)

sf["  repeating the message-raising calls unquieted:"];
sf["  CoonsPatch[three edges]:"];
x1 = SpectralElement`CoonsPatch[Take[edges, 3]];
sf["  CoonsPatch[edges that do not close]:"];
x2 = SpectralElement`CoonsPatch[openEdges];
sf["  CoonsPatch[Method -> \"NoSuchMethod\"] (must fire ::method):"];
x3 = SpectralElement`CoonsPatch[edges, Method -> "NoSuchMethod"];
sf["  SpectralDomainData[disc, \"NoSuchKey\"]:"];
x4 = SpectralElement`SpectralDomainData[disc, "NoSuchKey"];
sf["  SpectralDomain[Disk[], 6]:"];
x5 = SpectralElement`SpectralDomain[Disk[], 6];
sf["  their values: ", {x1, x2, x3, x4, x5}];

sofile = FileNameJoin[{repo, "Tests", "out", "installprobe.stdout"}];
allLines = If[FileExistsQ[sofile], Quiet[Check[ReadList[sofile, String], {}]], {}];
sf["stdout lines read back=", Length[allLines]];
msgs = Select[allLines, StringContainsQ[#, "::"] &];
sf["lines containing \"::\"=", Length[msgs]];
Do[sf["    ", m], {m, msgs}];

(* A message NAME appears if its tag is at the start of a stdout line.
   Two details, both measured (Tests/out/q6probe.044615_82623.txt):

     * stdout shows the tag WITHOUT its context -- "CoonsPatch::edges: ...",
       not "SpectralElement`CoonsPatch::edges: ..." -- so match the SHORT
       name.  The full tag is what Message[] is called with in the source.
     * MemberQ[msgs, StringStartsQ[#, short] &] is False even when an
       element plainly starts with `short`.  MemberQ does not treat a
       pattern as a per-element test the way AnyTrue does.  AnyTrue[msgs,
       StringStartsQ[#, short] &] is the form that works. *)
saw[short_] := AnyTrue[msgs, StringStartsQ[#, short] &];
(* SpectralNDSolve::nlift is in this list because section 8c raises it
   unquieted, so the name is confirmed by the INDEPENDENT stdout route as
   well as by the $MessageList slice in 8c.  Reporting it costs no gate. *)
want = {"CoonsPatch::edges", "CoonsPatch::corners", "CoonsPatch::method",
   "SpectralDomain::key", "SpectralDomain::nreg",
   "SpectralNDSolve::nlift"};
sf["expected message names, each fired at least once:"];
Do[sf["   ", want[[j]], " -> ", saw[want[[j]]]], {j, Length[want]}];

(* the load itself must be message-free: anything naming a Kernel FILE *)
loadMsgs = Select[msgs, StringContainsQ[#, "Kernel"] &];
sf["messages naming a Kernel file=", Length[loadMsgs],
   "  (0 expected: the load was already proved message-free in section 4)"];

(* ---- section 10 *)
sf["--- 10. uninstall, and PROVE nothing is left behind ---"];
un = Quiet[Check[PacletUninstall["SpectralElement"], "ERR"]];
sf["PacletUninstall returned=", un];
If[FileExistsQ[archive], DeleteFile[archive]];
sf["archive still present=", FileExistsQ[archive]];
If[DirectoryQ[installedLoc], Run["rm -rf " <> installedLoc]];
sf["install dir still on disk=", DirectoryQ[installedLoc]];
sf["PacletFind[SpectralElement] after uninstall=",
   Length[Quiet[Check[PacletFind["SpectralElement"], {}]]]];
sf["on $ContextPath after uninstall (loaded in THIS kernel only, harmless)=",
   MemberQ[$ContextPath, "SpectralElement`"]];

(* ---------------------------------------------------------------- *)
sf["--- 12. the RELEASE ARCHIVE, and the documentation pages in it ---"];
(* This section is the one the F1 work added, and it is deliberately
   about the ARCHIVE rather than the checkout.

   Section 2 above builds an archive of the WHOLE repo -- that is the point
   of this probe, which simulates a user with no build step.  It is the
   wrong archive to assert a release entry list against: it contains Tests/
   and scratch/, which no release ever ships.  So this section reads the
   archive build/release.sh actually produced, and the entry count it
   asserts is that archive's.

   The count is 26, and the nine documentation paths are listed and checked
   one by one.  Count alone would be the wrong gate: the Documentation
   Center resolves a symbol page by FILENAME, so a set of nine .nb files
   under the wrong names would pass a count and still leave F1 finding
   nothing. *)
releaseArchive = FileNameJoin[{repo, "build", "SpectralElement-0.1.0.paclet"}];
sf["release archive=", releaseArchive, "  exists=", FileExistsQ[releaseArchive]];
(* The archive's own entry list.

   Import[archive, "FileList"] was the first attempt, and it returns {} on
   this kernel -- 0 entries for an archive that `unzip -Z1` lists with 26.
   So the list is read the way the build itself reads it: unzip -Z1,
   redirected to a file, read back with Import.  That is also better
   evidence, because it is the same reader release.sh used to decide the
   release was good. *)
archiveListFile = FileNameJoin[{scratch, "release-entries.txt"}];
Quiet[Check[Run["unzip -Z1 " <> releaseArchive <> " > " <> archiveListFile], "ERR"]];
archiveEntries = If[FileExistsQ[archiveListFile],
   StringSplit[Import[archiveListFile, "Text"], "\n"], {}];
archiveEntries = DeleteCases[archiveEntries, "" | Null];
sf["unzip -Z1 on the release archive returned ", Length[archiveEntries],
   " entries"];
If[Length[archiveEntries] > 0, sf["   sample=", Take[archiveEntries, UpTo[6]]]];

archiveEntryCount = Length[archiveEntries];
(* 26 = 9 .nb pages + 5 directory entries + 5 files + 7 Kernel/ entries.
   The measured breakdown, from build/release.lastout: archive-entries 26,
   staged-files 19, documentation-files 9.  Asserted as 26 because that is
   what the release currently is; the per-path assertions below are what
   keep it honest. *)
archiveEntryCountOk = (archiveEntryCount === 26);
sf["release archive entry count = ", archiveEntryCount,
   "  (expected 26: 9 .nb pages + 5 directory entries + 12 files)  ",
   archiveEntryCountOk];

(* the nine convention paths, checked in the ARCHIVE listing *)
docRel = {"Documentation/English/Guides/SpectralElement.nb",
   "Documentation/English/ReferencePages/Symbols/CoonsPatch.nb",
   "Documentation/English/ReferencePages/Symbols/CoonsPatchQ.nb",
   "Documentation/English/ReferencePages/Symbols/CoonsPatchMap.nb",
   "Documentation/English/ReferencePages/Symbols/SpectralDomain.nb",
   "Documentation/English/ReferencePages/Symbols/SpectralDomainQ.nb",
   "Documentation/English/ReferencePages/Symbols/SpectralDomainData.nb",
   "Documentation/English/ReferencePages/Symbols/SpectralNDSolve.nb",
   "Documentation/English/ReferencePages/Symbols/SpectralNDSolveValue.nb"};
inArchive = Select[docRel,
   MemberQ[archiveEntries, ("SpectralElement/" <> #) | (#)] &];
archiveDocOk = (Length[inArchive] === Length[docRel]);
sf["the nine documentation pages are in the release archive=",
   archiveDocOk, "  found ", Length[inArchive], "/", Length[docRel]];

(* and in the CHECKOUT, which is what gets staged next time *)
inCheckout = Select[docRel, FileExistsQ[FileNameJoin[{repo, #}]] &];
checkoutDocOk = (Length[inCheckout] === Length[docRel]);
sf["the nine documentation pages are in the checkout=", checkoutDocOk,
   "  found ", Length[inCheckout], "/", Length[docRel]];

(* the PacletInfo the release ships must declare the Documentation
   extension with the MainPage the guide actually sits at *)
(* MemberQ, not MatchQ.  MatchQ takes TWO arguments, so the three-argument
   MatchQ[..., pattern, ___] came back unevaluated and printed itself --
   visible in the first run of this section as
       "PacletInfo declares ..." = MatchQ[{{...}}, {_, {...}, ___}]
   which is not a verdict at all.  What is wanted is membership in the
   Extensions list, and that is what MemberQ answers. *)
(* The rule keys are STRINGS, because PacletInfo is READ, not evaluated:
   po["Extensions"] reads back as
       {{"Kernel", "Root" -> "Kernel", "Context" -> {"SpectralElement`"}},
        {"Documentation", "Language" -> All,
                    "MainPage" -> "Guides/SpectralElement"}}
   -- "Language" -> All, not Language -> All.  The first pattern used bare
   symbols and matched nothing.  Same reason TriangleLink's own PacletInfo.m
   writes Language -> All: that file is in .m POSITIONAL form, where the
   keys are not strings. *)
mainPageOk = MemberQ[po["Extensions"],
   {"Documentation", "Language" -> _, "MainPage" -> "Guides/SpectralElement"}];
sf["PacletInfo declares {Documentation, MainPage -> Guides/SpectralElement}=",
   mainPageOk];
sf["PacletInfo Extensions=", po["Extensions"]];

(* The URI the Documentation Center builds from a symbol name must resolve
   to a file that exists.  Documentation`ResolveLink is the kernel-side
   entry point for exactly this resolution, so it exercises the F1 lookup
   path headless -- the one thing about F1 that can be checked without a
   front end.

   It resolves against a REGISTERED paclet, so the working tree has to be
   registered first: in the first run of this section the lookup returned
   Null, because by then section 10 had already uninstalled the copy this
   probe installed, and a paclet that is not registered resolves to nothing.
   PacletDirectoryLoad[repo] registers the checkout, which is a faithful
   stand-in for the installed tree because it is the same directory shape
   -- the nine pages were just verified to be present at the convention
   paths inside it. *)
Quiet[Check[PacletDirectoryLoad[repo], "DIRLOAD-RAISED"]];
sf["PacletDirectoryLoad[repo] -> ", PacletFind["SpectralElement"][[1, 1]]["Location"]];
resolveUri = "paclet:SpectralElement/ref/SpectralNDSolve";
resolved = Check[Quiet[Documentation`ResolveLink[resolveUri]], "UNRESOLVED"];
sf["Documentation`ResolveLink[\"", resolveUri, "\"] -> ", resolved];
resolvedIsFile = (StringQ[resolved] && FileExistsQ[resolved]);
sf["  ... and that path exists on disk=", resolvedIsFile];
resolvedEndsRight = (StringQ[resolved] &&
   StringEndsQ[resolved, "Documentation/English/ReferencePages/Symbols/SpectralNDSolve.nb"]);
sf["  ... and it ends at the convention path=", resolvedEndsRight];

resolveGuide = Check[Quiet[Documentation`ResolveLink[
   "paclet:SpectralElement/guide/SpectralElement"]], "UNRESOLVED"];
sf["Documentation`ResolveLink on the guide URI -> ", resolveGuide];
guideIsFile = (StringQ[resolveGuide] && FileExistsQ[resolveGuide]);
sf["  ... and the guide file exists=", guideIsFile];

(* Every .nb parses, and carries the styles the Documentation Center needs.
   The style list is the one read out of TriangleLink's own
   NotebookFileOutline, not a guess: AnchorBarGrid, ContextNameCell,
   ObjectNameGrid, Usage, NotesSection, PrimaryExamplesSection,
   ExampleSection, ExampleText, Input, Output, SeeAlsoSection, FooterCell. *)
docPages = Select[docRel, StringEndsQ[#, ".nb"] &];
styleGates = Map[
   Function[{rel},
     Module[{nb, cells, styles, objName, usageTxt, nEx},
       nb = Check[Get[FileNameJoin[{repo, rel}]], "GET-FAILED"];
       If[Head[nb] =!= Notebook,
         Print["  ", rel, " HEAD ", Head[nb], " ", nb];
         Return[{rel, False, "not-a-Notebook", False, False, 0}]];
       cells = Cases[nb, Cell[_, opts___] /; MemberQ[opts, _String], Infinity];
       styles = Union[Cases[cells, Cell[_, s_String] /;
          MemberQ[{"AnchorBarGrid", "ContextNameCell", "ObjectName",
            "Usage", "NotesSection", "Notes", "PrimaryExamplesSection",
            "ExampleSection", "ExampleText", "Input", "Output",
            "SeeAlsoSection", "FooterCell"}, #] &]];
       need = {"AnchorBarGrid", "ContextNameCell", "Usage",
         "NotesSection", "PrimaryExamplesSection", "ExampleSection",
         "ExampleText", "Input", "Output", "SeeAlsoSection", "FooterCell"};
       missingStyles = Complement[need, styles];
       If[missingStyles =!= {},
         Print["  ", rel, " MISSING STYLES ", missingStyles]];
       hasAllStyles = (missingStyles === {});
       (* the ObjectName cell must name THIS symbol, or F1 opens the page
          and the reader sees the wrong name at the top of it.  The name
          comes from the FILENAME by convention, so it is compared with the
          filename rather than with anything read out of the page. *)
       want = StringReplace[
         StringTake[rel, -StringLength[".nb"]],
         "Documentation/English/ReferencePages/Symbols/" -> ""];
       objNames = Cases[cells, Cell[n_String, "ObjectName"] /; ! MemberQ[n,
          {"Examples", "Options", "Details and Options"}], Infinity];
       objOk = (! MemberQ[objNames, _? (! StringQ[#]) &]) &&
         (Length[objNames] >= 1) && (MemberQ[objNames, want]);
       (* the Usage cell must carry text *)
       usageText = Check[Quiet[Cases[cells,
          Cell[BoxData[GridBox[{{"", Cell[TextData[t_String]]}}]], "Usage"],
          Infinity]], {}];
       usageLen = If[Length[usageText] > 0, Length[usageText], 0];
       nEx = Length[Cases[cells, Cell[_, "Input"], Infinity]];
       nOut = Length[Cases[cells, Cell[_, "Output"], Infinity]];
       Print["  ", rel, " styles=", If[hasAllStyles, "all", "MISSING"],
          " cells=", Length[cells], " Input=", nEx, " Output=", nOut,
          " UsageCells=", Length[usageText],
          " ObjectName=", If[objOk, "ok", StringTake[ToString[objNames], 60]]];
       {rel, hasAllStyles, If[hasAllStyles, "all-styles-present", ""], objOk,
         Length[usageText] > 0, nEx}]],
   docPages];
sf["every .nb parses and carries the Documentation Center styles: ",
   And @@ (styleGates[[All, 2]])];

(* ---------------------------------------------------------------- *)
sf["--- 13. verdict ---"];
checks = {
  "the machine had no SpectralElement installed before this run" -> clearBefore,
  "PacletInfo has Name/Version/Context/Extensions" -> metaOk,
  "the .paclet archive was created" -> archiveMade,
  "PacletInstall registered the paclet" -> (Length[found] >= 1),
  "install location is the installed copy, not the checkout" -> installOk,
  "PacletInstall raised no message" -> (inst =!= "PACLETINSTALL-RAISED"),
  "Needs returned Null" -> (nd === Null),
  "the load raised no message" -> loadClean,
  "context on $ContextPath" -> onPath,
  "FindFile resolves inside the installed copy" -> (ffIn === True),
  "no public symbol missing" -> (missing === {}),
  "all eight in context SpectralElement`" -> allInCtx,
  "no unexpected public symbols" -> (extra === {}),
  "the subfiles executed (private symbols exist)" -> (Length[privNames] > 0),
  "CoonsPatch built a patch" -> patchBuilt,
  "CoonsPatchQ accepted it" -> (patchQ === True),
  "CoonsPatchMap is exact on a linear patch" -> mapOk,
  "CoonsPatchMap is exact at a corner" -> cornerOk,
  "three edges rejected" -> rej3,
  "non-closing edges rejected" -> rejOpen,
  "Method -> AAA never silently downgrades to Analytic" ->
    ((! aaaBuilt) || (aaaMethod && aaaQ)),
  "unrecognised Method rejected, no silent fallback" -> rejMeth,
  "CoonsPatch::edges was the message" -> saw["CoonsPatch::edges"],
  "CoonsPatch::corners was the message" -> saw["CoonsPatch::corners"],
  "CoonsPatch::method was the message (no silent fallback)" ->
    saw["CoonsPatch::method"],
  "SpectralDomain built a discretization" -> discBuilt,
  "SpectralDomainQ accepted it" -> (discQ === True),
  "PatchCount == 1" -> (pc === 1),
  "Degree == 8" -> (deg === 8),
  "UnknownCount == (n-1)^2 == 49" -> (uc === 49),
  "UnknownCount is numeric (Sum[nInt] defect)" -> IntegerQ[uc],
  "RowCount == UnknownCount (square system)" -> (uc === rc),
  "nodes per direction == n+1 == 9" -> (Length[nodes] === 9),
  "one-patch domain has 0 interfaces" -> (Length[ifs] === 0),
  "MinJacobian == 2 (analytic, rel. tol 1e-12)" -> minjOk,
  "unknown key rejected" -> rejKey,
  "SpectralDomain::key was the message" -> saw["SpectralDomain::key"],
  "Rectangle shorthand gives 1 patch" -> (rectPc === 1),
  "Annulus span Pi gives 1 sector" -> (annPc === 1),
  "Annulus span 2 Pi gives 2 sectors" -> (ann2Pc === 2),
  "Disk rejected (J = 0 at the centre)" -> rejDisk,
  "SpectralDomain::nreg was the message" -> saw["SpectralDomain::nreg"],
  "the solver layer is implemented, not a stub" -> solverPresent,
  "installed Solve.wl is a real solver file, not the 63-byte stub" -> notStub,
  "SpectralNDSolve returns {{u -> Function}} on a linear problem" -> linShape,
  "linear solve recovers the manufactured solution" -> linOk,
  "SpectralNDSolve returns {{u -> Function}} on a nonlinear problem" -> nlShape,
  "nonlinear solve recovers the manufactured solution" -> nlOk,
  "MaxIterations -> 1 caps Newton and yields $Failed" -> capOk,
  "Method -> Newton matches the automatic dispatch" -> methOk,
  "an unknown Method is refused, not downgraded" -> badMethOk,
  "a pre-built discretization is consumed as-is" -> reuseOk,
  "SpectralNDSolveValue returns the function itself" -> valOk,
  "no DirichletCondition: the u == 0 default solves, fast and numeric" -> noDcOk,
  "non-numeric Dirichlet data is refused with $Failed and ::nlift" -> nliftOk,
  "uninstall removed the install dir" -> (! DirectoryQ[installedLoc]),
  "PacletFind empty after uninstall" ->
    (Length[Quiet[Check[PacletFind["SpectralElement"], {}]]] === 0),
  "no message named a Kernel file" -> (Length[loadMsgs] === 0),
  "build/release.sh produced an archive" -> releaseExistsOk,
  "release archive has 26 entries (9 doc pages + 5 dirs + 12 files)" ->
    archiveEntryCountOk,
  "all nine documentation pages are in the release archive" -> archiveDocOk,
  "all nine documentation pages are in the checkout" -> checkoutDocOk,
  "PacletInfo declares the Documentation extension with MainPage" -> mainPageOk,
  "the ref URI for SpectralNDSolve resolves to a file" -> resolvedIsFile,
  "... at the convention path ReferencePages/Symbols/<Symbol>.nb" ->
    resolvedEndsRight,
  "the guide URI resolves to a file" -> guideIsFile,
  "every documentation .nb parses as a Notebook with the required styles" ->
    And @@ (styleGates[[All, 2]]),
  "every documentation page names its own symbol in the ObjectName cell" ->
    And @@ (styleGates[[All, 4]]),
  "every documentation page has a non-empty Usage cell" ->
    And @@ (styleGates[[All, 5]]),
  "every documentation page carries at least one Input and one Output cell" ->
    And @@ (Map[#[[6]] >= 2 &, styleGates])
};
Do[sf["  ", checks[[i, 1]], " -> ", checks[[i, 2]]], {i, Length[checks]}];
allPass = And @@ checks[[All, 2]];
sf["checks run=", Length[checks], "  passed=", Count[checks[[All, 2]], True]];

(* MEASURED DEFECT IN THIS PROBE, and it is why INSTALLPROBE-ALL-PASS was
   never printed in ANY earlier run, including the ones that reported 45/45
   of their gates green.  This If had FIVE arguments:

       If[allPass, sf["...ALL-PASS"], sf["...FAIL"], sf["FAILING ITEMS"],
         Do[...]]

   If takes two to four, so it raised

       If::argb: If called with 5 arguments; between 2 and 4 arguments
       are expected.

   and returned UNEVALUATED.  Nothing was written: no verdict line, and no
   FAIL list either.  A probe whose verdict line silently does not exist is
   worse than a probe that fails, because a reader sees "checks run=45
   passed=43" and then DONE and has to guess.  The three statements are
   separate here on purpose: the failing items are listed UNCONDITIONALLY
   (an empty list is the desired output when everything passed), and only
   the verdict itself is guarded. *)
Do[If[checks[[i, 2]] =!= True, sf["   FAIL: ", checks[[i, 1]]], Null], {i, Length[checks]}];
If[TrueQ[allPass], sf["INSTALLPROBE-ALL-PASS"], sf["INSTALLPROBE-FAIL"]];
sf["================ DONE-installprobe ================"];
(* The literal last line, so the verdict can be taken from the end of the
   file without parsing anything above it. *)
sf["TALLY ", Count[checks[[All, 2]], True], "/", Length[checks], " PASS"];
sfClose[];
Quit[];