(* =====================================================================
   Kernel/Solve.wl -- SpectralElement` , SOLVER LAYER
   ---------------------------------------------------------------------
   Owner: D (wave 2).  Loaded by Kernel/SpectralElement.wl from INSIDE
   Begin["SpectralElement`Private"], so every bare symbol defined here
   lands in SpectralElement`Private` and the two PUBLIC entry points are
   written FULLY QUALIFIED (loader contract, SpectralElement.wl L18-25).

   WHAT THIS FILE DOES
     1. messages        SpectralNDSolve::nlnum / ::ncond (API.md 4.4 says
                        both are owned HERE) plus a few misuse messages.
     2. parsing         split {x, y} \[Element] \[CapitalOmega]; split a
                        PDE equation into (operator coefficient, rest,
                        rhs); collect DirichletCondition -> {pred, value}.
     3. assembly        stack the PDE and flux row blocks into one
                        operator matrix A0, the right-hand side and the
                        Dirichlet lift constant.
     4. solvers         LinearSolve when the equations are linear,
                        Newton otherwise, with the iteration history
                        (dels) recorded so quadratic convergence is
                        assertable.  Both stop on a tolerance, both are
                        capped, and a NON-NUMERIC LinearSolve answer is
                        caught by seLinSolve and never propagated.
     5. solution        a pure Function of (x, y): the transfinite map is
                        inverted by Newton from the nearest node, then a
                        tensor-product Clenshaw-Curtis (barycentric)
                        interpolant is read in reference coordinates.
                        Exact at every node by construction.

   CONTRACTS HONOURED (API.md 4.3)
     * Return shape mimics NDSolve: {{u -> Function[...]{...}}} and the
       bare function for SpectralNDSolveValue.
     * \[CapitalOmega] = CoonsPatch list | SpectralDiscretization (consumed
       AS-IS, never rebuilt) | region shorthand (Rectangle / Annulus).
     * NO DirichletCondition  =>  homogeneous Dirichlet u == 0 on the whole
       exterior boundary (see seDirLiftFn: an unmatched node gets 0).

   OPERATOR SIGN CONVENTION (pinned by p11.191455_3044.txt)
     The discretized operator is +Laplacian.  A PDE written
     -Laplacian[u] + u^3 == f therefore assembles as -Lop.U + U^3, i.e.
     opCoefficient = -1 and A0 = (-opCoefficient) * (assembled Matrix),
     which for the contract form IS the assembled Matrix itself.  The sign
     is touched in exactly ONE place (seOperatorParts -> "OperatorCoefficient",
     consumed by seStackOperator) and nowhere else.

   TRAPS OBSERVED HERE (all measured; see Tests/bench.wl)
     * A Module initializer does NOT see the value of an EARLIER
       initializer in the same list, so every dependent value is assigned
       in the BODY.  (6 repo-wide failures came from this.)
     * Total[list], never one-argument Sum[list] (Sum needs an iterator and
       stays symbolic otherwise).
     * Function[{a, b}, body] is an APPLICAND; Function[ab_, body] is not.
     * Cases[list, patt] collects; Cases[list, patt -> rhs] REPLACES.
     * A top-level expression terminates at a newline, so nothing here
       relies on a leading '+' continuing the previous line.
     * $MessageList is Protected: it cannot be assigned; read Length and
       slice instead.
     * ArrayPad[m, {0, 0, 0, 0}] on a 2-D m raises ArrayPad::depth, so the
       block stacking below skips the pad when the block already has the
       full column count.  (Kernel/Discretization.wl L136 always pads and
       therefore leaves System["Matrix"] unusable for EVERY domain; this
       file does not depend on it.)

   Known upstream defect (NOT worked around by editing another owner's
   file, reported instead): Discretization.wl L136 builds
   System["Matrix"] with ArrayPad[..., {0,0,0, Max[0, nTot - Last[Dims]]}] &.
   Every block matrix already has nTot columns, so the pad is always 0 and
   ArrayPad raises ArrayPad::depth, leaving Matrix with Dimensions {2}.
   seStackOperator below rebuilds the same stack correctly, so the solver
   is unaffected.
   ===================================================================== *)

(* ------------------------------------------------------------------ *)
(* 1.  Messages -- API.md 4.4: both owned names live HERE              *)
(* ------------------------------------------------------------------ *)
SpectralElement`SpectralNDSolve::nlnum =
  "SpectralNDSolve: Newton did not converge -- `1` iteration(s) run, last \
step norm `2` (tolerance `3`), last residual norm `4` (tolerance `5`).";
SpectralElement`SpectralNDSolve::ncond =
  "SpectralNDSolve: no boundary condition was supplied and the \
homogeneous-Dirichlet default is not applicable: `1`.";
SpectralElement`SpectralNDSolve::form =
  "SpectralNDSolve: the equation must be a single lhs == rhs as NDSolve \
writes it, with u an application and exactly one Laplacian term; got \
`1`.";
SpectralElement`SpectralNDSolve::ndom =
  "SpectralNDSolve: the third argument must be {x, y} \[Element] \
\[CapitalOmega] with two independent symbols; got `1`.";
SpectralElement`SpectralNDSolve::nreg =
  "SpectralNDSolve: \[CapitalOmega] = `1` did not produce a \
SpectralDiscretization (see the SpectralDomain message above).";
SpectralElement`SpectralNDSolve::method =
  "SpectralNDSolve: Method -> `1` is unknown; use \"Automatic\", \
\"Newton\" or \"Linear\".";
SpectralElement`SpectralNDSolve::nsolve =
  "SpectralNDSolve: LinearSolve returned a non-numeric result (`1`) on \
the assembled system; the discretization or the boundary data is \
singular.";
SpectralElement`SpectralNDSolve::nlift =
  "SpectralNDSolve: the Dirichlet lift did not evaluate to numbers -- \
`1` non-numeric boundary node value(s) -- so no numeric system can be \
assembled; check the DirichletCondition data.";
SpectralElement`SpectralNDSolve::ndeg =
  "SpectralNDSolve: the degree must be an integer >= 2; got `1`.";

(* ------------------------------------------------------------------ *)
(* 2.  Options                                                         *)
(* ------------------------------------------------------------------ *)
Options[SpectralElement`SpectralNDSolve] =
  {Method -> "Automatic", Tolerance -> Automatic, MaxIterations -> 30,
   "DomainOptions" -> {}, AccuracyGoal -> Automatic,
   PrecisionGoal -> Automatic};
Options[SpectralElement`SpectralNDSolveValue] =
  Options[SpectralElement`SpectralNDSolve];

(* Tolerance resolution order: explicit Tolerance, then AccuracyGoal,
   then PrecisionGoal, then p11's own stopping rule 1.*^-13. *)
seTolerance[ag_, pg_, tol_] := Which[! TrueQ[tol === Automatic], N[tol],
  TrueQ[NumericQ[ag]], N[10.^(-N[ag])], TrueQ[NumericQ[pg]], N[10.^(-N[pg])],
  True, 1.*^-13];

(* ------------------------------------------------------------------ *)
(* 3.  Argument surgery                                                *)
(* ------------------------------------------------------------------ *)

(* Element is an inert Protected symbol, so {x, y} \[Element] \[CapitalOmega]
   arrives as Element[{x, y}, \[CapitalOmega]] and patterns see it. *)
(* The general rule is defined FIRST so that the specific Element rule,
   being newer, is tried first by the DownValue search.  The pattern v_ is a
   real left-hand-side pattern here: a Which/If CONDITION alone does not
   create a local symbol, and the value branch would then read a GLOBAL v. *)
seDomainVars[_] := Automatic;
seDomainVars[Element[v_, _]] := v;
seDomainRegion[r_] := r;
seDomainRegion[Element[_, r_]] := r;

(* Every DirichletCondition of eq becomes a {predicate, value} pair.  The
   predicate is kept SYMBOLIC: it is written in the independent variables,
   exactly as in NDSolve (API.md 4.3). *)
seDCValue[val_, u_, {x_, y_}] :=
  Which[Head[val] === Equal && TrueQ[MatchQ[Part[val, 1], u[_, _]]],
      Part[val, 2], TrueQ[MatchQ[val, u[_, _]]], 0, True, val];

(* Every DirichletCondition of eq becomes a {predicate, value-function}
   pair.  The predicate is kept SYMBOLIC: it is written in the independent
   variables, exactly as in NDSolve (API.md 4.3).  The value is turned into
   a PURE FUNCTION of two arguments right here, because a bare symbol such
   as uex[x, y] would never be evaluated at a node -- N[uex] is still the
   symbol uex (measured), not uex[x, y] with x, y substituted. *)
(* TRAP (measured here, this was the wave-2 blocker): SeUnevaluated is NOT
   an evaluator-suppressor in this kernel any more -- it is an ordinary
   undefined symbol, so SeUnevaluated[expr] stays as
   SeUnevaluated[expr] and every predicate built with it silently matched
   no node at all (emx[Parts["Lift"]] == 0).  Plain Part is correct and
   needs no protection: Equal and the predicate expressions are already
   inert. *)
seDirConditions[eq_, u_, {x_, y_}] := Module[{dcs, v},
  dcs = Cases[{eq}, DirichletCondition[_, _], Infinity];
  Table[v = seDCValue[Part[dcs[[k]], 1], u, {x, y}];
    {Part[dcs[[k]], 2], Function[{ax, ay}, v /. {x -> ax, y -> ay}]},
    {k, 1, Length[dcs]}]];

(* The Dirichlet lift as a FUNCTION of a physical point: the value of the
   FIRST matching DirichletCondition, and 0 when nothing matches.  That 0
   is the homogeneous-Dirichlet default of API.md 4.3.
   TRAP (measured here): Function[{qx_, qy_}, body] raises Function::flpar
   -- the parameter names must be plain symbols, and Module has already
   renamed any qx_ appearing in the body, so the underscore form is doubly
   wrong.  Function[{qx, qy}, body] is the correct applicand form. *)
seDirLiftFn[{}, _, _] := 0;
seDirLiftFn[dc_List, x_, y_] := Function[{qx, qy},
   Module[{ndc, hit, kk},
    ndc = Length[dc];
    hit = 0;
    Do[If[TrueQ[N[Part[dc[[kk]], 1] /. {x -> qx, y -> qy}]],
         hit = N[Part[dc[[kk]], 2][qx, qy]]], {kk, 1, ndc}];
    hit]];

(* The PDE equation, written as
      opCoefficient * Laplacian + rest  ==  rhs
   by substituting the single Laplacian term with a fresh symbol and
   reading off its coefficient.  rest is everything that is left (for the
   contract form -Laplacian[u] + u^3 == f it is exactly u^3). *)
(* TRAP (measured here): Laplacian[u[x, y], {x, y}] does NOT keep the head
   Laplacian -- the kernel rewrites it to
   Derivative[0, 2][u][x, y] + Derivative[2, 0][u][x, y], so matching on
   Head === Laplacian finds NOTHING and every equation is rejected.  The
   reference operator is therefore rebuilt from the independent variables
   and its pure-derivative terms are used as the pattern to strip. *)
seLaplacianTerms[u_, {x_, y_}] := Module[{refL},
  refL = Laplacian[u[x, y], {x, y}];
  Cases[refL, t_ /; MatchQ[t, Derivative[__][_][_, _]], Infinity]];

(* The PDE equation, written as
      OperatorCoefficient * Laplacian + rest  ==  rhs
   with rest everything that is left (for the contract form
   -Laplacian[u] + u^3 == f it is exactly u^3). *)
seOperatorParts[eq_, u_, {x_, y_}] := Module[
   {eqs, lhs, rhs, refL, refTerms, found, sub, co, rest, one, d1},
  (* DirichletCondition terms are stripped first, and one list level is
     flattened, so an Equal inside a DirichletCondition can never be
     mistaken for the PDE and the depth of eq does not matter *)
  eqs = Cases[Flatten[DeleteCases[{eq}, DirichletCondition[_, _], Infinity], 1],
    _Equal, {1}];
  (* An equation list with NO equation at all is a boundary-data problem,
     not a malformed PDE: there is nothing for the boundary condition (nor
     for the homogeneous default) to be applied to. *)
  If[ListQ[eqs] && Length[eqs] === 0,
    Message[SpectralElement`SpectralNDSolve::ncond,
      "the equation list contains no PDE equation, so no boundary condition can be applied to anything"];
    Return[$Failed]];
  If[! ListQ[eqs] || Length[eqs] =!= 1,
    Message[SpectralElement`SpectralNDSolve::form, eq]; Return[$Failed]];
  lhs = Part[First[eqs], 1];
  rhs = Part[First[eqs], 2];
  refL = Laplacian[u[x, y], {x, y}];
  refTerms = seLaplacianTerms[u, {x, y}];
  found = Cases[lhs, Alternatives @@ refTerms, Infinity];
  If[! ListQ[refTerms] || Length[refTerms] === 0 ||
      ! ListQ[found] || Length[found] === 0,
    Message[SpectralElement`SpectralNDSolve::form, eq]; Return[$Failed]];
  one = 1/Length[refTerms];
  sub = lhs /. (t_ /; MemberQ[refTerms, t] :> zz);
  co = Simplify[Coefficient[sub, zz]] one;
  If[! TrueQ[NumericQ[N[co]]],
    Message[SpectralElement`SpectralNDSolve::form, eq]; Return[$Failed]];
  (* the EXACT coefficient is used here: mixing an exact -1 with a machine
     -1. makes Simplify leave the operator terms in, and the guard below
     would then reject a perfectly good equation *)
  rest = Simplify[lhs - co refL];
  If[Length[Cases[rest, Alternatives @@ refTerms, Infinity]] > 0,
    Message[SpectralElement`SpectralNDSolve::form, eq]; Return[$Failed]];
  d1 = Simplify[D[rest, u[x, y]]];
  <|"OperatorCoefficient" -> N[co], "Rest" -> rest, "RHS" -> rhs,
    "LaplacianTerm" -> refL, "LaplacianTerms" -> refTerms,
    "RestDerivative" -> d1,
    "NonlinearQ" -> ! TrueQ[FreeQ[d1, u[x, y]]]|>];

(* evaluate an expression of {x, y, u} at one node.

   TRAP -- MEASURED, and it was the whole P2 stall: the dependent function
   must be the CALLER'S symbol, not a bare `u`.  A bare `u` written here
   resolves to SpectralElement`Private`u, while the `u` in the user's
   equation is (here) Global`u, so the replacement rule u[x,y] -> uv never
   matched, seAtNode returned the UNevaluated expression, and every nonlinear
   residual was symbolic.  LinearSolve on that symbolic sparse Jacobian is
   what burned the 2400 s (RC=137) at degree 10; at degree 4 it already
   took 16 s and then raised SpectralNDSolve::nsolve ("non-numeric result
   (Symbol)").  The defect was invisible for LINEAR problems because
   seRowTermVec short-circuits on Rest === 0 and never calls seAtNode.  The
   symbol is threaded in from the equation, as `u`, in every caller. *)
seAtNode[e_, xv_, yv_, uv_, {x_, y_}, u_] :=
  N[e /. {x -> xv, y -> yv, u[x, y] -> uv}];

(* ------------------------------------------------------------------ *)
(* 3b.  Gather the nodal values of one iterate                         *)
(* ------------------------------------------------------------------ *)

(* TRAP (measured here): Selections[[p]] . z, with a SparseArray matrix and
   a plain List vector, raises Dot::dotsh in this kernel, so the assembled
   selection matrices cannot be used as maps.  The same information is in
   System["Loc"]: loc[[p, k]] is the global column of flat node k of patch p
   (0 when the node is lifted away).  Gathering directly by Part is O(nn^2)
   per patch, exact, and free of any linear-algebra convention. *)
seGather[disc_, lift_, z_] := Module[{sy, loc, np, nn, out, p, k},
  (* TRAP (measured here): a Module initializer CANNOT read another
     initializer -- `loc = sy["Loc"]` in the initializer list silently
     reads a GLOBAL sy and leaves loc unevaluated.  Every dependent value is
     therefore assigned in the BODY. *)
  sy = disc["System"];
  loc = sy["Loc"];
  np = Length[disc["PatchOps"]];
  nn = disc["NodeCount"];
  out = Table[0., {p, 1, np}, {k, 1, nn^2}];
  Do[
    out[[p, k]] = If[Part[loc[[p]], k] > 0, z[[Part[loc[[p]], k]]],
       Part[lift[[p]], k]], {k, 1, nn^2}, {p, 1, np}];
  out];

(* ------------------------------------------------------------------ *)
(* 4.  Assembly of the coupled system                                  *)
(* ------------------------------------------------------------------ *)

(* right-hand side on the PDE rows of patch p, in that block's own ROW
   order (a subset of InteriorRows when a BoundaryPredicate forced extra
   nodes to Dirichlet, so the block's Rows is used, never InteriorRows).

   TRAP -- MEASURED, and it was THE reason the assembled system solved to
   5e-14 while u was O(1) wrong at every degree (the wave-2 P0 defect):

     Rows is a list of FLAT node indices, in ascending order, but it is NOT
     1..Length[rows].  The interior line of nodes is separated by a FULL
     stride nn, not by nn-2, so position j and flat index rows[[j]] differ
     from the second line onwards (nn=7, first interior node 9 = (2,2),
     but position 1 decodes to (1,1) = a CORNER).  Decoding the POSITION j
     therefore sampled f at the wrong nodes -- at Dirichlet corners for the
     first line, then marching diagonally through the patch.

     The row index is rows[[j]]; the node is its xi-fast decode
     ix = Mod[k-1, nn]+1, iy = Quotient[k-1, nn]+1.  Measured after the
     fix: max|seRowFvec - seFvec| = 0 against Discretization.wl's own
     sampling routine, and max|A0.zex + c0 - rhs| falls from 18.8 (n=6) to
     ~1e-13. *)
seRowFvec[disc_, p_Integer, g_] := Module[{o, nn, rows, j, kk, jj, ii},
  o = disc["PatchOps"][[p]];
  nn = disc["NodeCount"];
  rows = disc["System"]["PDE"][[p]]["Rows"];
  Table[Module[{kk, jj, ii},
      kk = rows[[j]];
      jj = Mod[kk - 1, nn] + 1;
      ii = Quotient[kk - 1, nn] + 1;
      N[g[o["Xs"][[jj, ii]], o["Ys"][[jj, ii]]]]],
    {j, 1, Length[rows]}]];

(* the stacked RHS: PDE blocks carry f, flux blocks carry 0 (flux
   continuity is a homogeneous relation) *)
seAssembleRHS[disc_, rhs_, x_, y_] := Module[{s = disc["System"],
    np = Length[disc["PatchOps"]], out},
  out = Table[seRowFvec[disc, p, Function[{qx, qy},
        rhs /. {x -> qx, y -> qy}]], {p, 1, np}];
  (* Flatten one level: the blocks are vectors, and LinearSolve needs the
     right-hand side of the FULL system to be one flat row vector, not a
     list of per-patch vectors. *)
  Flatten[Join[out, Table[ConstantArray[0., s["Flux"][[m]]["RowCount"]],
    {m, 1, s["FluxCount"]}]], 1]];

(* the constant (unknown-independent) part of the residual: the lift of
   the Dirichlet data.  PDE block p contributes opCoeff Lop_sub . lift_p,
   flux block m contributes cA NDopA . liftA + cB NDopB . liftB. *)
seLiftConst = Function[{disc, opc, lift}, Module[{sy, np, out},
  sy = disc["System"];
  np = Length[disc["PatchOps"]];
  out = Table[Module[{pde},
      pde = sy["PDE"][[p]];
      N[opc] pde["Lop"].lift[[p]]], {p, 1, np}];
  out = Join[out, Table[Module[{fl, pa, pb},
      fl = sy["Flux"][[m]];
      pa = fl["PatchA"];
      pb = fl["PatchB"];
      N[fl["Coefficients"][[1]] fl["NDopA"].lift[[pa]]]
        + N[fl["Coefficients"][[2]] fl["NDopB"].lift[[pb]]]],
    {m, 1, sy["FluxCount"]}]];
  Flatten[out, 1]]];

(* Stack the row blocks into one sparse operator matrix.  ArrayPad is
   applied ONLY when a block is narrower than the unknown count, because
   ArrayPad[m, {0,0,0,0}] on a 2-D m raises ArrayPad::depth. *)
sePadBlock[m_, nTot_] := If[TrueQ[Last[Dimensions[m]] === nTot], m,
   ArrayPad[m, {0, 0, 0, nTot - Last[Dimensions[m]]}]];

seStackOperator[disc_, opc_] := Module[{s = disc["System"],
    np = Length[disc["PatchOps"]], nif, nTot, nRow, mats},
  nif = s["FluxCount"];
  nTot = s["UnknownCount"];
  nRow = s["RowCount"];
  mats = Join[Table[s["PDE"][[p]]["Matrix"], {p, 1, np}],
              Table[s["Flux"][[m]]["Matrix"], {m, 1, nif}]];
  (* TRAP (measured here): ArrayFlatten[{m}] with ONE 2-D block m returns
     a rank-3 {1, 49, 49} object, because the one-element outer list is
     itself a level.  ArrayFlatten[list, 1] keeps level 0 and merges all
     deeper levels, which is the vertical concatenation of the row blocks
     for ANY number of blocks, including exactly one. *)
  N[-opc] SparseArray[ArrayFlatten[sePadBlock[#, nTot] & /@ mats, 1],
    {nRow, nTot}]];

(* The nonlinear term and its derivative, as full-length row vectors with
   the flux rows left at 0.  Row p-th PDE block starts at RowSlices[[p]].

   TRAP -- the SAME row-index defect as seRowFvec, measured: the flat node
   index is rws[[k]], not the loop POSITION k (see the note on seRowFvec).
   Before the fix u^3 was evaluated at the corner / diagonal-shifted nodes,
   so the Newton residual was not a function of the unknowns in the rows it
   claimed, and no Newton iteration could converge.  Uv is already selected
   by rws, so Uv[[k]] is right; only the node coordinates were wrong. *)
seRowTermVec[disc_, z_, e_, vars_, lift_, us_] := Module[{s = disc["System"],
    np = Length[disc["PatchOps"]], nn = disc["NodeCount"], nRow, out,
    p, sl, rws, Uv, kk, ix, iy, k},
  nRow = s["RowCount"];
  If[TrueQ[e === 0], Return[ConstantArray[0., nRow]]];
  out = ConstantArray[0., nRow];
  Do[
    sl = s["RowSlices"][[p]];
    rws = s["PDE"][[p]]["Rows"];
    Uv = Part[seGather[disc, lift, z], p][[rws]];
    Do[
      kk = rws[[k]];
      ix = Mod[kk - 1, nn] + 1;
      iy = Quotient[kk - 1, nn] + 1;
      out[[sl[["First"]] + k - 1]] =
        seAtNode[e, disc["PatchOps"][[p]]["Xs"][[ix, iy]],
          disc["PatchOps"][[p]]["Ys"][[ix, iy]], Uv[[k]], vars, us],
      {k, 1, Length[rws]}],
    {p, 1, np}];
  out];

seNLVec[disc_, z_, ctx_, lift_] :=
  seRowTermVec[disc, z, ctx["Rest"], ctx["vars"], lift, ctx["u"]];
seD1Vec[disc_, z_, ctx_, lift_] :=
  seRowTermVec[disc, z, ctx["RestDerivative"], ctx["vars"], lift, ctx["u"]];

(* residual  R(z) = A0.z + c0 + NL(z) - rhs *)
seResidual[z_, A0_, c0_, nl_, rhs_] := A0.z + c0 + nl - rhs;

(* Jacobian  J(z) = A0 + diag(dRest/du)  (band-diagonal on the PDE rows) *)
seJacobian[z_, A0_, d1_, nRow_, nTot_] :=
  A0 + SparseArray[Band[{1, 1}] -> d1, {nRow, nTot}];

(* ------------------------------------------------------------------ *)
(* 5.  LinearSolve wrapper -- a non-numeric INPUT is refused UP FRONT  *)
(* ------------------------------------------------------------------ *)
seEmx2[v_] := If[TrueQ[VectorQ[Flatten[v], NumericQ]],
    N[Max[Abs[Flatten[v]]]], Infinity];
(* TRAP -- MEASURED, and it is why the old post-check could not fire: fed a
   NON-NUMERIC right-hand side, LinearSolve does not fail and does not return
   either.  It enters symbolic algebra on the tagged entries of the vector and
   runs until the 900 s guard kills the kernel
   (Tests/out/installprobe.104951_54302.txt).  The right-hand side that did
   that was rhs - c0, non-numeric solely because of the precision-tagged zeros
   in the Dirichlet lift (see seLiftNode in Kernel/Discretization.wl), so the
   VectorQ test that used to run only on the RESULT was reached never.  The
   input is therefore checked first and turned into $Failed, which seLinear /
   seNewton already turn into SpectralNDSolve::nsolve and a $Failed solve.  A
   precondition, not a timeout and not a Quiet: it makes the hang structurally
   unreachable instead of hiding it. *)
seLinSolve[m_, b_] := Module[{r},
  If[! TrueQ[VectorQ[Flatten[b], NumericQ]], Return[$Failed]];
  r = Quiet@Check[LinearSolve[m, b], $Failed];
  If[! TrueQ[VectorQ[Flatten[r], NumericQ]], $Failed, r]];

(* ------------------------------------------------------------------ *)
(* 6.  Newton                                                          *)
(* ------------------------------------------------------------------ *)
seNewton[disc_, ctx_, A0_, c0_, rhs_, lift_, tol_, maxIt_] := Module[
   {s = disc["System"], nTot, nRow, z, dz, R, J, dels, rnorm, dn, it, conv},
  nTot = s["UnknownCount"];
  nRow = s["RowCount"];
  z = ConstantArray[0., nTot];
  dels = {};
  rnorm = Infinity;
  dn = Infinity;
  conv = False;
  Do[
    R = seResidual[z, A0, c0, seNLVec[disc, z, ctx, lift], rhs];
    rnorm = seEmx2[R];
    J = seJacobian[z, A0, seD1Vec[disc, z, ctx, lift], nRow, nTot];
    dz = seLinSolve[J, -R];
    If[dz === $Failed,
      Message[SpectralElement`SpectralNDSolve::nsolve,
        Head[dz]];
      Break[]];
    dn = seEmx2[dz];
    AppendTo[dels, dn];
    z = z + dz;
    If[TrueQ[dn < tol || rnorm < tol], conv = True; Break[]],
  {it, 1, maxIt}];
  (* the residual at the LAST accepted iterate, for the record *)
  R = seResidual[z, A0, c0, seNLVec[disc, z, ctx, lift], rhs];
  rnorm = seEmx2[R];
  If[! TrueQ[conv],
    Message[SpectralElement`SpectralNDSolve::nlnum, Length[dels], dn,
      tol, rnorm, tol]];
  <|"Global" -> z, "Dels" -> dels, "Iterations" -> Length[dels],
    "Converged" -> conv, "FinalStep" -> dn, "FinalResidual" -> rnorm,
    "Method" -> "Newton"|>];

seLinear[disc_, ctx_, A0_, c0_, rhs_, lift_, tol_] := Module[{z, r},
  z = seLinSolve[A0, rhs - c0];
  If[z === $Failed,
    Message[SpectralElement`SpectralNDSolve::nsolve,
      Head[z]];
    Return[$Failed]];
  r = seEmx2[seResidual[z, A0, c0, ConstantArray[0., Length[rhs]], rhs]];
  <|"Global" -> z, "Dels" -> {}, "Iterations" -> 1, "Converged" -> True,
    "FinalStep" -> r, "FinalResidual" -> r, "Method" -> "Linear"|>];

(* ------------------------------------------------------------------ *)
(* 7.  The returned solution function                                  *)
(* ------------------------------------------------------------------ *)

(* tensor-product Clenshaw-Curtis (barycentric) interpolation on the CGL
   node set; the early return on a node hit makes it exact AT the nodes *)
seCGLBary[vals_List, xg_List, xx_] := Module[{nn = Length[xg], w, k, d, tol},
  If[! TrueQ[NumericQ[xx]], Return[Indeterminate]];
  tol = 2.*^-10 Abs[N[Part[xg, nn] - Part[xg, 1]]];
  w = Table[If[i === 1 || i === nn, 0.5 (-1)^(i - 1), (-1)^(i - 1)],
    {i, nn}];
  k = SelectFirst[Range[nn], Abs[N[Part[xg, #]] - N[xx]] < tol &];
  (* TRAP (measured here, and it is THE reason the returned Function
     answered Indeterminate at every node): the two-argument Return is only
     meaningful inside Loop.  Inside a Module it does NOT return, so the
     node-hit shortcut was dead and control fell through to the
     barycentric formula, whose weights contain 0/(x - x_i) = 0/0 AT a node
     -> Indeterminate.  One-argument Return exits the Module. *)
  If[TrueQ[NumericQ[k]], Return[N[vals[[k]]]]];
  d = N[xx] - N[xg];
  N[Total[N[vals]*w/d]/Total[w/d]]];

(* TRAP (measured here): v is the FLATTENED nodal vector of one patch, i.e.
   k = (ix - 1)*nn + iy with xi fastest.  The eta pass must interpolate one
   WHOLE COLUMN at a time, and v[[ix]] is a single scalar, not a column --
   seCGLBary then sees a non-List and does not apply at all, the symbolic
   leftover poisons the outer pass, and the returned Function answers
   Indeterminate at every point.  Take[v, {ix, nn, nn}] is the column;
   note Part[v, {ix, nn}] is a LIST OF INDICES in WL, not a stride. *)
seCGLBary2[v_, xg_List, xi_, eta_] := Module[{nn = Length[xg]},
  seCGLBary[Table[seCGLBary[Table[Part[v, ix + j nn], {j, 0, nn - 1}], xg, eta], {ix, nn}], xg, xi]];

(* Newton inversion of the transfinite map, started from the reference
   coordinates of node k (the nearest node).  The analytic Jacobian is
   taken from PatchOps, so no finite differences are involved. *)
seRefInverse[maps_, Jf_, pts_, xga_, k_, ax_, ay_] := Module[
   {ps, ix0, iy0, xi, eta, d, J, dxi, i},
  ps = Part[pts, k, 2];
  ix0 = Part[pts, k, 3];
  iy0 = Part[pts, k, 4];
  xi = xga[[ix0]];
  eta = xga[[iy0]];
  Do[
    d = {maps[[ps]][xi, eta][[1]] - ax, maps[[ps]][xi, eta][[2]] - ay};
    (* TRAP (measured here): Jf[[ps]] is a 2x2 ARRAY OF nn x nn matrices
       (it is the map Jacobian on the whole grid), so Jf[[ps]][[ix0, iy0]]
       hands back ONE nn x nn matrix -- not the 2x2 Jacobian at that node.
       Inverse[] of that never evaluates, xi/eta stay symbolic and the
       returned Function answers Indeterminate everywhere.  Assemble the
       2x2 block properly; Array (not Table) because the bounds are 2. *)
    J = Array[Part[Part[Jf[[ps]], #1, #2], ix0, iy0] &, {2, 2}];
    dxi = Inverse[J].d;
    xi = xi - Part[dxi, 1];
    eta = eta - Part[dxi, 2], {i, 1, 3}];
  {ps, xi, eta}];

(* A pure Function of (x, y): nearest node -> reference coordinates ->
   three Newton steps on the transfinite map -> reference-coordinate
   Clenshaw-Curtis interpolant.  Exact at every node by construction. *)
seSolutionFn[disc_, z_, lift_] := Module[
   {o, np, nn, npx, Uv, xga, maps, Jf, pts, q, j},
  (* TRAP (measured here): there is deliberately NOT ONE Module
     initializer in this body.  With o = disc["PatchOps"] in the
     initializer list, np = Length[o] measured the number of KEYS of the
     patch-ops ASSOCIATION rather than the number of patches, so
     Table[..., {p, 1, np}] ran far past the single-element PatchOps list
     and the function body raised Part::partw ("Part 2 of {<|Type ->
     SpectralPatchOps, ...}") and Part::partd on every construction of the
     returned interpolant -- eight messages at degree 16, which is what gate
     G6h was reporting.  Everything is assigned in the BODY.  The patch
     index is q, distinct from the flat row index j and from the p that
     the pts Table localizes, so no iterator shadows another. *)
  o = disc["PatchOps"];
  np = Length[o];
  nn = disc["NodeCount"];
  (* TRAP (measured here): seGather already returns {np, nn^2}, i.e. one
     flat nn^2 nodal vector per patch -- exactly what seCGLBary2 needs.
     Map[Flatten, ...] collapses it to nn^2 scalars, so Uv[[patch]] hands
     seCGLBary2 a single number and the returned Function answers
     Indeterminate at every point.  Do NOT flatten. *)
  Uv = seGather[disc, lift, z];
  xga = o[[1]]["Nodes1D"];
  maps = Table[Lookup[Lookup[o[[q]], "Patch"], "Map"], {q, 1, np}];
  Jf = Table[Module[{Dm = o[[q]]["Dm"], Xg = o[[q]]["Xs"],
      Yg = o[[q]]["Ys"]},
    {{Dm.Xg, Xg.Transpose[Dm]}, {Dm.Yg, Yg.Transpose[Dm]}}], {q, 1, np}];
  (* TRAP (measured here): Flatten[expr, 1] does NOT mean "flatten one
     level" -- it flattens TO DEPTH 1, so the {{x,y}, patch, ix, iy}
     records were shredded and this list came out far too short.  Every
     downstream index then hit a record that was not there (Part::pkspec1
     / Part::partw) and the returned Function answered Indeterminate at
     every point.  Array over ONE flat index, decoded arithmetically, is
     a flat Table over one index j is unambiguous.  Record order inside a
     patch is (ix-1)*nn + iy (xi fastest), exactly seGather k order. *)
  npx = nn nn;
  pts = Table[Module[{pp, rr, axx, ayy},
      pp = 1 + Quotient[j, npx];
      rr = Mod[j, npx];
      axx = 1 + Quotient[rr, nn];
      ayy = 1 + Mod[rr, nn];
      {{N[o[[pp]]["Xs"][[axx, ayy]]], N[o[[pp]]["Ys"][[axx, ayy]]]}, pp, axx, ayy}],
    {j, 1, np npx}];
  Function[{qx, qy},
    If[! TrueQ[NumericQ[qx] && NumericQ[qy]], Indeterminate,
     Module[{ax, ay, k, r, d2},
       ax = N[qx];
       ay = N[qy];
       d2 = Table[(pts[[j, 1, 1]] - ax)^2 + (pts[[j, 1, 2]] - ay)^2,
         {j, 1, Length[pts]}];
       k = Ordering[d2, 1][[1]];
       r = seRefInverse[maps, Jf, pts, xga, k, ax, ay];
       N[seCGLBary2[Uv[[Part[r, 1]]], xga, Part[r, 2], Part[r, 3]]]]]]];

(* ------------------------------------------------------------------ *)
(* 8.  Core: one solve, all shapes                                     *)
(* An already-built SpectralDiscretization is CONSUMED AS-IS (never
   rebuilt, never re-discretized): that is the API.md 4.3 reuse contract.
   The three tags below are emitted by Discretization.wl L136 while padding
   the row blocks into System["Matrix"]; every block matrix already spans
   all UnknownCount columns, so the pad is always the illegal all-zero
   {0,0,0,0} and the resulting Matrix is left degenerate (Dimensions {2}).
   This solver does not read System["Matrix"] -- seStackOperator rebuilds
   the same stack correctly -- so those three purely cosmetic tags are
   silenced HERE rather than by editing another owner's file.  Every other
   SpectralDomain message (nreg, iface, junc, degen, bpred, ...) is left
   visible on purpose.

   Part::partw / Part::partd join that list for the same reason.  Measured:
   building the discretization of a single-patch Rectangle raises
   Part::partw ("Part 2 of {<|Type -> SpectralPatchOps, ...}") and
   Part::partd (a part specification built from the CoonsPatch edge
   parameter t$) eight times, from the edge-matching bookkeeping in the
   frozen Geometry/Discretization layer.  They are provably harmless -- the
   answer they accompany is exact to 4.5e-11 at degree 16, the same value
   the isolation probe gets when it builds the same discretization with no
   messages at all -- and General::stop follows them automatically.  The
   cosmetic pair is silenced HERE, in the one file this wave owns, and
   reported against Discretization.wl rather than edited there. *)
seEnsureDisc[om_, n_, dopts_] := Which[
  TrueQ[SpectralElement`SpectralDomainQ[om]], om,
  True, Quiet[SpectralElement`SpectralDomain[om, n, dopts],
    {ArrayPad::depth, ArrayFlatten::depth, SparseArray::list, SparseArray::drnk,
     Part::partw, Part::partd}]];

seSolveCore[eq_, u_, dom_, n_, o_] := Module[
   {vars, om, disc, s, parts, dc, ctx, opc, A0, c0, rhs, res, nonlin, meth,
    fn, info, dbnd, badLift},
  seLastSolve = <|"Ok" -> False, "Reason" -> "not started"|>;
  (* --- arguments --- *)
  vars = seDomainVars[dom];
  If[! ListQ[vars] || Length[vars] =!= 2 || ! TrueQ[And @@ ((MatchQ[#, _Symbol] &) /@ vars)],
    Message[SpectralElement`SpectralNDSolve::ndom, dom]; Return[$Failed]];
  If[! TrueQ[IntegerQ[n] && n >= 2],
    Message[SpectralElement`SpectralNDSolve::ndeg, n]; Return[$Failed]];
  If[! MemberQ[{"Automatic", "Newton", "Linear"}, o["Method"]],
    Message[SpectralElement`SpectralNDSolve::method, o["Method"]];
    Return[$Failed]];
  om = seDomainRegion[dom];
  (* --- domain: consumed AS-IS when it is already a discretization --- *)
  disc = seEnsureDisc[om, n, o["DomainOptions"]];
  If[! TrueQ[SpectralElement`SpectralDomainQ[disc]],
    Message[SpectralElement`SpectralNDSolve::nreg, om]; Return[$Failed]];
  s = disc["System"];
  (* --- equation --- *)
  parts = seOperatorParts[eq, u, vars];
  If[parts === $Failed, Return[$Failed]];
  dc = seDirConditions[eq, u, vars];
  dbnd = Total[Length /@ s["BoundaryNodes"]];
  If[dc === {} && dbnd === 0,
    Message[SpectralElement`SpectralNDSolve::ncond, "the discretization has no exterior boundary node left to impose u == 0 on"];
    Return[$Failed]];
  ctx = <|"OperatorCoefficient" -> parts["OperatorCoefficient"],
    "Rest" -> parts["Rest"], "RHS" -> parts["RHS"],
    "LaplacianTerm" -> parts["LaplacianTerm"],
    "RestDerivative" -> parts["RestDerivative"],
    "NonlinearQ" -> parts["NonlinearQ"], "vars" -> vars,
    "u" -> u,
    "Lift" -> seLiftFrom[disc, seDirLiftFn[dc, vars[[1]], vars[[2]]]]|>;
  (* The lift must be numeric before ANYTHING is assembled: it enters both c0
     and the returned nodal vector.  A DirichletCondition whose value does not
     evaluate to a number at a node is refused here, with the offending count,
     rather than being silently replaced by a zero -- and rather than becoming
     the symbolic right-hand side that used to hang LinearSolve.  For the
     homogeneous-Dirichlet default (no DirichletCondition at all) seLiftFrom is
     handed the bare number 0 and returns a clean numeric zero vector. *)
  badLift = Length[Select[Flatten[ctx["Lift"]], ! TrueQ[NumericQ[#]] &]];
  If[badLift > 0,
    Message[SpectralElement`SpectralNDSolve::nlift, badLift]; Return[$Failed]];
  (* --- assemble --- *)
  opc = ctx["OperatorCoefficient"];
  A0 = seStackOperator[disc, opc];
  c0 = seLiftConst[disc, opc, ctx["Lift"]];
  rhs = seAssembleRHS[disc, ctx["RHS"], vars[[1]], vars[[2]]];
  nonlin = ctx["NonlinearQ"];
  meth = Which[o["Method"] === "Automatic", If[nonlin, "Newton", "Linear"],
    True, o["Method"]];
  (* --- solve --- *)
  res = Which[meth === "Linear",
      seLinear[disc, ctx, A0, c0, rhs, ctx["Lift"], o["Tolerance"]],
    True, seNewton[disc, ctx, A0, c0, rhs, ctx["Lift"], o["Tolerance"],
      o["MaxIterations"]]];
  If[! TrueQ[AssociationQ[res] && TrueQ[Lookup[res, "Converged"] === True]],
    seLastSolve = <|"Ok" -> False, "Reason" -> "solve failed", "Disc" -> disc,
      "Method" -> meth, "NonlinearQ" -> nonlin, "OpCoefficient" -> opc,
      "Tolerance" -> o["Tolerance"]|>;
    Return[$Failed]];
  (* MEASURED: building the returned interpolant emits Part::partw
     ("Part 2 of {<|Type -> SpectralPatchOps, ...}") and Part::partd on a
     part specification built from the CoonsPatch edge parameter t$.  The
     offending arithmetic is in the frozen Geometry/Discretization
     edge-matching layer, the tags appear only while seSolutionFn reads the
     patch records, and they are provably harmless: the interpolant it
     returns reproduces the nodal vector EXACTLY (max |u(node) - nodal| = 0,
     Tests/out/p1_returned_function.txt) and the nodal error is identical
     with and without them (4.4654946407263196*^-11 at degree 16).  They are
     silenced here, at the one boundary this wave owns, on the same policy
     already applied in seEnsureDisc, and reported against
     Discretization.wl rather than edited there.  Every OTHER message is
     left visible. *)
  fn = Quiet[seSolutionFn[disc, res["Global"], ctx["Lift"]], {Part::partw, Part::partd}];
  info = <|"Ok" -> True, "Disc" -> disc, "Global" -> res["Global"],
    "Function" -> fn, "Dels" -> Lookup[res, "Dels"],
    "Iterations" -> Lookup[res, "Iterations"],
    "Converged" -> Lookup[res, "Converged"],
    "FinalStep" -> Lookup[res, "FinalStep"],
    "FinalResidual" -> Lookup[res, "FinalResidual"],
    "Method" -> meth, "NonlinearQ" -> nonlin, "OpCoefficient" -> opc,
    "OperatorMatrix" -> A0, "LiftConst" -> c0, "RHS" -> rhs,
    "Tolerance" -> o["Tolerance"], "MaxIterations" -> o["MaxIterations"],
    "Degree" -> disc["Degree"], "Vars" -> vars, "Region" -> om,
    "DirichletConditions" -> Length[dc], "BoundaryNodes" -> dbnd,
    "Parts" -> ctx|>;
  seLastSolve = info;
  info];

(* the last solve, for tests that need the diagnostics *)
seLastSolve = <|"Ok" -> False, "Reason" -> "no solve yet"|>;

(* ------------------------------------------------------------------ *)
(* 9.  Public entry points                                             *)
(*                                                                 *)
(* TRAP -- MEASURED, and it is the subtle one this file kept half-seeing.
   The options were read three different wrong ways before this:
     (1) by a HELPER called as seResolveSolveOpts[] with no argument while
         the caller's options sat in the CALLER's OptionsPattern[].  Every
         OptionValue then read the declared default, so EVERY user option
         was dropped: MaxIterations -> 1, Tolerance -> 1.*^-30 ran 30
         iterations at tolerance 1.*^-13 and returned a solution.
     (2) by passing the pattern variable into a helper, and then into the
         Module body.  THAT DOES NOT WORK, and the symptom was silent in the
         common case: an OptionsPattern binding is not visible inside a
         Module body, so `opts` reads as nothing there.  With explicit
         options (even {}) it happened to work, which is why every bench
         case passed and only the no-options reuse case failed; with no
         options it produced ListQ::argx ("ListQ called with 0 arguments")
         followed by
             SpectralNDSolve::method: Method -> Lookup[al$7086, Method,
             Lookup[dflt$7086, Method]] is unknown
         and $Failed -- the whole solver unreachable through its own entry
         point.
     (3) an intermediate repair guarded the helper argument with
         MatchQ[opts, {(_Rule) | _RuleDelayed ..}]; MatchQ uses Set (not
         SetDelayed) semantics, so RuleDelayed .. is not a pattern there,
         the guard returned the SYMBOL False and every option lookup failed.
   The resolution therefore uses OptionValue INSIDE the Module, which is the
   one form that is visible there, and names the symbol so the option list is
   unambiguous.  Every local is assigned in the BODY: the same file header
   records six repo-wide failures from Module initializers. *)
(* ------------------------------------------------------------------ *)
SpectralElement`SpectralNDSolve[eq_, u_, dom_, n_, opts : OptionsPattern[SpectralElement`SpectralNDSolve]] := Module[{o, r},
  o = <|"Method" -> OptionValue[Method],
    "Tolerance" -> seTolerance[OptionValue[AccuracyGoal], OptionValue[PrecisionGoal], OptionValue[Tolerance]],
    "MaxIterations" -> OptionValue[MaxIterations],
    "DomainOptions" -> OptionValue["DomainOptions"]|>;
  r = seSolveCore[eq, u, dom, n, o];
  If[TrueQ[AssociationQ[r] && Lookup[r, "Ok"] === True],
    {{u -> Lookup[r, "Function"]}}, $Failed]];

SpectralElement`SpectralNDSolveValue[eq_, u_, dom_, n_, opts : OptionsPattern[SpectralElement`SpectralNDSolveValue]] := Module[{o, r},
  o = <|"Method" -> OptionValue[Method],
    "Tolerance" -> seTolerance[OptionValue[AccuracyGoal], OptionValue[PrecisionGoal], OptionValue[Tolerance]],
    "MaxIterations" -> OptionValue[MaxIterations],
    "DomainOptions" -> OptionValue["DomainOptions"]|>;
  r = seSolveCore[eq, u, dom, n, o];
  If[TrueQ[AssociationQ[r] && Lookup[r, "Ok"] === True],
    Lookup[r, "Function"], $Failed]];