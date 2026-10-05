(* =====================================================================
   Kernel/Geometry.wl -- SpectralElement` , GEOMETRY LAYER
   ---------------------------------------------------------------------
   Owner: geometry/discretization wave (Wave 1).  Loaded by
   Kernel/SpectralElement.wl from INSIDE Begin["SpectralElement`Private`"].

   CONTRACT RULES OBSERVED HERE
     * NO BeginPackage / Begin / End in this file (the loader owns them).
     * Public symbols are written FULLY QUALIFIED
         SpectralElement`CoonsPatch  /  SpectralElement`CoonsPatchQ
       so that Get-ing this file works both from inside the loader and
       standalone.
     * Every internal symbol carries the `se` prefix (seCGL, seChebD1,
       ...) so that it cannot collide with the sibling agents' private
       symbols, which share the same SpectralElement`Private` context.

   NUMERICAL PROVENANCE (copied verbatim from the verified reference
   /Users/huyan00/mycode/wl-verify/specF/p11.wl + helpers.wl):
     cgl / chebD1 : Chebyshev-Gauss-Lobatto grid and 1st derivative matrix
                    at machine precision (Trefethen `cheb` trick).
     transfinite  : p11 `mkMap4`, i.e. 4-edge Coons / blend map
                    sm = b0 c1 + b1 c2 + a0 c3 + a1 c4 - bilinear corners.

   TRAPS PINNED HERE (this project learned them the hard way)
     * Chebyshev D matrices: never build them by differencing.
     * Kron ordering: nodeVec[v_] = Flatten[Transpose[v]] so the FIRST
       matrix index is the FAST index = xi.
     * Transfinite maps need TRUE corners: on a smooth closed boundary
       the two incident edges share a tangent and J degenerates to 0.
   ===================================================================== *)

(* ---------------------------------------------------------------------
   1.  Numeric primitives (verified verbatim)
   --------------------------------------------------------------------- *)

(* Chebyshev-Gauss-Lobatto nodes on [a,b], nn points, first = +b. *)
seCGL[a_, b_, nn_] := Table[(a + b)/2 - (b - a)/2 Cos[k Pi/(nn - 1)],
   {k, 0, nn - 1}];

(* 1st derivative matrix on CGL nodes (machine precision, dense). *)
seChebD1[xx_] := Module[{nn = Length[xx], cc, sg, aa, bb, d, ii},
   cc = Table[If[i == 1 || i == nn, 2., 1.], {i, nn}];
   sg = (-1.)^Range[0, nn - 1];
   aa = sg cc; bb = sg/cc;
   d = Outer[Times, aa, bb]/(Outer[Subtract, xx, xx] + IdentityMatrix[nn])
      - IdentityMatrix[nn];
   ii = -Map[Total, d];
   d + DiagonalMatrix[ii]];

(* Flatten an nn x nn table with xi as the FAST index. *)
seNodeVec[m_] := Flatten[Transpose[m]];

(* max |.| guard: VectorQ on a NESTED list is False, so flatten first. *)
seEmx[v_] := If[VectorQ[v, NumericQ], N[Max[Abs[v]]], -1.];
seEmxM[m_] := seEmx[Flatten[m]];

(* Never print a huge / non-numeric expression. *)
seTrunc[e_] := Module[{s = ToString[e, InputForm]},
   StringTake[s, Min[300, StringLength[s]]]];

(* 5-point central derivative of an edge curve at t0 (|dt| ~ 1e-12). *)
seEdgeTan[f_, t0_] := Module[{h = 1.*^-4, g},
   g = N[f, 16];
   N[(g[t0 + 2 h] - 8 g[t0 + h] + 8 g[t0 - h] - g[t0 - 2 h])/(12 h)]];

seCross2[a_, b_] := a[[1]] b[[2]] - a[[2]] b[[1]];

(* ---------------------------------------------------------------------
   2.  Four-edge (transfinite / Coons) geometry
   ---------------------------------------------------------------------
   Edge signature, fixed by the API contract:
     bottom : xi  in [-1,1], the curve sits at eta = -1
     top    : xi  in [-1,1], the curve sits at eta = +1
     left   : eta in [-1,1], the curve sits at xi  = -1
     right  : eta in [-1,1], the curve sits at xi  = +1
   Each edge returns a 2-vector {x, y}. *)

seIsEdgeQ[e_] := MatchQ[e, _Function | _InterpolatingFunction];

sePatchEdges[p_] := Lookup[p, "Edges", {}];

(* The four vertices, in the order used by the transfinite blend:
     V1 = bottom(-1) = left(-1) , V2 = bottom(+1) = right(-1) ,
     V3 = top(-1)    = left(+1) , V4 = top(+1)    = right(+1) *)
seCorners[edges_List] := Module[{c1 = edges[[1]], c2 = edges[[2]]},
   {c1[-1], c1[1], c2[-1], c2[1]}];

(* G-B1 (a): corner CLOSURE.  Exact same expression as p11 `mkMap4`. *)
seCornerClosure[edges_List] := Module[{V = seCorners[edges], p},
   p = Max[Abs[V[[1]] - edges[[3]][-1]], Abs[V[[2]] - edges[[4]][-1]],
          Abs[V[[3]] - edges[[3]][1]],  Abs[V[[4]] - edges[[4]][1]]];
   N[p]];

(* G-B1 (b): corner METRIC consistency.  On the transfinite map
     d sm/d xi  restricted to eta = +-1  is the bottom/top edge tangent,
     d sm/d eta restricted to xi  = +-1  is the left/right edge tangent,
   so the map Jacobian at a patch corner is exactly the 2-D cross product
   of the two incident edge tangents.  It vanishes iff the boundary is
   smooth there (p11m2/p11m3 lesson: then J = 0 and the patch is dead).
   Order: {(-1,-1), (1,-1), (-1,1), (1,1)}. *)
seCornerCross[edges_List] := Module[{c1 = edges[[1]], c2 = edges[[2]],
     c3 = edges[[3]], c4 = edges[[4]]},
   N /@ {seCross2[seEdgeTan[c1, -1], seEdgeTan[c3, -1]],
         seCross2[seEdgeTan[c1,  1], seEdgeTan[c4, -1]],
         seCross2[seEdgeTan[c2, -1], seEdgeTan[c3,  1]],
         seCross2[seEdgeTan[c2,  1], seEdgeTan[c4,  1]]}];

(* Everything the gates need to know about one patch's corners. *)
seCornerConsistency[ed_] := Module[{cr = seCornerCross[ed], ac, mn, ix},
   ac = Abs /@ cr; mn = Min[ac];
   ix = First[Ordering[ac, 1, Greater]];
   <|"Closure" -> seCornerClosure[ed], "TangentCross" -> cr,
     "MinTangentCross" -> mn, "WorstCorner" -> ix,
     "NonDegenerate" -> (mn > 1.*^-8)|>];

(* The transfinite map itself: Function[{xi, eta}, {x, y}]. *)
seTransfinite[ed_] := Module[{c1 = ed[[1]], c2 = ed[[2]], c3 = ed[[3]],
     c4 = ed[[4]], V = seCorners[ed]},
   Function[{xx, yy},
     ((1 - yy)/2)*c1[xx] + ((1 + yy)/2)*c2[xx]
      + ((1 - xx)/2)*c3[yy] + ((1 + xx)/2)*c4[yy]
      - (((1 - xx)*(1 - yy)/4)*V[[1]] + ((1 + xx)*(1 - yy)/4)*V[[2]]
         + ((1 - xx)*(1 + yy)/4)*V[[3]] + ((1 + xx)*(1 + yy)/4)*V[[4]])]];

(* Evaluate the map on the CGL grid; {Xs, Ys} as nn x nn tables with
   xi indexing rows and eta indexing columns. *)
sePatchGrid[map_, xg_List] := Module[{nn = Length[xg]},
   {Table[map[a, b][[1]], {a, xg}, {b, xg}],
    Table[map[a, b][[2]], {a, xg}, {b, xg}]}];

(* ---------------------------------------------------------------------
   2b.  Method -> "AAA" : sample each edge, fit the sample with the AAA
   rational core, hand the FITS to the transfinite map.
   ---------------------------------------------------------------------
   WHY THIS LIVES HERE AND NOT IN Discretization.wl: the option belongs to
   CoonsPatch, the AAA core (Kernel/AAA.wl) is Get-ed BEFORE this file
   (API.md 2.3 rule 4), and the transfinite map below consumes whatever
   four edge functions it is handed -- so the whole method difference is
   "which four edge functions".  Nothing else in the paclet changes.

   CALL CONVENTIONS, MEASURED AGAINST Kernel/AAA.wl (not recalled):
     * aaazfit[zs_List, fs_List, tol_:1.0^-13, mmax_:100, nmax_:2000] returns
       an Association.  It NEVER signals a failure: every refusal comes back
       as "Status" -> "InputError" or "Failure" with a "Message" string.
       Measured: a non-numeric edge sample -> Status InputError, "zs and fs
       must be numeric lists"; an all-zero sample -> Status InputError.
       Anything that is not an Association with a usable Status must
       therefore be treated as a FAILURE, never as a fit.
     * aaaeval[fit, z] takes a scalar or a flat numeric list and returns the
       same shape (Reals for a real fit).  At a support node it returns the
       interpolatory limit f_j rather than the 0/0 NaN, so the corner checks
       are safe on t = -1 and t = +1.
     * Two fits per edge, x and y separately, NOT one complex fit of
       x + I y.  Measured on the sinusoid quad of Tests/aaageom.wl at 130
       samples per edge: the complex fit needs m = 9 for every edge, while
       the split fits need m = 2 on the coordinate that is affine in t and
       m = 9 on the curved one, at identical off-sample accuracy
       (max 8.9e-15) and identical wall clock.  The split fit also keeps the
       map REAL: a complex fit can leak ComplexInfinity at a pole, and a
       real map that returns non-finite on [-1,1] is the failure mode this
       branch must never ship.

   FIT QUALITY IS NOT AN ASSUMPTION HERE.  After the fits are built the
   branch re-evaluates them on a dense grid that deliberately reaches
   slightly OUTSIDE [-1,1] (seEdgeTan differentiates at t = -1 with
   h = 1e-4, so the map is called at -1 - 2e-4).  A fit with an interior
   pole shows up there as a non-finite value and is REJECTED through
   CoonsPatch::method, which is why "AAA could not fit this boundary"
   can never turn into a garbage patch.
   --------------------------------------------------------------------- *)

(* How far OUTSIDE [-1,1] the AAA branch has to be able to evaluate.
   seEdgeTan (section 1) forms its 5-point stencil with h = 1e-4 at t0 = -1
   and t0 = 1, so the corner-consistency check calls every edge at
   -1 - 2e-4 and 1 + 2e-4.  The frozen Analytic path therefore ALREADY
   assumes each edge extends cleanly by 2e-4; the AAA branch fits over
   [-1 - seAAAExtend, 1 + seAAAExtend] for exactly that reason.
   This is not cosmetic.  MEASURED (Tests/out/gp4.*.txt): a degree-(8,8) fit
   sampled on [-1,1] alone is finite at all 65 sample points (measured
   separately, per coordinate) and reproduces the corner to machine
   precision, yet the finiteness probe FAILED -- and the only points it adds
   beyond the sample grid are -1 - 2.2e-4 and 1 + 2.2e-4, so a pole of the
   approximant sits just outside the interval, where nothing in the data
   constrains it.  Sampling over the extended interval moves that pole out of
   the reach of every downstream consumer. *)
seAAAExtend = 2.5 1.*^-4;

(* Uniform AAA sample grid: exactly n equispaced points on
   [-1 - seAAAExtend, 1 + seAAAExtend], endpoints INCLUDED.
   Endpoints matter: the corner checks evaluate the fit at exactly t = -1 and
   t = 1, and AAA is interpolatory only at its own support points, so
   dropping them would make the corners sample-dependent.  The grid is built
   with Table rather than Subdivide because Subdivide[-1., 1., 65] was
   MEASURED to return 66 points, and AAASamples -> n has to mean exactly n. *)
seAAASampleGrid[n_Integer?Positive] := Module[{k = Max[4, n], lo = -1. - seAAAExtend, hi = 1. + seAAAExtend},
   Table[N[lo + (hi - lo) (i - 1)/(k - 1)], {i, k}]];

(* Dense finiteness probe over the whole reach: the sample interval itself,
   which already contains everything the map and seEdgeTan can ask for. *)
seAAAProbeGrid[] := Module[{lo = -1. - seAAAExtend, hi = 1. + seAAAExtend},
   Table[N[lo + (hi - lo) i/200], {i, 0, 200}]];

(* Sanitised AAASamples option value: anything non-numeric or below the
   core's 4-sample floor falls back to the documented default of 65 rather
   than reaching aaazfit as garbage.  This is option hygiene, not a method
   fallback: it cannot turn a rejected patch into an accepted one. *)
seAAAOptSamples[q_] := If[TrueQ[NumericQ[q]] && N[q] >= 4, Max[4, Round[N[q]]], 65];

(* Is this fit association usable?  "MaxIterationsReached" is accepted: a
   bounded type with a recorded relative error is a legitimate rational
   approximant, and the error is carried into the patch object so a caller
   can see it.  "InputError" and "Failure" are the core's two refusals. *)
seAAAUsableQ[fit_] := TrueQ[AssociationQ[fit]
   && MatchQ[Lookup[fit, "Status", None], "Converged" | "MaxIterationsReached"]
   && Length[Lookup[fit, "Nodes", {}]] >= 1
   && Length[Lookup[fit, "Values", {}]] === Length[Lookup[fit, "Nodes", {}]]
   && Length[Lookup[fit, "Weights", {}]] === Length[Lookup[fit, "Nodes", {}]]];

seAAADesc[fit_] := If[TrueQ[AssociationQ[fit] && StringQ[Lookup[fit, "Status"]]],
   Lookup[fit, "Status"] <> ": " <> Lookup[fit, "Message", ""],
   "the AAA core returned no fit association at all"];

seAAAFitSummary[fit_] := <|"Status" -> Lookup[fit, "Status", "?"],
   "Type" -> Lookup[fit, "Type", {0, 0}],
   "RelError" -> Lookup[fit, "RelError", -1.],
   "SupportSize" -> Length[Lookup[fit, "Nodes", {}]],
   "Support" -> Lookup[fit, "Nodes", {}]|>;

(* Finite real test for a flat numeric vector.  FiniteQ is NOT used: it is
   measured to answer FALSE for perfectly finite complex numbers in this
   kernel, so the test is spelled out (same idiom as Kernel/AAA.wl). *)
seAAAFiniteVecQ[v_] := TrueQ[VectorQ[v, NumericQ]
   && AllTrue[v, (TrueQ[NumericQ[#]] && Abs[#] < Infinity) &]];

(* The ONLY message names treated as a hard failure of the AAA branch.
   MEASURED (Tests/out/gp3.*.txt): a perfectly healthy 65-point sinusoid fit
   issues NINE messages -- Power::infy x3, Infinity::indet x3,
   General::stop x2, Part::partw -- all of them from aaapoles / aaaroots,
   i.e. from the pole-and-residue POST-PROCESSING this branch never consumes.
   So Check[expr, tag] with NO message list must not be used here: it treats
   every message as a failure and therefore rejects EVERY good fit (measured:
   Check[aaazfit[...], "TAG"] returned "TAG" for a fit whose relative error is
   at machine precision).  Instead the core is Quiet-ed -- that chatter is
   internal, not information for the user -- and the gate is seAAAUsableQ on
   the returned association, which is the documented integration contract
   (docs/AAA-NOTES.md section 1).

   THE THREE NAMES MUST BE WRITTEN AS A LITERAL LIST AT EACH CALL SITE.
   Check is HoldAll: it has to install its handler before expr runs, so it
   never evaluates its third argument.  Check[e, f, seAAAFatalMsgs] therefore
   FAILS TO EVALUATE AT ALL -- the kernel hands back the unevaluated Check --
   and the caller then receives a Check expression where a list of samples
   should be, so every fit is rejected as "does not sample to a finite real
   numeric vector".  Measured side by side on the same message, in this
   kernel: the literal {IterationLimit::itlim} returned "TA", the identical
   list reached through a symbol returned the unevaluated Check (Tests/out/
   gp4.*.txt).  No symbol is defined for the list on purpose: there is no way
   to name it here. *)
seAAAFitCoord[edge_, ts_List, j_Integer] := Module[{fs, fit, tag = "edge coordinate " <> ToString[j]},
   fs = Quiet[Check[N[Table[N[edge[t][[j]], 16], {t, ts}], MachinePrecision], "seAAA:sample", {IterationLimit::itlim, RecursionLimit::reclim, Stack::overflow}]];
   If[! TrueQ[seAAAFiniteVecQ[fs] && Length[fs] === Length[ts] && Length[ts] >= 4],
     Return[{"Fail", tag <> " does not sample to a finite real numeric vector of at least 4 points"}]];
   fit = Quiet[Check[aaazfit[ts, fs], "seAAA:fit", {IterationLimit::itlim, RecursionLimit::reclim, Stack::overflow}]];
   If[! TrueQ[seAAAUsableQ[fit]],
     Return[{"Fail", tag <> " could not be fit (" <> seAAADesc[fit] <> ")"}]];
   {"OK", fit}];

(* Build the fitted edge from the two fit associations.
   The associations go in as PATTERN variables of a plain SetDelayed rule so
   there is exactly one capture form in this file and it is the one whose
   semantics do not depend on Module's substitution rules.  (For the record,
   the Module-local form Function[{tt}, {aaaeval[u, tt], ...}] with u a
   Module local was MEASURED to capture by value as well, Tests/out/gp4.*.txt;
   it is not relied on here.) *)
seAAAFitFn[fx_, fy_] := Function[{tt}, {aaaeval[fx, tt], aaaeval[fy, tt]}];

(* Fit ONE edge.  Returns {"OK", Function, summary} or {"Fail", reason, {}}
   -- ALWAYS three elements, so the caller destructures with one pattern
   regardless of outcome.

   NB sx and sy ARE the two fit associations: `{rx, sx} = seAAAFitCoord[...]`
   assigns sx to the SECOND element of seAAAFitCoord's {"OK", fit} pair, i.e.
   to `fit`.  So the fit is passed on as `sx`, never as `sx[[2]]` -- the
   latter is fit["Values"], a plain list of sample values, and aaaeval on it
   is not a number (measured: every AAA patch was rejected as "not finite",
   with the probe itself measuring finite on the identical data). *)
seAAAFitEdge[edge_, ts_List] := Module[{rx, sx, ry, sy, probe},
   {rx, sx} = seAAAFitCoord[edge, ts, 1];
   If[TrueQ[rx === "Fail"], Return[{"Fail", sx, {}}]];
   {ry, sy} = seAAAFitCoord[edge, ts, 2];
   If[TrueQ[ry === "Fail"], Return[{"Fail", sy, {}}]];
   (* A fit can be exact on its sample grid and still carry a pole between
      two samples, so the whole reach is probed densely before the fit is
      handed over: a non-finite value anywhere is a rejection, not a patch. *)
   probe = Quiet[Check[N[Table[seAAAFitFn[sx, sy][z], {z, seAAAProbeGrid[]}], MachinePrecision], "seAAA:probe", {IterationLimit::itlim, RecursionLimit::reclim, Stack::overflow}]];
   If[! TrueQ[seAAAFiniteVecQ[Flatten[probe]]],
     Return[{"Fail", "the AAA fit of this edge is not finite across the interval the transfinite map and the corner checks evaluate (a pole of the rational approximant lies inside it); probe head " <> ToString[Head[probe], InputForm] <> " length " <> ToString[Length[probe]], {}}]];
   {"OK", seAAAFitFn[sx, sy], <|"X" -> seAAAFitSummary[sx], "Y" -> seAAAFitSummary[sy]|>}];

(* The failure branch, with NO Module at all -- pattern variables only. *)
seAAAFitFail[raw_List, bad_List] := {"Fail",
   "edge " <> ToString[First[Position[raw, bad]]] <> " of {bottom, top, left, right}: " <>
    bad[[2]], {}};

(* Decide OK / Fail from the four collected triples.  No Module, no
   Condition: an If with the two branches spelled out. *)
seAAAFitDecide[raw_List] := seAAAFitDecide1[raw, Select[raw, TrueQ[#[[1]] === "Fail"] &]];
seAAAFitDecide1[raw_List, bad_List] := If[TrueQ[Length[bad] > 0], seAAAFitFail[raw, bad[[1]]], {"OK", raw[[All, 2]], raw[[All, 3]]}];

(* Fit all four edges.  Returns {"OK", edges, info} or {"Fail", reason, {}}.

   Deliberately split into three tiny pieces with no loop inside any Module:
   measured, in this kernel, the single-body form
      Module[{raw}, raw = Table[...]; ...; {"OK", raw[[All, 2]], raw[[All, 3]]}]
   returned {"OK", {}, {}} -- the Table result never reached the returned
   expression -- while the identical Table evaluated at top level gave the
   right four rows (Tests/out/gp5.*.txt).  Nothing here needs a loop inside a
   Module, so nothing here is written that way.

   NB the tag test is `r === "Fail"` on the ALREADY DESTRUCTURED first
   element; `r[[1]] === "Fail"` would be First["Fail"] = "F", never true. *)
seAAAFitEdges[ed_List, ts_List] :=
   seAAAFitDecide[Table[seAAAFitEdge[ed[[k]], ts], {k, 1, Length[ed]}]];

(* ---------------------------------------------------------------------
   3.  Public: CoonsPatch / CoonsPatchQ / Format
   --------------------------------------------------------------------- *)

Options[SpectralElement`CoonsPatch] = {Method -> "Analytic",
   CornerTolerance -> 1.*^-12, AAASamples -> 65};

SpectralElement`CoonsPatch::edges = "CoonsPatch[{bottom, top, left, right}] wants FOUR pure functions of one variable returning {x, y}: bottom and top take xi in [-1,1] (bottom sits at eta = -1, top at eta = +1), left and right take eta in [-1,1] (left sits at xi = -1, right at xi = +1).";
SpectralElement`CoonsPatch::corners = "CoonsPatch: the four edges do not close at the corners: max corner mismatch = `1` exceeds the tolerance `2`. The transfinite (Coons) map needs exactly closing edges.";
SpectralElement`CoonsPatch::tangent = "CoonsPatch: at corner `1` the two incident edges are tangent to each other (|cross| = `2` is at or below `3`), so the transfinite map is DEGENERATE there (J = 0). Patch vertices must be TRUE corners of the domain; a smooth closed boundary has no corners.";
SpectralElement`CoonsPatch::method = "CoonsPatch: Method -> `1` cannot produce a patch. Reason: `2`. The two implemented methods are \"Analytic\", which evaluates the four edge curves exactly, and \"AAA\", which samples each edge on an equispaced grid and fits it with the AAA rational core. An unrecognised method name, an edge that does not sample to a finite real numeric vector, and an AAA fit that fails or is not finite on its own sample interval are all REJECTIONS: the patch is refused rather than silently downgraded to \"Analytic\", because a fallback would pass off a bad boundary as a good one.";
SpectralElement`CoonsPatch::qform = "CoonsPatchQ: `1` is not a CoonsPatch object.";

SpectralElement`CoonsPatch[edges_List, opts : OptionsPattern[]] :=
  Module[{ed = edges, tol, meth, ns, naa, fr, fEdges, fInfo, cl, cc, obj},
    If[Length[ed] =!= 4 || ! MatchQ[ed, {_Function, _Function, _Function, _Function}],
      Message[SpectralElement`CoonsPatch::edges]; Return[$Failed]];
    meth = OptionValue[Method];
    If[! TrueQ[StringQ[meth]] || ! MemberQ[{"Analytic", "AAA"}, meth],
      Message[SpectralElement`CoonsPatch::method, meth,
        "unrecognised method name"]; Return[$Failed]];
    naa = {};
    If[meth === "AAA",
      (* The fit happens BEFORE the corner and tangent checks, because the
         corner and tangent checks must be run on the edges the object will
         actually use -- the fits, not the functions that were passed in.
         Every refusal inside the AAA path ends here, as ::method, with the
         patch REJECTED: there is no fallback to "Analytic". *)
      ns = seAAAOptSamples[OptionValue[AAASamples]];
      {fr, fEdges, fInfo} = seAAAFitEdges[ed, seAAASampleGrid[ns]];
      If[TrueQ[fr === "Fail"],
        Message[SpectralElement`CoonsPatch::method, meth, fEdges];
        Return[$Failed]];
      ed = fEdges;
      naa = <|"Samples" -> ns, "Fits" -> fInfo|>];
    tol = N[OptionValue[CornerTolerance]];
    cl = seCornerClosure[ed];
    If[! TrueQ[N[cl <= tol]],
      Message[SpectralElement`CoonsPatch::corners, N[cl], tol];
      Return[$Failed]];
    cc = seCornerConsistency[ed];
    If[TrueQ[cc["NonDegenerate"]] === False,
      Message[SpectralElement`CoonsPatch::tangent, cc["WorstCorner"],
        cc["MinTangentCross"], 1.*^-8]];
    obj = <|"Type" -> "CoonsPatch", "Edges" -> ed, "Corners" -> seCorners[ed],
      "CornerClosure" -> cl, "CornerConsistency" -> cc,
      "CrossAtCorners" -> cc["TangentCross"],
      "CornerTolerance" -> tol, "Method" -> meth, "AAA" -> naa,
      "Map" -> seTransfinite[ed], "Domain" -> "SpectralElement`"|>;
    obj];

SpectralElement`CoonsPatch[___] :=
  (Message[SpectralElement`CoonsPatch::edges]; $Failed);

SpectralElement`CoonsPatchQ[obj_] := TrueQ[AssociationQ[obj]
   && Lookup[obj, "Type"] === "CoonsPatch"
   && MatchQ[Lookup[obj, "Edges", {}], {_Function, _Function, _Function, _Function}]
   && MatchQ[Lookup[obj, "Corners", {}], {_?ListQ, _?ListQ, _?ListQ, _?ListQ}]
   && MatchQ[Lookup[obj, "Map", {}], _Function]];

(* NO Format rules here, deliberately.  A Format LHS is evaluated at set
   time, so Format[SpectralElement`CoonsPatch[p_Association], form] := ...
   calls CoonsPatchQ on the bare Pattern object p_Association, which the
   CoonsPatch[___] catch-all then rejects -> CoonsPatch::edges plus
   SetDelayed::write on every single load, ending in General::stop which
   then swallows genuine ::edges messages for the whole session.  Measured
   by Tests/out/idprobe*.txt.  The object CoonsPatch returns is a plain
   Association, so a CoonsPatch[...] wrapper never appears in display and
   these rules would be unreachable anyway.  If a wrapped object is ever
   introduced, add Format there with HoldPattern on the pattern argument
   and re-prove that Get[Geometry.wl] fires ZERO messages. *)
(* ---------------------------------------------------------------------
   3b. Public map accessor (API.md 4.1 table row 3: owned by B, lives in
   Geometry.wl; its usage message belongs to the LOADER, not here).
   --------------------------------------------------------------------- *)
SpectralElement`CoonsPatchMap[p_Association, x_, y_] /;
   TrueQ[SpectralElement`CoonsPatchQ[p]] := Lookup[p, "Map"][x, y];
SpectralElement`CoonsPatchMap[___] := $Failed;


(* ---------------------------------------------------------------------
   4.  Analytic region edge builders (exact transfinite maps)
   --------------------------------------------------------------------- *)

(* Rectangle -> the IDENTITY map on the reference square, J = dx/dy. *)
seRectEdges[{x0_, y0_}, {x1_, y1_}] :=
  {Function[t, {x0 + (x1 - x0) (1 + t)/2, y0}],
   Function[t, {x0 + (x1 - x0) (1 + t)/2, y1}],
   Function[t, {x0, y0 + (y1 - y0) (1 + t)/2}],
   Function[t, {x1, y0 + (y1 - y0) (1 + t)/2}]};

(* One polar annular SECTOR.  xi <-> theta DECREASING and eta <-> r
   INCREASING give J = r (dtheta) (dr) > 0 (p11m4's orientation fix);
   |dtheta/dxi| = span/2, |dr/deta| = (r2-r1)/2, so
        J = rEta span (r2-r1)/4  and  min J = r1 span (r2-r1)/4 .
   With span = pi this is EXACTLY p11 E2's mkHalf: the r in [1,1.5] half
   of the r in [1,2] half-annulus has min J = pi/8 and the [1.5,2] half
   min J = 3 pi/16 (both reproduced by Tests/geoprobe.wl G-B5).

   TRAP PINNED HERE (a silent, sector-count-dependent bug): the sector
   helpers must NOT be created with SetDelayed inside the Module.  Written
   that way they become GLOBAL, MUTABLE symbols and the four returned
   Functions capture the SYMBOLS, not their values, so every earlier
   sector's edges silently re-evaluate with the LAST call's parameters.
   With one sector that is invisible; with ns > 1 sectors (an Annulus
   spanning 2 pi) all sectors then sample identically, the interface
   detector reports 4 interfaces instead of 2, and ::iface / ::junc fire.
   Every sector parameter is therefore baked into the closures as a NUMBER
   below. *)
seAnnulusEdges[{r1_, r2_}, {th1_, th2_}] := Module[{dth = N[th2 - th1],
     thm = (th1 + th2)/2, r0 = (r1 + r2)/2, dr = (r2 - r1)/2},
  {Function[t, r1 {Cos[thm - dth t/2], Sin[thm - dth t/2]}],
   Function[t, r2 {Cos[thm - dth t/2], Sin[thm - dth t/2]}],
   Function[t, (r0 + dr t) {Cos[th2], Sin[th2]}],
   Function[t, (r0 + dr t) {Cos[th1], Sin[th1]}]}];

(* Number of angular sectors used for an angular span. *)
seAnnulusSectors[span_] := N[Ceiling[Abs[span]/Pi]];

(* ---------------------------------------------------------------------
   5.  Internal gate helpers (used by Tests/geoprobe.wl)
   --------------------------------------------------------------------- *)
seMinJ[p_Association] := N[Min[Flatten[p["J"]]]];
seNonPositiveJ[p_Association] := Count[Flatten[p["J"]], _?(# <= 0 &)];
seCornerJ[p_Association] := Module[{nn = p["Nodes"], J = p["J"]},
   N /@ {J[[1, 1]], J[[nn, 1]], J[[1, nn]], J[[nn, nn]]}];
(* max |Lop - (Id (x) D2 + D2 (x) Id)| : the flat-degeneracy gate G2/G-B3.
   NOTE: the Kronecker sum MUST live on ONE physical line -- a newline
   after a syntactically complete expression terminates it and a leading
   `+` on the next line is a separate discarded expression (this exact bug
   produced g2 = 35196 in p11). *)
seFlatDegeneracy[ops_Association] := Module[{nn = ops["Nodes"], D2 = ops["D2m"], Lop = ops["Lop"], ref},
   ref = KroneckerProduct[IdentityMatrix[nn], D2] + KroneckerProduct[D2, IdentityMatrix[nn]];
   seEmxM[Normal[Lop - ref]]];
