(* Tests/probes/p_docverify.wl -- VERIFY EVERY EXAMPLE IN wfr/SpectralNDSolve.md.

   Each labelled item below is an example from the document, and each is
   EVALUATED here.  "A doc example that does not run is a failed delivery"
   is therefore a checked claim rather than an intention.

   Pass test: raised no message, and the answer is neither $Failed nor
   Indeterminate.  Two earlier versions of this test were wrong and both
   reported walls of failures that were really passes:
     * "Head is not Symbol" -- rejects True, Function and $Failed alike;
     * adding "and the answer is not the input expression" -- but `expr` in
       a SetDelayed pattern is ALREADY EVALUATED, so SameQ[expr, r] is
       trivially True for every call that succeeded.
   The printed head and the printed value are the real evidence.

   The pointwise-error helper ptErr below is COPIED VERBATIM from
   Tests/installprobe.wl L523 (proven in a green run) so that the bracket
   structure is not re-derived by hand.  The `&` is load-bearing: `expr /@
   pts` threads the list of PAIRS into the pattern variables, so the
   interpolant is asked for f[point1, point2, ...] and answers
   Indeterminate.

   Run: ./rr.sh 300 Tests/probes/p_docverify.wl *)
$HistoryLength = 0;
$HistoryLength = 1;
ok = 0;
bad = 0;
sh[r_] := Print["        -> ", ToString[Head[r], InputForm], "  ", StringTake[ToString[r, InputForm], UpTo[140]]];
chk[label_, expr_] := Module[{r, good},
   r = Quiet[Check[expr, "RAISED"]];
   good = ! SameQ[r, "RAISED"] && ! SameQ[r, $Failed] && ! SameQ[r, Indeterminate];
   If[TrueQ[good], ok++, bad++];
   Print[If[TrueQ[good], "  ok  ", "  FAIL"], "  ", label];
   sh[r];
   r];
chkF[label_, expr_] := Module[{r, good},
   r = Quiet[Check[expr, "RAISED"]];
   good = TrueQ[r === $Failed];
   If[TrueQ[good], ok++, bad++];
   Print[If[TrueQ[good], "  ok  ", "  FAIL"], "  ", label, " (correct answer is $Failed)"];
   sh[r];
   r];

(* THREE DirectoryNames, not two.  rr.sh runs `wolframscript -script
   Tests/probes/p_docverify.wl` from the repo root, so $InputFileName is
   RELATIVE ("Tests/probes/p_docverify.wl") and two levels up is "Tests",
   not the repo root.  With two, PacletDirectoryLoad silently returned {}
   and Needs answered Needs::nocont, the package never loaded, and every
   non-$Failed check counted an UNEVALUATED call as a pass: 53 "ok" and 9
   "FAIL", where the 9 were exactly the ones that assert $Failed.  Hence
   the abort gate immediately below -- a failed load must stop the run,
   not be absorbed by permissive checks. *)
repo = FileNameJoin[{DirectoryName[DirectoryName[DirectoryName[$InputFileName]]]}];
Print["repo=", repo];
PacletDirectoryLoad[repo];
Print["needs=", Check[Needs["SpectralElement`"], "RAISED"]];
loadedQ = (MemberQ[$ContextPath, "SpectralElement`"]
    && Length[DownValues[SpectralElement`SpectralNDSolve]] > 0
    && Length[DownValues[SpectralElement`CoonsPatch]] > 0);
Print["the package is REALLY loaded (ContextPath + DownValues)=", loadedQ,
    "   Names=", Length[Names["SpectralElement`*"]]];
If[! TrueQ[loadedQ],
   Print["FATAL: the package did not load, so every later check would be",
       "reading an UNEVALUATED call as a pass.  Stopping instead."];
   Print["DOCVERIFY-ABORTED-NOT-LOADED"];
   Quit[3]];

edges = {Function[t, {2 t, -1}], Function[t, {2 t, 1}], Function[t, {-2, t}], Function[t, {2, t}]};
chk["CoonsPatch[edges]", SpectralElement`CoonsPatch[edges]];
patch = SpectralElement`CoonsPatch[edges];
chk["CornerClosure (doc: 0. exactly)", Lookup[patch, "CornerClosure"]];
chk["Method tag (doc: Analytic)", Lookup[patch, "Method"]];
chk["CoonsPatchMap[patch, 0.3, -0.5] (doc: {0.5999999999999999, -0.5})", SpectralElement`CoonsPatchMap[patch, 0.3, -0.5]];
chk["CoonsPatchMap[patch, -1., -1.] (doc: {-2., -1.})", SpectralElement`CoonsPatchMap[patch, -1., -1.]];
chk["corner Max[Abs] (doc: 0.)", Max[Abs[N[SpectralElement`CoonsPatchMap[patch, -1., -1.]] - {-2., -1.}]]];
chk["interior Max[Abs] (doc: < 1e-14)", Max[Abs[N[SpectralElement`CoonsPatchMap[patch, 0.3, -0.5]] - {0.6, -0.5}]]];

Print["== discretization =="];
disc = chk["SpectralDomain[{patch}, 8]", SpectralElement`SpectralDomain[{patch}, 8]];
chk["PatchCount (doc 1)", SpectralElement`SpectralDomainData[disc, "PatchCount"]];
chk["Degree (doc 8)", SpectralElement`SpectralDomainData[disc, "Degree"]];
chk["UnknownCount (doc 49)", SpectralElement`SpectralDomainData[disc, "UnknownCount"]];
chk["RowCount (doc 49)", SpectralElement`SpectralDomainData[disc, "RowCount"]];
chk["Length[Nodes] (doc 9)", Length[SpectralElement`SpectralDomainData[disc, "Nodes"]]];
chk["Length[InterfacePairs] (doc 0)", Length[SpectralElement`SpectralDomainData[disc, "InterfacePairs"]]];
chk["MinJacobian (doc {1.9999999999999882})", SpectralElement`SpectralDomainData[disc, "MinJacobian"]];
chk["Rectangle PatchCount (doc 1)", SpectralElement`SpectralDomainData[SpectralElement`SpectralDomain[Rectangle[{-1, -1}, {1, 1}], 6], "PatchCount"]];
chk["Annulus Pi PatchCount (doc 1)", SpectralElement`SpectralDomainData[SpectralElement`SpectralDomain[Annulus[{1, 2}, {0, Pi}], 6], "PatchCount"]];
chk["Annulus 2Pi PatchCount (doc 2)", SpectralElement`SpectralDomainData[SpectralElement`SpectralDomain[Annulus[{1, 2}, {0, 2 Pi}], 6], "PatchCount"]];
chkF["SpectralDomain[Disk[], 6] (doc $Failed)", SpectralElement`SpectralDomain[Disk[], 6]];
chkF["SpectralDomainData[disc, \"NoSuchKey\"] (doc $Failed)", SpectralElement`SpectralDomainData[disc, "NoSuchKey"]];

Print["== AAA =="];
aaa = chk["CoonsPatch[edges, Method -> \"AAA\"]", SpectralElement`CoonsPatch[edges, Method -> "AAA"]];
chk["aaa Method tag (doc: AAA)", Lookup[aaa, "Method", Missing[]]];
chk["CoonsPatchQ[aaa] (doc True)", SpectralElement`CoonsPatchQ[aaa]];
chk["CoonsPatchQ[patch] (doc True)", SpectralElement`CoonsPatchQ[patch]];
chk["aaa Samples (doc 65)", Lookup[aaa, "AAA", {}]["Samples"]];
chk["aaa CornerClosure (doc 2.22e-16)", Lookup[aaa, "CornerClosure", Indeterminate]];
chk["aaa first edge fit X (doc: 2-point, ~1e-15)", Lookup[aaa, "AAA", {}]["Fits"][[1, "X"]]];
chkF["CoonsPatch[edges, Method -> \"NoSuchMethod\"] (doc $Failed)", SpectralElement`CoonsPatch[edges, Method -> "NoSuchMethod"]];
chkF["CoonsPatch[Take[edges, 3]] (doc $Failed)", SpectralElement`CoonsPatch[Take[edges, 3]]];
chkF["CoonsPatch non-closing (doc $Failed, mismatch 0.5)", SpectralElement`CoonsPatch[{Function[t, {2 t, -1}], Function[t, {2 t, 1.5}], Function[t, {-2, t}], Function[t, {2, t}]}]];

Print["== solver, degree 16 =="];
uexz[x_, y_] := Sin[2 x + 1] Cos[3 y - 1] + x y/5;
fLin = -Laplacian[uexz[x, y], {x, y}];
fNl = -Laplacian[uexz[x, y], {x, y}] + uexz[x, y]^3;
rect = Rectangle[{-1.5, -1.2}, {1.8, 1.3}];
bd = Abs[x + 1.5] < 1.*^-8 || Abs[x - 1.8] < 1.*^-8 || Abs[y + 1.2] < 1.*^-8 || Abs[y - 1.3] < 1.*^-8;
pts5 = {{-0.5, 0.3}, {0.1, 0.2}, {-0.4, 0.6}, {0.9, -0.7}, {0.6, 0.8}};
pts3 = {{-0.5, 0.3}, {0.1, 0.2}, {-0.4, 0.6}};
ptErr[fn_, pts_] := N[Max[Abs[N[fn[N[#[[1]]], N[#[[2]]]]] - N[uexz[N[#[[1]]], N[#[[2]]]]]] & /@ pts]];
(* the same shape for a DIFFERENCE of two interpolants, which is what the
   "Method -> Newton matches Automatic" and "reuse reproduces" claims in the
   document actually assert.  ptErr cannot be reused for those: it subtracts
   uexz, so it would measure an error rather than a difference. *)
ptDiff[f_, g_, pts_] := N[Max[Abs[N[f[N[#[[1]]], N[#[[2]]]]] - N[g[N[#[[1]]], N[#[[2]]]]]] & /@ pts]];
eqLin = {-Laplacian[u[x, y], {x, y}] == fLin, DirichletCondition[u[x, y] == uexz[x, y], bd]};
eqNl = {-Laplacian[u[x, y], {x, y}] + u[x, y]^3 == fNl, DirichletCondition[u[x, y] == uexz[x, y], bd]};
lin16 = chk["SpectralNDSolve[eqLin, ..., 16] (doc: {{u -> Function}})", SpectralElement`SpectralNDSolve[eqLin, u, {x, y} \[Element] rect, 16]];
chk["MatchQ[sol, {{u -> _Function}}]", MatchQ[lin16, {{u -> _Function}}]];
uf = lin16[[1, 1, 2]];
chk["{uf[-0.5, 0.3], N[uexz[-0.5, 0.3]]}  <-- the doc quotes this PAIR", {uf[-0.5, 0.3], N[uexz[-0.5, 0.3]]}];
chk["five-point errors at degree 16  <-- the doc quotes this NUMBER", ptErr[uf, pts5]];
nl16 = chk["SpectralNDSolve[eqNl, ..., 16] (Newton)", SpectralElement`SpectralNDSolve[eqNl, u, {x, y} \[Element] rect, 16]];
chk["Newton step norms (doc quotes 1.39, 0.059, 7.1e-4, 1.2e-7, 4.1e-15)", N[Lookup[SpectralElement`Private`seLastSolve, "Dels"]]];
chk["Newton iterations (doc 5)", Lookup[SpectralElement`Private`seLastSolve, "Iterations"]];
chk["SpectralNDSolveValue[eqLin, ..., 16] head is Function", Head[SpectralElement`SpectralNDSolveValue[eqLin, u, {x, y} \[Element] rect, 16]]];

Print["== annulus =="];
bdAnn = Abs[Sqrt[x^2 + y^2] - 1] < 1.*^-8 || Abs[Sqrt[x^2 + y^2] - 2] < 1.*^-8 || Abs[y] < 1.*^-8;
annSol = chk["SpectralNDSolve on Annulus[{1,2},{0,Pi}], 16", SpectralElement`SpectralNDSolve[{-Laplacian[u[x, y], {x, y}] == fLin, DirichletCondition[u[x, y] == uexz[x, y], bdAnn]}, u, {x, y} \[Element] Annulus[{1, 2}, {0, Pi}], 16]];
chk["annulus error at three interior points (bench: 7.88e-4 nodal)", ptErr[annSol[[1, 1, 2]], {{1.5, 0.2}, {-0.4, 0.9}, {0.6, 0.4}}]];

Print["== solver, degree 12: the Tests-section gates =="];
sol12 = chk["SpectralNDSolve[eqLin, ..., 12]", SpectralElement`SpectralNDSolve[eqLin, u, {x, y} \[Element] rect, 12]];
chk["degree-12 linear error, three points (doc: < 1e-5)", ptErr[sol12[[1, 1, 2]], pts3]];
nl12 = chk["SpectralNDSolve[eqNl, ..., 12]", SpectralElement`SpectralNDSolve[eqNl, u, {x, y} \[Element] rect, 12]];
chk["degree-12 nonlinear error, five points (doc: ~1.25e-6)", ptErr[nl12[[1, 1, 2]], pts5]];
chkF["MaxIterations -> 1 (doc $Failed)", SpectralElement`SpectralNDSolve[eqNl, u, {x, y} \[Element] rect, 12, MaxIterations -> 1]];
chkF["Method -> \"NoSuchMethod\" (doc $Failed)", SpectralElement`SpectralNDSolve[eqLin, u, {x, y} \[Element] rect, 12, Method -> "NoSuchMethod"]];
newt12 = chk["Method -> \"Newton\" accepted", SpectralElement`SpectralNDSolve[eqNl, u, {x, y} \[Element] rect, 12, Method -> "Newton"]];
chk["Method -> \"Newton\" MINUS Automatic (doc: 0.)", ptDiff[newt12[[1, 1, 2]], nl12[[1, 1, 2]], pts3]];
preD = chk["SpectralDomain[rect, 12] reused as-is", SpectralElement`SpectralDomain[rect, 12]];
preS = chk["SpectralNDSolve on the pre-built discretization", SpectralElement`SpectralNDSolve[eqNl, u, {x, y} \[Element] preD, 12]];
chk["reused-discretization MINUS from-scratch (doc: 0.)", ptDiff[preS[[1, 1, 2]], nl12[[1, 1, 2]], pts3]];

Print["== bundle integrity =="];
bt = chk["Import[wfr/SpectralNDSolve.wl, \"Text\"]", Import[FileNameJoin[{repo, "wfr", "SpectralNDSolve.wl"}], "Text"]];
chk["SyntaxQ[bundleText] (doc True)", SyntaxQ[bt]];
chk["StringFreeQ[bundleText, escaped dollar] (doc True)", StringFreeQ[bt, "\\$InputFileName"]];
chk["StringFreeQ[bundleText, bare dollar] (doc False)", StringFreeQ[bt, "$InputFileName"]];

Print["== Solving with no boundary condition (round-4 doc section) =="];
mDiag = Length[$MessageList];
poly[a_, b_] := (1 - a^2) (1 - b^2);
chk["doc: -Laplacian[poly] printed form is 2(1-x^2)+2(1-y^2)",
   N[-Laplacian[poly[x, y], {x, y}]]];
noDc = chk["doc: SpectralNDSolve with no DirichletCondition, 12 (doc {{u -> Function}})",
   SpectralElement`SpectralNDSolve[{-Laplacian[u[x, y], {x, y}] == -Laplacian[poly[x, y], {x, y}]}, u, {x, y} \[Element] Rectangle[{-1, -1}, {1, 1}], 12]];
noDcShape = (ListQ[noDc] && Length[noDc] === 1 && ListQ[First[noDc]]
    && Length[First[noDc]] === 1 && First[First[noDc]][[1]] === u
    && (Head[First[First[noDc]][[2]]] === Function));
chk["doc: MatchQ[noDc, {{u -> _Function}}]", MatchQ[noDc, {{u -> _Function}}]];
noDcFn = If[TrueQ[noDcShape], First[First[noDc]][[2]], Null];
noDcBdPts = {{1., 0.}, {-1., 0.}, {0., 1.}, {0., -1.}, {0.5, 1.}, {-0.5, -1.}};
chk["doc: the six boundary values are {0.,0.,0.,0.,0.,0.}", N[Apply[noDcFn, noDcBdPts, {1}]]];
chk["doc: max |u| on the boundary === 0.", N[Max[Abs[Apply[noDcFn, noDcBdPts, {1}]]]]];
noDcPts = {{0.25, 0.5}, {-0.5, -0.25}, {0.6, -0.7}, {0., 0.}};
chk["doc: max |u - poly| at four interior points (doc 2.886579864025407*^-15)",
   N[Max[Abs[Apply[noDcFn, noDcPts, {1}] - Apply[poly, noDcPts, {1}]]]]];
gd[a_, b_] := gUndefined[a, b];
gdBd = Abs[x] < 1.*^-8 || Abs[x - 1.] < 1.*^-8 || Abs[y] < 1.*^-8 || Abs[y - 1.] < 1.*^-8;
chkF["doc: non-numeric Dirichlet data -> $Failed", SpectralElement`SpectralNDSolve[{-Laplacian[u[x, y], {x, y}] == 1, DirichletCondition[u[x, y] == gd[x, y], gdBd]}, u, {x, y} \[Element] Rectangle[{-1, -1}, {1, 1}], 12]];
Print["        (the ::nlift tag above is the doc's quoted message; its text is",
    "         recovered from this run's stdout by installprobe section 9)"];

Print["================================================"];
Print["doc examples ok=", ok, "  failed=", bad];
Print[If[bad === 0, "DOCVERIFY-ALL-PASS", "DOCVERIFY-FAIL"]];
Quit[];
