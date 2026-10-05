(* ::Package:: *)

(* =====================================================================
   Kernel/AAA.wl  --  the AAA rational-approximation algorithm
   ---------------------------------------------------------------------
   Y. Nakatsukasa, O. Sete, L. N. Trefethen, "The AAA algorithm for
   rational approximation", SIAM J. Sci. Comput. 40 (2018), A1494-A1522.
   (arXiv:1612.00337.  The task brief mis-attributed this paper to
   Driscoll: Driscoll co-authors the LATER review "The first five years
   of the AAA algorithm", together with Nakatsukasa and Trefethen.)

   LOADING CONTRACT
   This file is Get-ed from INSIGHT of SpectralElement`Private (by
   Kernel/SpectralElement.wl).  Therefore:
     * no BeginPackage / Begin / End here,
     * every name defined below lands in SpectralElement`Private,
     * NO public (SpectralElement`) symbol is defined in this file.
   Every name is prefixed `aaa` so it cannot collide with the private
   names of the Geometry / Discretization / Solve modules.

   ROLE IN THE PACLET
   A user's domain boundary arrives as a SAMPLED CURVE.  The paclet
   splits it into four arcs at the user's corners and hands each arc to
   the AAA solver as a map from the ARC PARAMETER (arclength or chord
   length) to the complex plane.  AAA returns a barycentric rational
   function for each arc; CoonsPatch then evaluates it -- and its
   derivative, for the surface metrics -- at arbitrary (u,v).  Rational
   rather than polynomial, because a smooth arc of a real parametric
   curve carries poles off the axis (usually a conjugate pair near the
   arc), so the error falls off geometrically instead of algebraically.
   See docs/AAA-NOTES.md.

   MACHINE-PRECISION AND WOLFRAM TRAPS this project already paid for
     * every entry point coerces its input with N[., MachinePrecision],
       so exact rationals can never leak into the Cauchy matrix, the SVD
       or the error loop;
     * the max-abs helper guards with VectorQ -- a nested list would
       otherwise come back as the integer -1;
     * the barycentric evaluation ALWAYS divides by Total of the
       denominator weight terms (a missing denominator is a real bug);
     * Ordering[list, 1] is the position of the SMALLEST element and
       Ordering[list, -1] the position of the LARGEST -- both are used,
       neither is assumed;
     * the SingularValueDecomposition convention is PROBED numerically
       in Tests/aaaprobe.wl (gate G-A0), never assumed;
     * the Cauchy matrix keeps 1/0 = ComplexInfinity on its own diagonal,
       exactly as the reference implementation does; poisoning is
       ROW-LOCAL because Total sums along the row, and those rows are
       dropped from the least-squares and filled in from the limit f_j.
   ===================================================================== *)


(* ---------------------------------------------------------------------
   aaamaxabs : guarded max |.|, returns -1 for anything non-vector.
   --------------------------------------------------------------------- *)
aaamaxabs[v_] := If[TrueQ[VectorQ[v, NumericQ]], Max[Abs[v]], -1];

(* ---------------------------------------------------------------------
   aaasub : deterministic uniform subsample of a sample set.  Returns
   ORIGINAL indices, ascending, no repeats, first and last always kept.
   --------------------------------------------------------------------- *)
aaasub[nn_Integer?Positive, nmax_Integer?Positive] := Module[{st, ii},
  If[nn <= nmax, Return[Range[nn]]];
  st = Max[1, Floor[nn/nmax]];
  ii = Range[1, nn, st];
  If[Last[ii] =!= nn, ii = Append[ii, nn]];
  ii
];

(* ---------------------------------------------------------------------
   aaacauchy[zlist_List, nodes_List] : the (rows x m) matrix
   C_ij = 1/(z_i - z_j).  On the diagonal the difference is exactly 0
   and the entry becomes ComplexInfinity, as in the reference code; every
   consumer either excludes those rows or substitutes the limit.
   The leading `1./` is load-bearing: without it this returns the RAW
   DIFFERENCES z_i - z_j, the Loewner matrix is built from the wrong
   numbers, and AAA degenerates into a fit that never converges.
   --------------------------------------------------------------------- *)
aaacauchy[zlist_List, nodes_List] :=
  1./Outer[Subtract, zlist, nodes] /. {0 -> ComplexInfinity, 0. -> ComplexInfinity};

(* ---------------------------------------------------------------------
   aaarows[mat_List, fn_] : apply fn to each ROW of mat (a flat length-m
   list) and Total the result, giving a flat list of Length[mat] scalars.

   Everything is done with flat vectors INSIDE the row and then summed,
   because WL will not reliably contract a nested list against a flat one.
   `c * ws` with c of shape {n, m} and ws of shape {m} stays an
   UNEVALUATED Times whenever n =/= m -- in particular for a single
   evaluation point, where n = 1.  Total of that never evaluates, so
   aaaeval handed back a raw Total[...] instead of a number, aaaaderiv fell
   back to its polynomial path at every non-node point, and every
   derivative gate read ~1 instead of ~1e-14.

   Writing `fn[mat[[i]]]` keeps both operands flat length m, where `*` is
   ordinary elementwise multiplication with no shape to infer.
   --------------------------------------------------------------------- *)
aaarows[mat_List, fn_] :=
  Table[N[Total[fn[mat[[i]]]], MachinePrecision], {i, 1, Length[mat]}];

(* ---------------------------------------------------------------------
   aaahit[zlist_List, nodes_List] : for each evaluation point, the index
   of the support node it coincides with (0 = no coincidence).  Used both
   to guard the 0/0 and to fetch f_j there.  Written as an explicit fold
   rather than with exotic patterns, so the 0 test is unambiguous.
   --------------------------------------------------------------------- *)
aaahit[zlist_List, nodes_List] := Module[{mm = Length[nodes]},
  (* `== 0`, NOT `=== 0`.  SameQ distinguishes an exact integer 0 from a
     machine-real 0.0, and the difference z - z_j is a machine real, so the
     node test never fired and every evaluation AT a support point returned
     the 0/0 limit instead of f_j. *)
  (* {Range[mm], diff} and NOT {{Range[mm]}, {diff}}: the doubly braced
     form has Dimensions {1,1,2,3}, so Transpose swaps two length-1 levels
     and returns the input unchanged.  The fold then walked the two ROWS
     instead of the m PAIRS, no node was ever matched, and evaluation at a
     support point always fell through to the raw 0/0 limit. *)
  Table[Fold[(#1 + If[#2[[2]] == 0, #2[[1]], 0]) &, 0,
     Transpose[{Range[mm], zlist[[i]] - nodes}]], {i, 1, Length[zlist]}]
];

(* ---------------------------------------------------------------------
   aaasvdw[amat_] : barycentric weights from the singular vector of the
   SMALLEST singular value of the Loewner matrix.

   Convention PROBED, never assumed (Tests/aaaprobe.wl gate G-A0):
   SingularValueDecomposition[a] -> {u, s, v} with
       a == u . DiagonalMatrix[s] . ConjugateTranspose[v]
   and the singular values sorted DECREASING, so the smallest is at
   position 1 of ascending Ordering and its right singular vector is
   v[[All, 1]] (the last column).  Here amat is (rows x m) with
   rows > m, so the reduced SVD returns exactly m singular values.
   Weights arrive with unit 2-norm; we renormalise to max |w_j| = 1 --
   the rational function is invariant under a common scale, and this
   keeps the Cauchy products clear of over/underflow.
   --------------------------------------------------------------------- *)
aaasvdw[amat_] := Module[{usv, v, vv, sraw, sd, s, ncols, jm, w},
  (* NOTE 1: every local is assigned by a separate statement in the body.
     Chaining them inside the Module local list -- usv = SVD[...],
     s = usv[[2]], v = usv[[3]] -- is NOT safe: WL does not guarantee that
     a later initialiser sees an earlier one's assigned value, and when it
     does not, `usv` stays an undefined GLOBAL.  The symptom is a silent
     Part::partd followed by a returned literal `usv[[3]][[All,2]]`.

     NOTE 2 (the subtle one): usv[[2]] is NOT a vector.  For a tall matrix
     WL returns the singular values as a full (rows x cols) MATRIX with the
     values on the diagonal and ZEROS everywhere else, e.g. for a 40x2
     matrix {{47.59, 0}, {0, 0}, ..., {0, 3.53}, ...}.  Flattening that
     interleaves the padding zeros, so Ordering picks a ZERO as the
     "smallest singular value": aaasvdw returned the zero vector, ||A.w||
     was meaningless, and AAA never converged.  The values are therefore
     taken from SingularValueList (a proper descending vector) and only the
     diagonal is read out of usv[[2]] as a cross-check. *)
  usv = SingularValueDecomposition[amat];
  v = usv[[3]];
  vv = Dimensions[v];
  sraw = usv[[2]];
  sd = If[TrueQ[MatrixQ[sraw]], Diagonal[sraw], Flatten[sraw]];
  ncols = Min[Dimensions[amat][[2]], vv[[2]]];
  s = Take[SingularValueList[amat], UpTo[ncols]];
  jm = ncols;                              (* descending => smallest is last *)
  w = N[v[[All, jm]], MachinePrecision];
  w = w/Max[Abs[w]];
  {w, s[[jm]]}
(* -> {weights, smallest singular value}.  The value is MEASURED, so a
   silent change of the SVD convention would show up in the test. *)
];

(* ---------------------------------------------------------------------
   aaaprodp[zs_List, j_Integer] : coefficients (ascending powers) of
   prod_{i != j} (z - z_i).  Explicit multiplication -- cheap at AAA
   sizes and it needs no symbolic ground manipulation.
   --------------------------------------------------------------------- *)
aaaprodp[zs_List, j_Integer] := Module[{co = {1}, cc, kk},
  Do[If[kk =!= j,
        cc = ConstantArray[0, Length[co] + 1];
        (* ASCENDING coefficients, as documented: multiplying by z shifts the
           whole vector UP one slot, and the -z_k part stays where it is.
           Putting z*co in the lower slot instead yields the same polynomial
           written DESCENDING, which silently disagreed with aaahorner,
           aaapolyder and aaacomp -- all of which assume ascending.  The
           visible symptom was that every reported "pole" was a root of the
           reversed polynomial. *)
        cc[[2 ;; Length[co] + 1]] += co;                    (* z*co      *)
        cc[[1 ;; Length[co]]] += -zs[[kk]]*co;              (* -z_k*co   *)
        co = cc],
     {kk, 1, Length[zs]}];
  co];

(* Horner evaluation of a polynomial given by ascending coefficients *)
aaahorner[co_List, x_] := Fold[(#1*x + #2) &, 0, Reverse[co]];

(* derivative of a polynomial given by ascending coefficients:
   {a0,a1,a2} -> {a1};  {a0,a1,a2,a3} -> {a1, 2 a2} *)
(* derivative of a polynomial given by ASCENDING coefficients:
     {a0,a1,a2}     -> {a1}
     {a0,a1,a2,a3}  -> {a1, 2 a2}
   The multiplier must have the SAME length as the surviving coefficients.
   Drop[Most[co],1] has Length[co]-2 entries against a Length[co]-1
   multiplier, so WL returned the raw product {a1}*{1,2} UNevaluated, and
   residues plus every node-derivative came back as nested Horner calls. *)
aaapolyder[co_List] := If[Length[co] < 2, {}, Rest[co]*Range[1, Length[co] - 1]];

(* ---------------------------------------------------------------------
   aaanorm[co_List] : trim trailing (highest-degree) zeros, then rescale by
   the largest magnitude.

   Both steps matter for the root finder.  The p/q coefficients come out of
   a product of (z - z_j) factors, so their magnitudes span many orders and
   the leading coefficient can even be exactly 0 when the rational function
   degenerates to a lower type.  Dividing by a zero or denormal leading
   coefficient fills the companion matrix with Infinity, and Eigenvalues on
   such a matrix does not fail cleanly -- it runs essentially forever, which
   is what hung the first pole-extraction test.
   --------------------------------------------------------------------- *)
aaanorm[co_List] := Module[{c = co, mx},
  While[TrueQ[Length[c] > 1 && c[[-1]] === 0], c = Most[c]];
  If[!TrueQ[VectorQ[c, NumericQ]], Return[{1.}]];
  mx = Max[Abs[c]];
  If[!TrueQ[mx > 0], Return[{1.}]];
  N[c/mx, MachinePrecision]
];

(* ---------------------------------------------------------------------
   aaaroots[co_List] : numeric roots of a polynomial given by ascending
   coefficients.  NSolve is tried first (robust on badly scaled but
   NON-SINGULAR polynomials); the companion-matrix eigenvalue route is the
   fallback.  Both see coefficients already normalised by aaanorm.
   --------------------------------------------------------------------- *)
aaaroots[co_List] := Module[{c, d, ev},
  (* Companion-matrix eigenvalues only.  An NSolve route was tried first and
     removed: extracting N roots from N solve-rules with N distinct
     Unique symbols needs a Slot-numbered substitution, and the easy version
     silently substituted the rule list itself, returning {}.  On the small
     degrees AAA actually produces (m-1, with m typically < 30) the companion
     route is both fast and reliable once aaanorm has trimmed and rescaled
     the coefficients -- without that normalisation a zero or denormal
     leading coefficient fills the matrix with Infinity and Eigenvalues does
     not fail cleanly, it simply runs for ever. *)
  c = aaanorm[co];
  d = Length[c] - 1;
  If[d < 1, Return[{}]];
  ev = Quiet[Check[N[Eigenvalues[aaacomp[c]], MachinePrecision], {}]];
  Cases[ev, _?NumericQ]
];

(* ---------------------------------------------------------------------
   aaacomp[co_List] : companion matrix of the polynomial whose ascending
   coefficients are co (degree = Length[co]-1).  Its eigenvalues are the
   polynomial's roots.  Callers must pass aaanorm-normalised coefficients.
   --------------------------------------------------------------------- *)
aaacomp[co_List] := Module[{n = Length[co] - 1, cn = co[[-1]], cm},
  (* Frobenius companion matrix for ASCENDING coefficients co = {a_0..a_n}:
         subdiagonal 1s, last column -a_{n-i}/a_n.
     The previous orientation (coefficients in the first column, ones on the
     SUPERdiagonal) also has 1s overwritten by the coefficient column, and
     its characteristic polynomial is the REVERSED polynomial -- so the
     reported "poles" were roots of the wrong equation entirely. *)
  If[n < 1, Return[{{}}]];
  cm = ConstantArray[0, {n, n}];
  (* last column is -a_0/a_n, -a_1/a_n, ... in that order, i.e. simply
     -co[[i]]/cn: indexing with n-i+1 there yields the REVERSED polynomial
     a_n z^n + ... which is a different equation whose roots are wrong. *)
  Do[cm[[i, n]] = -co[[i]]/cn, {i, 1, n}];
  Do[cm[[i + 1, i]] = 1, {i, 1, n - 1}];
  cm
];

(* ---------------------------------------------------------------------
   aaapolyform[nodes_List, vals_List, ws_List] : the p/q polynomial view.
   With l(z) = prod_j (z - z_j),
       q(z) = l(z) d(z) = sum_j w_j prod_{i != j} (z - z_i)   (its roots are the poles)
       p(z) = l(z) n(z) = sum_j w_j f_j prod_{i != j} (z - z_i) (its roots are the zeros)
   both of degree <= m-1, and r = p/q.  (Paper eq. (1), (4).)
   --------------------------------------------------------------------- *)
aaapolyform[nodes_List, vals_List, ws_List] := Module[{mm = Length[nodes], pn, pd, co, jj},
  pn = ConstantArray[0, mm];
  pd = ConstantArray[0, mm];
  Do[co = aaaprodp[nodes, jj];
     pn = pn + ws[[jj]]*vals[[jj]]*co;
     pd = pd + ws[[jj]]*co,
   {jj, 1, mm}];
  {pn, pd}
];
(* -> {numerator coefficients, denominator coefficients}, ascending *)

(* ---------------------------------------------------------------------
   aaapoles[fit_] : <|"Poles", "Residues", "Zeros"|>.
   Poles are the roots of q; the residue at a simple pole p is the exact
   p(p)/q'(p) (no finite differencing, unlike the paper's 4-point
   estimate).  Zeros are the roots of p.
   --------------------------------------------------------------------- *)
(* ---------------------------------------------------------------------
   aaapsq[nodes_List, vals_List, ws_List] : the p/q polynomial view with ONE
   shared scale applied to both.

   The scale must be shared.  p/q is invariant under scaling p and q by the
   SAME constant, but not under scaling them differently -- that rescales the
   rational function.  Poles survive (they are zeros of q, which a scalar
   cannot move) while residues are multiplied by the wrong factor and the
   p/q derivative (p'q - p q')/q^2 picks up the ratio.  Dividing p and q by
   their own maxima independently made the node-derivative ~0.2 instead of
   ~1e-15.
   --------------------------------------------------------------------- *)
aaapsq[nodes_List, vals_List, ws_List] := Module[{pf = aaapolyform[nodes, vals, ws], sc},
  sc = Max[Flatten[Abs[{pf[[1]], pf[[2]]}]]];
  If[!TrueQ[sc > 0], sc = 1.];
  {N[pf[[1]]/sc, MachinePrecision], N[pf[[2]]/sc, MachinePrecision]}
];

aaapoles[fit_Association] := Module[{nodes, vals, ws, pn, pd, dq, pol, res, zer, good},
  If[!TrueQ[AssociationQ[fit]] || !TrueQ[KeyExistsQ[fit, "Nodes"]],
    Return[<|"Poles" -> {}, "Residues" -> {}, "Zeros" -> {}|>]];
  nodes = fit["Nodes"];
  vals = fit["Values"];
  ws = fit["Weights"];
  {pn, pd} = aaapsq[nodes, vals, ws];      (* ONE shared scale -- see aaapsq *)
  dq = aaapolyder[pd];
  good = Function[p, TrueQ[NumericQ[Re[p]]] && TrueQ[NumericQ[Im[p]]] && TrueQ[Abs[p] < 10^12]];
  pol = Select[aaaroots[pd], good];
  res = (N[aaahorner[pn, #], MachinePrecision]/N[aaahorner[dq, #], MachinePrecision]) & /@ pol;
  zer = Select[aaaroots[pn], good];
  <|"Poles" -> pol, "Residues" -> res, "Zeros" -> zer|>
];

(* ---------------------------------------------------------------------
   aaabary[nodes, vals, ws, zlist] : shared barycentric core for aaaeval
   and aaaderiv.  With c_j = w_j/(z-z_j),
       n(z) = sum_j c_j f_j      n'(z) = -sum_j c_j f_j /(z-z_j)
       d(z) = sum_j c_j          d'(z) = -sum_j c_j /(z-z_j)
   (the minus sign is d/dz of 1/(z-z_j) = -1/(z-z_j)^2).
   hit_i = node index equal to z_i, or 0.
   --------------------------------------------------------------------- *)
aaabary[nodes_List, vals_List, ws_List, zlist_List] := Module[{c},
  (* same Module-initializer rule as aaasvdw: assign in the body, never
     chain inside the local list *)
  c = aaacauchy[zlist, nodes];
  {aaarows[c, (#*ws*vals) &],         (* n(z)  =  Sum w_j f_j /(z-z_j)    *)
   aaarows[c, (#*ws) &],              (* d(z)  =  Sum w_j    /(z-z_j)    *)
   -aaarows[c, ((#*ws)*#) &],         (* d'(z) = -Sum w_j    /(z-z_j)^2 *)
   -aaarows[c, (((#*ws)*vals)*#) &],  (* n'(z) = -Sum w_j f_j/(z-z_j)^2 *)
   aaahit[zlist, nodes]}              (* node index hit here, 0 if none *)
];

(* ---------------------------------------------------------------------
   aaazfit[zs_List, fs_List, tol_, mmax_] : AAA fit.  <-- MAIN ENTRY
   ---------------------------------------------------------------------
   Greedy barycentric rational approximation of the data fs sampled at
   zs.  At step m:
     * add the support point where |f - r| is currently largest;
     * build the Loewner matrix  S_ij = (f_i - f_j)/(z_i - z_j)  over the
       CURRENT support points against all sample points;
     * take the right singular vector belonging to the SMALLEST singular
       value of S as the barycentric weights -- this is what makes the
       interpolant the (near-)minimax approximant;
     * re-evaluate at every sample point and record the max error;
     * stop when the error reaches tol * max|f|, or at mmax.
   Step 1 references the constant interpolant mean(f), exactly as the
   reference implementation does, so the first support point is the
   sample furthest from the mean.

   Optional 5th argument nmax caps the number of sample points used
   (deterministic stride subsample, first and last kept).  The cap is
   2000, which no test gate reaches; "Subsampled" records whether it
   fired.  The association's keys are the contract for the integration
   agent -- see docs/AAA-NOTES.md and the final report.
   --------------------------------------------------------------------- *)
aaazfit[zs_List, fs_List, tol_: 1.0*^-13, mmax_: 100, nmax_: 2000] := Module[{zz, ff, nn, keep, ord, sv, dup, nsamp, nodes = {}, vals = {}, ws, hist = {}, rhist = {}, scale, sigma, amat, crow, fsup, jj, mm, mstop, it, err, rel, convQ = False, fref, ip, pf, polinfo, badMsg},
  (* --- machine precision from here on: no exact input reaches the SVD --- *)
  zz = N[zs, MachinePrecision];
  ff = N[fs, MachinePrecision];
  nn = Length[zz];
  If[!TrueQ[VectorQ[zz, NumericQ]] || !TrueQ[VectorQ[ff, NumericQ]],
    Return[<|"Status" -> "InputError", "Message" -> "zs and fs must be numeric lists"|>]];
  If[nn != Length[ff] || nn < 4,
    Return[<|"Status" -> "InputError", "Message" -> "zs and fs must have equal length >= 4"|>]];
  If[!TrueQ[NumericQ[tol]] || !TrueQ[NumericQ[mmax]],
    Return[<|"Status" -> "InputError", "Message" -> "tol and mmax must be numeric"|>]];
  scale = aaamaxabs[ff];
  If[!TrueQ[scale > 0],
    Return[<|"Status" -> "InputError", "Message" -> "all sample values are zero"|>]];

  (* --- subsample, then drop duplicate sample points: a duplicate of a
         support point would put a ComplexInfinity row inside the SVD --- *)
  keep = aaasub[nn, Max[1, Min[Floor[nmax], nn]]];
  zz = zz[[keep]];
  ff = ff[[keep]];
  ord = Ordering[zz];
  sv = zz[[ord]];
  dup = ord[[Flatten[Position[sv[[2 ;; Length[sv]]] - sv[[1 ;; Length[sv] - 1]], 0]] + 1]];
  zz = Drop[zz, dup];
  ff = Drop[ff, dup];
  nsamp = Length[zz];
  If[!TrueQ[nsamp >= 4],
    Return[<|"Status" -> "InputError", "Message" -> "fewer than 4 distinct sample points"|>]];
  scale = aaamaxabs[ff];

  ip = Range[nsamp];
  fref = ConstantArray[Mean[ff], nsamp];        (* step-1 reference: mean(f) *)
  mstop = Max[1, Min[Floor[mmax], nsamp - 1]];
  (* the iteration tag must be a real Symbol: Do[..., {_, 1, n}] raises
     Do::ittag ("Cannot use _ as an iterator since it contains no
     assignment tag") and the loop body never runs, which silently
     produced a zero-support "Failure" fit instead of an error. *)
  Do[
    (* ---- greedy: largest nonlinear residual ---- *)
    jj = ip[[Ordering[Abs[ff[[ip]] - fref[[ip]]], -1][[1]]]];
    nodes = Append[nodes, zz[[jj]]];
    vals = Append[vals, ff[[jj]]];
    ip = DeleteCases[ip, jj];
    If[ip === {},
      Do[If[TrueQ[!MemberQ[nodes, zz[[k]]]], ip = Append[ip, k]], {k, 1, nsamp}];
    ];
    mm = Length[nodes];
    fsup = N[vals, MachinePrecision];

    (* ---- Loewner matrix  A = S_F C - C S_f  (all samples, m columns) --- *)
    crow = aaacauchy[zz, nodes];
    (* Loewner matrix, straight from its definition
           S_ij = (f_i - f_j) / (z_i - z_j)
       rather than as S_F C - C S_f.  Forming it by the difference of
       products relies on WL broadcasting a (nsamp x m) matrix against a
       (nsamp x 1) column, and that broadcasting does NOT do the obvious
       thing: it left the matrix RANK 1 for every m >= 2, so "the smallest
       singular value" was a zero-padding entry and AAA crept along at
       ~0.4% per iteration instead of converging.  The explicit form has
       no broadcasting to get wrong and costs the same O(nsamp*m). *)
    amat = N[Table[(ff[[i]] - fsup[[j]])/(zz[[i]] - nodes[[j]]),
       {i, 1, nsamp}, {j, 1, Length[nodes]}], MachinePrecision];

    (* ---- smallest singular vector = barycentric weights ---- *)
    {ws, sigma} = aaasvdw[amat[[ip]]];

    (* ---- re-evaluate everywhere and record the error ---- *)
    fref = ff;
    (* explicit row sums, not Dot: see aaarows for what went wrong *)
    fref[[ip]] = aaarows[crow[[ip]], (#*ws*fsup) &]/aaarows[crow[[ip]], (#*ws) &];
    err = aaamaxabs[ff - fref];
    (* aaamaxabs returns -1 when the residual vector is not numeric.  That
       sentinel must NEVER be able to satisfy `rel <= tol`, or a broken
       evaluation would be reported as a converged fit. *)
    If[!TrueQ[err >= 0],
      badMsg = "non-numeric residual at iteration " <> ToString[it];
      Return[<|"Status" -> "Failure", "Message" -> badMsg|>]];
    rel = err/scale;
    hist = Append[hist, err];
    rhist = Append[rhist, rel];
    If[rel <= tol, convQ = True; Break[]],
  {it, 1, mstop}];
  mm = Length[nodes];
  If[!TrueQ[mm >= 1],
    Return[<|"Status" -> "Failure", "Message" -> "AAA produced no support points"|>]];

  pf = aaapolyform[nodes, vals, ws];
  polinfo = aaapoles[<|"Nodes" -> nodes, "Values" -> vals, "Weights" -> ws|>];
  <|
    "Status" -> If[TrueQ[convQ], "Converged", "MaxIterationsReached"],
    "Nodes" -> nodes,                        (* support points z_j, machine precision *)
    "Values" -> vals,                         (* f_j = f(z_j) at the nodes *)
    "Weights" -> ws,                          (* barycentric weights, max |w_j| = 1 *)
    "Error" -> Last[hist],                    (* ABSOLUTE max error over the sample set *)
    "RelError" -> Last[rhist],                (* Error / max|f| *)
    "History" -> hist,                        (* ABSOLUTE max error, one per iteration *)
    "RelHistory" -> rhist,                    (* relative error, one per iteration *)
    "Tol" -> tol, "MMax" -> mmax, "Converged" -> convQ,
    "Iterations" -> mm, "Type" -> {mm - 1, mm - 1},
    "Scale" -> scale,                         (* max |f| over the samples used *)
    "Samples" -> zz, "SampleValues" -> ff,    (* the (subsampled) sample set actually used *)
    "Subsampled" -> (nsamp < Length[keep]), "SampleCount" -> nsamp,
    "WeightScale" -> "max |w_j| = 1",
    "PolyNum" -> pf[[1]], "PolyDen" -> pf[[2]],
    "Poles" -> polinfo[["Poles"]], "Residues" -> polinfo[["Residues"]],
    "Zeros" -> polinfo[["Zeros"]]
  |>
];

(* ---------------------------------------------------------------------
   aaaeval[fit_, z_] : evaluate the rational function at a scalar or a
   flat list of scalars, returning the same shape.  The denominator
   Total is always present, and at a support node the value comes from
   the interpolatory limit r(z_j) = f_j instead of the 0/0 NaN.
   --------------------------------------------------------------------- *)
aaaeval[fit_Association, z_] := Module[{nodes = fit["Nodes"], vals = fit["Values"], ws = fit["Weights"], zl, scalarQ, b, ok, out, kk, hj},
  scalarQ = !TrueQ[VectorQ[z, NumericQ]];
  zl = N[If[scalarQ, {z}, z], MachinePrecision];
  If[!TrueQ[VectorQ[zl, NumericQ]], Return[$Failed]];
  b = aaabary[nodes, vals, ws, zl];
  (* NumericQ alone is not enough -- NumericQ[ComplexInfinity] is TRUE, so the
     pole points were classified as usable and the raw 0/0 limit leaked out as
     Indeterminate.  But FiniteQ is not reliable here either: measured in this
     kernel it returns FALSE for a perfectly finite complex value, which sent
     EVERY point down the node branch and made aaaderiv return 0 throughout.
     Spell the test out. *)
  (* is d(z) usable at this point? *)
  ok = Map[TrueQ[NumericQ[#] && Abs[#] < Infinity] &, b[[2]]];        (* is d(z) usable here? *)
  out = b[[1]]/b[[2]];
  Do[hj = b[[5]][[kk]];
     If[TrueQ[!ok[[kk]] && hj >= 1], out[[kk]] = vals[[hj]]],
   {kk, 1, Length[zl]}];
  If[scalarQ, First[out], out]
];

(* ---------------------------------------------------------------------
   aaaderiv[fit_, z_] : first derivative, analytic quotient rule of the
   barycentric form.  CoonsPatch needs this for the surface metrics, so
   it is a hard requirement rather than a convenience.
       r = n/d,   r' = (n' d - n d')/d^2 = (n' - r d')/d
   At a support node the barycentric form is singular term by term while
   the rational function itself is perfectly regular, so those points are
   evaluated through the p/q view instead:  r' = (p' q - p q')/q^2.
   --------------------------------------------------------------------- *)
aaaderiv[fit_Association, z_] := Module[{nodes = fit["Nodes"], vals = fit["Values"], ws = fit["Weights"], zl, scalarQ, b, r, rp, ok, out, kk, hj, oj, sj, sfj},
  scalarQ = !TrueQ[VectorQ[z, NumericQ]];
  zl = N[If[scalarQ, {z}, z], MachinePrecision];
  If[!TrueQ[VectorQ[zl, NumericQ]], Return[$Failed]];
  b = aaabary[nodes, vals, ws, zl];
  ok = Map[TrueQ[NumericQ[#] && Abs[#] < Infinity] &, b[[2]]];        (* see aaaeval: FiniteQ, not NumericQ *)
  r = b[[1]]/b[[2]];
  (* quotient rule r' = (n' - r*d')/d.  aaabary orders its outputs
     {n, d, d', n'}, so the derivative terms are b[[4]] then b[[3]] --
     the reverse of the first two.  With them the wrong way round the
     formula still returns a number, just the wrong one (~2.2 instead of
     ~1e-14), so the gates failed without any message. *)
  rp = (b[[4]] - r*b[[3]])/b[[2]];
  If[!TrueQ[And @@ ok],
    (* Node limit of r'.  Writing r = p/q with p = l*n_bary, q = l*d_bary and
       l = (z-z_j)*L, the (z-z_j) terms cancel exactly and leave
         r'(z_j) = ( sum_{i!=j} w_i f_i/(z_j-z_i)
                   - f_j sum_{i!=j} w_i/(z_j-z_i) ) / w_j .
       The explicit polynomial route (p'q - p q')/q^2 was tried first and
       reached only ~1e-5 on a 17-node fit: degree-16 monomial coefficients
       whose magnitudes span many orders cannot carry the cancellation that
       r'(z_j) depends on.  This form is a plain sum and is exact to rounding. *)
    Do[If[TrueQ[!ok[[kk]]],
        hj = b[[5]][[kk]];
        If[TrueQ[hj >= 1 && ws[[hj]] =!= 0],
          oj = DeleteCases[Range[Length[nodes]], hj];
          sj = Total[ws[[oj]]/(zl[[kk]] - nodes[[oj]])];
          sfj = Total[ws[[oj]]*vals[[oj]]/(zl[[kk]] - nodes[[oj]])];
          rp[[kk]] = N[(sfj - vals[[hj]]*sj)/ws[[hj]], MachinePrecision],
          rp[[kk]] = 0.]],
      {kk, 1, Length[zl]}]];
  out = rp;
  If[scalarQ, First[out], out]
];

(* ---------------------------------------------------------------------
   aaainfo[fit_] : one-line human summary of a fit.
   --------------------------------------------------------------------- *)
aaainfo[fit_Association] := "AAA " <> fit["Status"] <> "  type (" <>
  ToString[fit["Type"][[1]]] <> "," <> ToString[fit["Type"][[2]]] <> ")  relerr " <>
  ToString[fit["RelError"], InputForm] <> "  poles " <> ToString[Length[fit["Poles"]]];

(* =====================================================================
   end of Kernel/AAA.wl
   ===================================================================== *)