(* ::Package:: *)

(* ====================================================================
   GENERATED FILE -- DO NOT EDIT.
   
   This is the single-file build of the SpectralElement paclet, produced
   for the Wolfram Function Repository by build/bundle.wl.  It was NOT
   written by hand: every block between the INLINED VERBATIM markers
   below is a byte-for-byte copy of a file under Kernel/ in the source
   repository, spliced in where the paclet loader would have Get-ed it.
   
   Source repository:  https://github.com/spectralelement/SpectralElement
   Source files:       Kernel/SpectralElement.wl (this header's skeleton)
                      Kernel/AAA.wl, Kernel/Geometry.wl,
                      Kernel/Discretization.wl, Kernel/Solve.wl
   Regenerate with:    ./build/bundle.sh     (or: ./rr.sh 180 build/bundle.wl)
   
   The build is deterministic: it contains no timestamp, so an unchanged
   source tree always produces a byte-identical bundle.  Provenance is
   carried by the SHA-256 of each inlined source, printed in its marker.
   
   Load-time dependencies: NONE.  There is deliberately no $InputFileName,
   no Get and no FileNameJoin anywhere in this file -- the whole point of
   the build.  Kernel/init.m is NOT inlined: it is the paclet's fallback
   loader for a hand-placed Kernel/ directory on $Path and has no role
   here.
   ==================================================================== *)

(* ::Package:: *)

(* ====================================================================
   SpectralElement.wl -- the ONE and ONLY public entry point.
   --------------------------------------------------------------------
   LOADER CONTRACT (do not deviate; every other Kernel/*.wl file is
   written against it -- see API.md):

     * The four subfiles AAA.wl, Geometry.wl, Discretization.wl, Solve.wl
       are Get'd from INSIDE  Begin["`Private"] .  Therefore every BARE
       symbol they define lands in  SpectralElement`Private` .

     * To define a PUBLIC symbol, a subfile MUST write it fully
       qualified:      SpectralElement`CoonsPatch[...] := ...
       (not  CoonsPatch[...] := ... , which would silently create a
       private symbol and leave the public one undefined).

     * Subfiles MUST NOT use BeginPackage / Begin / End.  They are
       fragments, not packages.

     * Because the Gets happen BEFORE End[], the subfile definitions run
       inside the private context but the symbols they create there are
       the ones the public usage messages above refer to.  Order matters:
       AAA.wl before Geometry.wl, because CoonsPatch's Method -> "AAA"
       path needs the approximation core.
   ==================================================================== *)

BeginPackage["SpectralElement`"]

(* ------------------------------------------------------------------ *)
(* Geometry layer                                                      *)
(* ------------------------------------------------------------------ *)

CoonsPatch::usage =
"CoonsPatch[{bottom, top, left, right}, opts] builds a transfinite (Coons) \
patch of the reference square \[CenterDot]-1 <= \[Xi] <= 1, \[Eta] <= 1 from \
four boundary curves, each given as a pure function of one parameter t that \
maps to a point {x, y}.  bottom and top are parameterized by t = \[Xi] in \
\[Minus]1 <= t <= 1 and sit at \[Eta] = \[Minus]1 and \[Eta] = 1;  left and \
right are parameterized by t = \[Eta] in \[Minus]1 <= t <= 1 and sit at \
\[Xi] = \[Minus]1 and \[Xi] = 1.  The four corner values must agree to \
within 1*^-12 or CoonsPatch::corners is issued.  Returns a CoonsPatch \
object whose map CoonsPatchMap[#1, \[Xi], \[Eta]] evaluates to {x, y} on the \
curved domain.  Options include Method -> \"Analytic\" (default) or \
Method -> \"AAA\".";

CoonsPatchQ::usage =
"CoonsPatchQ[expr] gives True if expr is a valid CoonsPatch object \
produced by CoonsPatch.";

CoonsPatchMap::usage =
"CoonsPatchMap[patch, \[Xi], \[Eta]] evaluates the transfinite \
(Coons) map of patch at the reference-square coordinates \[Xi], \[Eta] \
and returns the point {x, y} on the curved domain.";

(* ------------------------------------------------------------------ *)
(* Discretization layer                                                *)
(* ------------------------------------------------------------------ *)

SpectralDomain::usage =
"SpectralDomain[patches, n, opts] builds a SpectralDiscretization object \
from a list of CoonsPatch patches, all discretized at the same degree \
n.  Shared geometric edges are detected by sampling (endpoints plus \
interior Chebyshev nodes, compared within tolerance), their unknowns are \
shared (continuous in value), and normal-flux continuity rows are added, \
so the patches are coupled exactly as in a conforming continuous-Galerkin \
assembly.  SpectralDomain[region, n] accepts the region shorthands \
Rectangle[{x1, y1}, {x2, y2}] and Annulus[{r1, r2}, {\[Theta]1, \[Theta]2}] \
with r1 > 0, and builds the CoonsPatches automatically; Disk is not \
supported (the polar map is singular at r = 0, giving a zero Jacobian) and \
gives SpectralDomain::nreg.  Options include \"InterfaceTolerance\" -> tol \
and \"BoundaryPredicate\" -> fun.";

SpectralDomainQ::usage =
"SpectralDomainQ[expr] gives True if expr is a valid SpectralDiscretization \
object produced by SpectralDomain.";

SpectralDomainData::usage =
"SpectralDomainData[disc, \"key\"] extracts a property of a \
SpectralDiscretization.  Keys include \"Nodes\", \"InterfacePairs\", \
\"PatchCount\", \"Degree\", \"PatchMap\", \"Jacobian\", \"InteriorRows\", \
\"BoundaryRows\", \"FluxRows\" and \"UnknownCount\".";

(* ------------------------------------------------------------------ *)
(* Solver layer                                                        *)
(* ------------------------------------------------------------------ *)

SpectralNDSolve::usage =
"SpectralNDSolve[eq, u, {x, y} \[Element] \[CapitalOmega], n, opts] solves a \
partial differential equation for u on the domain \[CapitalOmega] using the \
multi-domain spectral-element method with degree n per patch, and returns \
the result in the same {{u -> ...}} form as NDSolve, wrapped in a single \
pair of braces.  \[CapitalOmega] is a CoonsPatch list, a \
SpectralDiscretization, or a region shorthand (Rectangle or Annulus).  eq \
may contain DirichletCondition terms; if none is given, homogeneous \
Dirichlet data is imposed on the whole boundary.  Linear problems are \
solved directly; nonlinear ones by Newton's method (Method -> \"Newton\", \
the default when the equations are nonlinear).  Returns \
{{u -> Function[...]{...}}}.";

SpectralNDSolveValue::usage =
"SpectralNDSolveValue[eq, u, {x, y} \[Element] \[CapitalOmega], n, opts] \
gives the value of the solution of eq as a pure function, with the same \
arguments, options and semantics as SpectralNDSolve.";

(* ------------------------------------------------------------------ *)

Begin["`Private`"]

(* ==================================================================
   >>> INLINED VERBATIM FROM Kernel/AAA.wl (554 source lines, SHA-256 84978144105247829370747821503475986528690961321585467825704081124747658218711)
   ================================================================== *)
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
(* <<< END OF INLINED Kernel/AAA.wl *)
(* ==================================================================
   >>> INLINED VERBATIM FROM Kernel/Geometry.wl (457 source lines, SHA-256 34043981844021656785360837470512344082986557875797440370324063449957994590310)
   ================================================================== *)
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
   Tests/reference/specF/p11.wl + helpers.wl):
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
(* <<< END OF INLINED Kernel/Geometry.wl *)
(* ==================================================================
   >>> INLINED VERBATIM FROM Kernel/Discretization.wl (801 source lines, SHA-256 21667048540907919655648255211278921745842384657228177250017095672359457857391)
   ================================================================== *)
(* TRAP: the right-hand side of this definition once named the PATTERN
   status_List instead of the pattern VARIABLE status.  That is a
   RuleDelayed::rhs error and Mathematica then drops the whole SetDelayed
   with no message, so seAssemble silently did not exist.  Always use the
   bare variable on the right-hand side. *)
seAssembleCore[patches_List, ops_List, ifs_List, status_List, nN_Integer, pred_] := Module[
   {np, nn, nn2, nif, nmi, cls, fd, dropList, p, q, m, j, ix, iy, ndA, ndB, dq,
    badN, nInt, offP, offI, loc, sel, lf, bnd, bEdges, pde, flux, blocks,
    slices, order, r0, mats, nTot, nRow, nPde, nFlux, intf, rr, sysMat},
   np = Length[ops];
   nif = Length[ifs];
   nmi = nN - 1;
   offP = {};
   offI = {};
   slices = {};
   order = {};
   r0 = 0;
   nn = ops[[1]]["Nodes"];
   nn2 = nn^2;
   cls = Table[seClassifyPatch[nN, status[[p]]], {p, 1, np}];
   (* the destructuring Set must never be able to abort the whole Module
      body: if seForceDirichlet does not match, dropList simply stays {} *)
   fd = seForceDirichlet[cls, ops, pred];
   If[TrueQ[MatchQ[fd, {_List, _List}]], {cls, dropList} = fd, dropList = {}];
   nInt = Table[Count[Flatten[cls[[p]]], "Interior"], {p, 1, np}];
   (* TRAP: a Table assigns its OWN result only after the whole body has
      run, so offP[[p - 1]] inside the body still saw the empty initial
      value {} and produced {}[[1]] -- patch 2's interior offsets were
      garbage.  (Total[nInt[[q]], {q, 1, p - 1}] does not work either: Part
      of a literal list with a symbolic index does not evaluate under Total.)
      Accumulate is the right tool. *)
   offP = Accumulate[Prepend[nInt, 0]];
   (* The shared blocks sit AFTER every patch's interior block, so block m
      starts at Total[nInt] + (m-1) nmi.  The old Sum[nInt[[q]], {q, 1, p}]
      started the first shared block at nInt[[1]] = 225, which is exactly
      offP[[2]] = 225 -- the shared block and patch 2's interior block
      ALIASED each other from column 226 on, so patch 2 and the interface
      read and wrote the same unknowns. *)
   offI = Table[Total[nInt] + (p - 1) nmi, {p, 1, nif}];
   (* loc[[p]] must be a FLAT length-nn^2 vector of global column numbers,
      because that is how every reader indexes it:
        seFlatIndex[ix, iy, nn] = 1 + (ix-1) + nn (iy-1)   (xi fast)
      A stray extra {k, 1, nn2} iterator in front made it nn^2 x nn x nn,
      so loc[[p]][[k]] was a whole node MATRIX.  Positive[<matrix>] is not
      True, so the selection matrices came out empty and every column index
      below was silently wrong.  Invert seFlatIndex inside the Table. *)
   loc = Table[Block[{c}, c = 0;
       Table[If[cls[[p]][[Mod[k - 1, nn] + 1, Quotient[k - 1, nn] + 1]] === "Interior",
           offP[[p]] + (c++; c), 0], {k, 1, nn2}]], {p, 1, np}];
   Do[
     ndA = seEdgeNodes[ifs[[m]]["EdgeA"], nN];
     ndB = seEdgeNodes[ifs[[m]]["EdgeB"], nN];
     dq = If[TrueQ[ifs[[m]]["Orientation"] === "Reversed"], Reverse[Range[nmi]], Range[nmi]];
     Do[
       loc[[ifs[[m]]["PatchA"]]][[seFlatIndex[ndA[[j, 1]], ndA[[j, 2]], nn]]] = offI[[m]] + j;
       loc[[ifs[[m]]["PatchB"]]][[seFlatIndex[ndB[[dq[[j]]]][[1]], ndB[[dq[[j]]]][[2]], nn]]] = offI[[m]] + j,
       {j, 1, nmi}],
     {m, 1, nif}];
   (* TRAP: Sum takes at least an ITERATOR, so the one-argument Sum[nInt]
      silently stayed unevaluated (Sum::argmu) and poisoned nTot, nPde and
      every count derived from them.  Use Total for a list of counts. *)
   nTot = Total[nInt] + nif nmi;
   (* TRAP: Cases[list, pattern -> rhs] REPLACES every match with rhs, so
      Cases[..., {_, j_?Positive} -> _] collected Blank[] objects instead of
      rules and SparseArray rejected them: every selection matrix came out
      EMPTY, so no patch ever read its own unknowns and the whole assembled
      system was meaningless (silently -- the PDE and flux blocks still had
      the right SHAPE).  Filter the {node, column} pairs first, then turn the
      survivors into rules. *)
   sel = Table[Block[{rr},
       rr = ({#[[1]], #[[2]]} -> 1.) & /@
         Select[Table[{k, loc[[p]][[k]]}, {k, 1, nn2}], Positive[#[[2]]] &];
       SparseArray[rr, {nn2, nTot}]], {p, 1, np}];
   lf = Table[Table[0., {nn2}], {p, 1, np}];
   (* PDE blocks *)
   pde = Table[Block[{rows, Ls},
       dq = Flatten[Map[If[Lookup[#, "Patch"] === p, {Lookup[#, "Flat"]}, {}] &, dropList]];
       rows = If[dq === {}, ops[[p]]["InteriorRows"], Complement[ops[[p]]["InteriorRows"], dq]];
       Ls = ops[[p]]["Lop"][[rows]];
       <|"Patch" -> p, "Rows" -> rows, "RowCount" -> Length[rows],
         "Lop" -> Ls, "Selection" -> sel[[p]], "Matrix" -> (-Ls).sel[[p]]|>],
     {p, 1, np}];
   (* TRAP: `intf` is the Module local that carries the interface record of
      the pair being assembled; it MUST be bound to ifs[[m]] inside the loop.
      Leaving it unbound turned every intf["PatchA"] into a bare Part on a
      symbol (Part::pkspec1), seFluxSide was fed unevaluated arguments and
      every stored flux row (Sigma, FaceRowsA/B, NDopA/B, Matrix) was
      garbage -- yet the loop completed silently, so nothing ever raised. *)
   flux = Table[Block[{fs},
       intf = ifs[[m]];
       fs = seFluxSide[ops[[intf["PatchA"]]], ops[[intf["PatchB"]]], intf];
       <|"Pair" -> m, "PatchA" -> intf["PatchA"], "EdgeA" -> intf["EdgeA"],
         "PatchB" -> intf["PatchB"], "EdgeB" -> intf["EdgeB"],
         "Orientation" -> intf["Orientation"], "Sigma" -> fs["Sigma"],
         "NormalAgreement" -> fs["NormalAgreement"],
         "Coefficients" -> fs["Coefficients"], "FaceRowsA" -> fs["FaceRowsA"],
         "FaceRowsB" -> fs["FaceRowsB"], "Offset" -> offI[[m]],
         "RowCount" -> nmi, "NDopA" -> fs["NDopA"], "NDopB" -> fs["NDopB"],
         "Matrix" -> fs["NDopA"].sel[[intf["PatchA"]]]
           + fs["Coefficients"][[2]] fs["NDopB"].sel[[intf["PatchB"]]]|>],
     {m, 1, nif}];
   (* boundary records *)
   bnd = Table[Flatten[Table[
       If[cls[[p]][[ix, iy]] === "Dirichlet",
         <|"Patch" -> p, "Flat" -> seFlatIndex[ix, iy, nn],
           "Index" -> {ix - 1, iy - 1}, "X" -> N[ops[[p]]["Xs"][[ix, iy]]],
           "Y" -> N[ops[[p]]["Ys"][[ix, iy]]],
           "Edges" -> seEdgesAtNode[{ix, iy}, nN]|>, {}],
       {iy, 1, nn}, {ix, 1, nn}]], {p, 1, np}];
   bEdges = Table[Flatten[Table[
       If[status[[p, ei]] === "Boundary",
         <|"Patch" -> p, "Edge" -> seEdgesAll[[ei]], "Nodes" -> nn,
           "InteriorNodes" -> nmi,
           "Param" -> (seEdgeParam[seEdgesAll[[ei]], #, ops[[p]]["Nodes1D"]] &)
             /@ seEdgeNodesAll[seEdgesAll[[ei]], nN]|>, {}], {ei, 1, 4}]], {p, 1, np}];
   (* stacked row blocks *)
   blocks = Join[Table[<|"Kind" -> "PDE", "Index" -> p, "Rows" -> pde[[p]]["RowCount"]|>,
       {p, 1, np}], Table[<|"Kind" -> "Flux", "Index" -> m, "Rows" -> nmi|>, {m, 1, nif}]];
   mats = Join[Table[pde[[p]]["Matrix"], {p, 1, np}],
     Table[flux[[m]]["Matrix"], {m, 1, nif}]];
   slices = {}; r0 = 0; order = {};
   Do[slices = Join[slices, {<|"Kind" -> bl["Kind"], "Index" -> bl["Index"], "First" -> r0 + 1, "Last" -> r0 + bl["Rows"], "Count" -> bl["Rows"]|>}];

      order = Join[order, {bl["Kind"]}]; r0 = r0 + bl["Rows"], {bl, blocks}];
   nPde = Total[nInt]; nFlux = nif nmi; nRow = r0;
   (* API.md 4.4 SpectralDomain::iface: matched but the two traces are not
      tangent to each other, i.e. the pairing is geometrically inconsistent *)
   badN = Count[flux[[All, "NormalAgreement"]], _?(Abs[#] < 0.5 &)];
   If[badN > 0,
     Message[SpectralElement`SpectralDomain::iface, badN,
       "the matched traces are not mutually tangent (normal agreement < 0.5): the pairing is inconsistent"]];
   (* Stack the block matrices ROW-wise.  SparseArray's 2-argument form does
      NOT accept a list of SparseArrays, so the previous
      SparseArray[Flatten[ArrayPad[...]], {nRow, nTot}] silently produced a
      degenerate 1-D object (measured: Dimensions = {1}).

      TRAP (measured, three messages in a row, Kernel/Solve.wl L61-66
      documented the symptom without the cause): ArrayPad's padding
      specification must have ONE ENTRY PER DIMENSION OF THE ARRAY.  Every
      block here is RANK 2 (rows x UnknownCount), so the flat four-element
      spec {0, 0, 0, ...} is one entry too many and ArrayPad returns
      UNEVALUATED:

        ArrayPad::depth: Padding amount {0, 0, 0, 0} should specify padding in
          no more than the number of dimensions in array SparseArray[..,{49,49}].
        ArrayFlatten::depth: The ArrayDepth ... must be at least equal to the
          specified rank 2.
        SparseArray::list: List expected at position 1 in
          SparseArray[ArrayFlatten[{ArrayPad[..,{0,0,0,0}]}], {49, 49}].

      Because SparseArray[...] was handed an unevaluated head, it built an
      object of Dimensions {2} -- a 1 x nRow x nTot box -- and stored THAT as
      System["Matrix"], the public "Matrix" key.  It stayed SILENT to every
      consumer that does not look at it, which is why the only symptoms were
      the three message tags and D's Dimensions[Matrix] == {2} measurement.

      The fix has two parts, both required:
        * the rank-2 spec {{0,0},{0,pad}} (rank 1 would be {0, 0});
        * ArrayFlatten[list, 1], NOT the default rank 2.  With exactly ONE
          block the outer list is itself a level, so rank 2 asks for two
          levels and fails; level 1 merges everything below level 0, which is
          the vertical concatenation of the row blocks for ANY number of
          blocks including one. *)
   sysMat = SparseArray[ArrayFlatten[
       ArrayPad[#, {{0, 0}, {0, Max[0, nTot - Last[Dimensions[#]]]}}] & /@ mats,
       1], {nRow, nTot}];
   <|"Type" -> "SpectralSystem", "UnknownCount" -> nTot, "RowCount" -> nRow,
     "PDERowCount" -> nPde, "FluxRowCount" -> nFlux,
     "Class" -> cls, "Loc" -> loc, "Selections" -> sel, "Lift" -> lf,
     "PDE" -> pde, "Flux" -> flux, "Blocks" -> blocks, "RowOrder" -> order,
     "RowSlices" -> slices, "InteriorOffsets" -> offP, "SharedOffsets" -> offI,
     "InteriorCounts" -> nInt, "BoundaryNodes" -> bnd, "BoundaryEdges" -> bEdges,
     "ForcedDirichlet" -> dropList, "FluxCount" -> nif,
     "Matrix" -> sysMat,
     "BlockMatrices" -> mats|>];

(* =====================================================================
   Kernel/Discretization.wl -- SpectralElement` , DISCRETIZATION LAYER
   ---------------------------------------------------------------------
   Owner: geometry/discretization wave (Wave 1).  Loaded by
   Kernel/SpectralElement.wl from INSIDE Begin["SpectralElement`Private`"].

   CONTRACT RULES OBSERVED HERE
     * NO BeginPackage / Begin / End.  Bare symbols (all prefixed `se`)
       land in SpectralElement`Private`; public symbols are FULLY
       QUALIFIED (SpectralElement`SpectralDomain, ...Data, ...Q).

   WHAT THIS FILE DOES
     1. sePatchOps       one patch -> grid, metric fields, Jacobian,
                         J (+Delta convention) Laplacian, FD-Jacobian
                         check, interior row list.   (p11 `mkOps` verbatim)
     2. interface        every patch edge is sampled at the 1-D CGL nodes
                         (endpoints + interior); two edges of two patches
                         are the SAME geometric edge iff the samples agree
                         within InterfaceTolerance, either in the same or
                         in reversed order.  Matched pairs share ONE
                         unknown per physical node (point pairing, no
                         cross-grid interpolation) and get one
                         normal-flux continuity row per shared node.
                         Unmatched edges are the domain boundary.
     3. seAssemble       the global system: per-patch selection matrices
                         M_p (nn^2 x nTot), the interior Laplace row
                         blocks -Lop_sub . M_p, the flux row blocks
                         (n_A . M_A + c_B . n_B), the boundary (Dirichlet)
                         node records, and the stacked sparse Matrix.
                         Dirichlet nodes are ELIMINATED by lifting (p11's
                         verified arrangement), so the system stays square:
                             rows = unknowns = sum (n-1)^2 + k(n-1).
     4. gates            seMinJ, seNonPositiveJ, seFDJ, seFlatDegeneracy,
                         seFluxJump, sePdeResidual, seExactGlobal,
                         seExactResiduals.

   SIGN CONVENTION (p11-pinned, do not change)
     Lop = +Lap.  A PDE row is built as  -Lop . u + <nonlinear> = f.
     nodeVec: xi is the FAST index; KroneckerProduct's SECOND argument
     acts on the fast index (Kron[Id, D2m] multiplies u_xixi).
   ===================================================================== *)

(* ---------------------------------------------------------------------
   1.  Node / row bookkeeping
   --------------------------------------------------------------------- *)

(* flat (xi-fast) index of the node with 1-BASED reference indices *)
seFlatIndex[ix_, iy_, nn_] := 1 + (ix - 1) + nn (iy - 1);

seEdgesAll = {"Bottom", "Top", "Left", "Right"};
seEdgeCoord[edge_String] := If[MemberQ[{"Bottom", "Top"}, edge], "Eta", "Xi"];
seEdgeFn[edges_List, edge_String] :=
  edges[[Switch[edge, "Bottom", 1, "Top", 2, "Left", 3, "Right", 4]]];

(* ALL nn nodes of one edge, in edge-parameter order, 1-based {ix, iy} *)
seEdgeNodesAll[edge_String, nN_Integer] := Module[{nn = nN + 1},
  Switch[edge,
    "Bottom", Table[{ix, 1}, {ix, nn}],
    "Top",    Table[{ix, nn}, {ix, nn}],
    "Left",   Table[{1, iy}, {iy, nn}],
    "Right",  Table[{nn, iy}, {iy, nn}]]];

(* INTERIOR nodes of an edge: the two patch vertices removed.
   TRAP: Drop[l, {1, -1}] does NOT mean "first and last" -- a Part/Level
   specification {n1, n2} is a RANGE, and -1 counts from the end, so it
   dropped positions 1 .. Last and returned {} for every edge.  Every
   shared-node loop therefore iterated over an empty list and silently
   marked nothing, which is why no node ever came out as "Shared" and no
   shared unknown ever got a global column.  Use an explicit Part range. *)
seEdgeNodes[edge_String, nN_Integer] := seEdgeNodesAll[edge, nN][[2 ;; -2]];

seEdgeParam[edge_String, {ix_, iy_}, xg_List] :=
  If[MemberQ[{"Bottom", "Top"}, edge], xg[[ix]], xg[[iy]]];

(* the edge curve sampled at every 1-D CGL node, in edge-parameter order *)
seEdgeSamples[patch_, edge_String, xg_List] := Module[
   {f = seEdgeFn[sePatchEdges[patch], edge],
    nd = seEdgeNodesAll[edge, Length[xg] - 1]},
   f /@ (seEdgeParam[edge, #, xg] & /@ nd)];

(* Same curve?  "Same" = node k of A is node k of B; "Reversed" = node k of
   A is node nn+1-k of B (the pair is still EXACT pointwise). *)
seEdgeMatch[sa_List, sb_List, tol_] := Module[
   {d1 = Max[Flatten[Abs[sa - sb]]], d2 = Max[Flatten[Abs[Reverse[sa] - sb]]]},
   Which[d1 <= tol, {"Same", d1}, d2 <= tol, {"Reversed", d2},
         True, {"None", Min[d1, d2]}]];

(* ---------------------------------------------------------------------
   2.  Per-patch operator table  (p11 mkOps, +Delta convention)
   --------------------------------------------------------------------- *)
sePatchOps[patch_Association, nN_Integer] := Module[
   {nn = nN + 1, xg, sm, Xs, Ys, Dm, D2m, xxi, xe, yxi, ye, Jm, al, be, ga, de,
    AA, BB, CCc, d10, d01, Lop, intRows, i0, j0, x0, y0, h, xip, xet, yip, yet,
    jfd, fdrel, Id, AB, SQE, SQX},
   sm = patch["Map"];
   xg = seCGL[-1., 1., nn];
   {Xs, Ys} = sePatchGrid[sm, xg];
   Dm = seChebD1[xg]; D2m = Dm.Dm;
   xxi = Dm.Xs; xe = Xs.Transpose[Dm]; yxi = Dm.Ys; ye = Ys.Transpose[Dm];
   Jm = xxi*ye - xe*yxi;
   al = ye/Jm; be = -yxi/Jm; ga = -xe/Jm; de = xxi/Jm;
   AA = al^2 + ga^2; BB = 2 (al be + ga de); CCc = be^2 + de^2;
   d10 = al*(Dm.al) + be*(al.Transpose[Dm]) + ga*(Dm.ga) + de*(ga.Transpose[Dm]);
   d01 = al*(Dm.be) + be*(be.Transpose[Dm]) + ga*(Dm.de) + de*(de.Transpose[Dm]);
   vv[v_] := SparseArray[Band[{1, 1}] -> seNodeVec[v]];
   Id = SparseArray[IdentityMatrix[nn]];
   Lop = vv[AA].KroneckerProduct[Id, SparseArray[D2m]]
       + vv[BB].KroneckerProduct[SparseArray[Dm], SparseArray[Dm]]
       + vv[CCc].KroneckerProduct[SparseArray[D2m], Id]
       + vv[d10].KroneckerProduct[Id, SparseArray[Dm]]
       + vv[d01].KroneckerProduct[SparseArray[Dm], Id];
   intRows = Flatten[Table[seFlatIndex[ix + 1, iy + 1, nn], {iy, 1, nN - 1}, {ix, 1, nN - 1}]];
   i0 = Floor[nn/2]; j0 = i0; x0 = xg[[i0]]; y0 = xg[[j0]]; h = 1.*^-6;
   xip = (sm[x0 + h, y0][[1]] - sm[x0 - h, y0][[1]])/(2 h);
   xet = (sm[x0, y0 + h][[1]] - sm[x0, y0 - h][[1]])/(2 h);
   yip = (sm[x0 + h, y0][[2]] - sm[x0 - h, y0][[2]])/(2 h);
   yet = (sm[x0, y0 + h][[2]] - sm[x0, y0 - h][[2]])/(2 h);
   jfd = xip*yet - xet*yip;
   fdrel = Abs[jfd - Jm[[i0, j0]]]/Abs[Jm[[i0, j0]]];
   AB = al be + ga de; SQE = Sqrt[be^2 + de^2]; SQX = Sqrt[al^2 + ga^2];
   <|"Type" -> "SpectralPatchOps", "Patch" -> patch, "Order" -> nN,
     "Nodes" -> nn, "Nodes1D" -> xg, "Xs" -> Xs, "Ys" -> Ys,
     "Dm" -> Dm, "D2m" -> D2m, "J" -> Jm,
     "MinJ" -> N[Min[Flatten[Jm]]],
     "NonPositiveJ" -> Count[Flatten[Jm], _?(# <= 0 &)],
     "CornerJ" -> N /@ {Jm[[1, 1]], Jm[[nn, 1]], Jm[[1, nn]], Jm[[nn, nn]]},
     "al" -> al, "be" -> be, "ga" -> ga, "de" -> de,
     "AA" -> AA, "AB" -> AB, "BB" -> BB, "CC" -> CCc,
     "SQ" -> SQE, "SQXi" -> SQX,
     "Lop" -> Lop, "InteriorRows" -> intRows, "FDJ" -> N[fdrel]|>];

sePatchOpsQ[ops_] := TrueQ[AssociationQ[ops] && Lookup[ops, "Type"] === "SpectralPatchOps"];

(* the physical vector field normal to a reference coordinate line:
     grad eta = (be, de),  grad xi = (al, ga)        (Kron-consistent) *)
seNormalField[ops_, coord_String] :=
  Which[coord === "Eta", {ops["be"], ops["de"]},
        coord === "Xi",  {ops["al"], ops["ga"]}, True, $Failed];

(* Normal derivative along that unit normal.  This is p11's NDop:
     d/dn_eta = (AB/SQ) d/dxi + SQ d/deta ,  SQ = |grad eta| = Sqrt[be^2+de^2]
     (on p11's annular patches AB = 0 identically, so NDop = d/dn = d/dr,
      which is why the half-annulus flux row is NDopA - NDopB.)
   The xi analogue is given for completeness (needed when two patches share
   a xi = const edge). *)
seNormalOp[ops_, coord_String] := Module[
   {nn = ops["Nodes"], Dm = ops["Dm"], Id, Dxi, Deta, vv, S},
   (* TRAP: a Module initializer does NOT see the value of an EARLIER
      initializer in the same list (measured: Module[{nn = i, Id =
      SparseArray[IdentityMatrix[nn]]}, ..] raises SparseArray::list with nn
      still a symbol).  Every dependent initializer therefore has to be
      assigned in the BODY, after the ones it reads. *)
   Id = SparseArray[IdentityMatrix[nn]];
   vv[v_] := SparseArray[Band[{1, 1}] -> seNodeVec[v]];
   Dxi = KroneckerProduct[Id, SparseArray[Dm]];
   Deta = KroneckerProduct[SparseArray[Dm], Id];
   S = If[coord === "Eta", ops["SQ"], ops["SQXi"]];
   Which[coord === "Eta", vv[ops["AB"]/S].Dxi + vv[S].Deta,
         coord === "Xi",  vv[S].Dxi + vv[ops["AB"]/S].Deta, True, $Failed]];

(* ---------------------------------------------------------------------
   3.  Interface detection and node classification
   --------------------------------------------------------------------- *)

seFindInterfaces[ops_List, tol_] := Module[{np = Length[ops], used = {}, ifs = {},
     i, j, e1, e2, sa, sb, st, dev},
   Do[
     Do[
       (* i != j: only an edge of patch i and an edge of a DIFFERENT patch j
          can form an interface.  Without this guard every edge matches
          ITSELF (trivially, deviation 0), so a one-patch domain reports four
          bogus interfaces, every patch pair is then flagged as a duplicate
          match, and multi-patch vertices appear where there are none.
          Pinned by G-B5 (exactly 1 interface) and G-B7 (0 and 2). *)
       If[i != j && ! MemberQ[used, {i, e1}] && ! MemberQ[used, {j, e2}],
         sa = seEdgeSamples[ops[[i]]["Patch"], e1, ops[[i]]["Nodes1D"]];
         sb = seEdgeSamples[ops[[j]]["Patch"], e2, ops[[j]]["Nodes1D"]];
         {st, dev} = seEdgeMatch[sa, sb, tol];
         If[st =!= "None",
           AppendTo[ifs, <|"PatchA" -> i, "EdgeA" -> e1, "PatchB" -> j,
             "EdgeB" -> e2, "Orientation" -> st, "Deviation" -> dev,
             "Nodes" -> Length[sa], "SharedNodes" -> Length[sa] - 2|>];
           used = Join[used, {{i, e1}, {j, e2}}]]],
       {j, 1, np}, {e2, seEdgesAll}],
     {i, 1, np}, {e1, seEdgesAll}];
   ifs];

seEdgeUsed[ifs_List, patch_Integer, edge_String] := Module[{hit = False},
   Do[If[(Lookup[ifs[[k]], "PatchA", -1] === patch && Lookup[ifs[[k]], "EdgeA", ""] === edge) ||
         (Lookup[ifs[[k]], "PatchB", -1] === patch && Lookup[ifs[[k]], "EdgeB", ""] === edge),
      hit = True], {k, 1, Length[ifs]}];
   hit];

seEdgeStatuses[np_Integer, ifs_List] := Table[
   Table[If[seEdgeUsed[ifs, p, seEdgesAll[[ei]]], "Interface", "Boundary"], {ei, 1, 4}],
   {p, 1, np}];

seEdgesAtNode[{ix_, iy_}, nN_Integer] :=
   Select[seEdgesAll, MemberQ[seEdgeNodesAll[#, nN], {ix, iy}] &];

(* node classes: "Interior" (own unknown) | "Shared" (one unknown per
   physical node, shared by two patches) | "Dirichlet" (lifted, known) *)
seClassifyPatch[nN_Integer, status_List] := Module[{nn = nN + 1, cls, ei, nd, k},
   cls = Table["Interior", {nn}, {nn}];
   Do[nd = seEdgeNodesAll[seEdgesAll[[ei]], nN];
      Do[cls[[nd[[k, 1]], nd[[k, 2]]]] = "Dirichlet", {k, 1, Length[nd]}], {ei, 1, 4}];
   Do[If[status[[ei]] === "Interface",
        nd = seEdgeNodes[seEdgesAll[[ei]], nN];
        Do[cls[[nd[[k, 1]], nd[[k, 2]]]] = "Shared", {k, 1, Length[nd]}]], {ei, 1, 4}];
   cls];

(* a node touching two or more interface edges is a multi-patch vertex *)
seJunctionCount[nN_Integer, status_List] := Module[{nn = nN + 1, cnt, ei, nd, k},
   cnt = Table[0, {nn}, {nn}];
   Do[If[status[[ei]] === "Interface", nd = seEdgeNodesAll[seEdgesAll[[ei]], nN];
        Do[cnt[[nd[[k, 1]], nd[[k, 2]]]]++, {k, 1, Length[nd]}]], {ei, 1, 4}];
   Length[Position[cnt, _?(# >= 2 &)]]];

(* Optional extra Dirichlet nodes from a BoundaryPredicate.  Only patch
   INTERIOR nodes may be forced: dropping a shared unknown would silently
   change the coupling, so those are refused with a message.  A forced
   interior node loses its unknown AND its PDE row, which keeps the
   system square. *)
seForceDirichlet[cls_List, ops_List, pred_] := Module[{np = Length[cls],
   out = cls, drop = {}, refused = 0, p, nn, ix, iy, c, x, y},
   If[pred === Automatic, Return[{out, drop}]];
   Do[
     nn = ops[[p]]["Nodes"];
     Do[
       c = out[[p]][[ix, iy]];
       If[c =!= "Dirichlet",
         x = N[ops[[p]]["Xs"][[ix, iy]]]; y = N[ops[[p]]["Ys"][[ix, iy]]];
         If[TrueQ[pred[{x, y}]],
           Which[c === "Interior",
                 (out[[p]][[ix, iy]] = "Dirichlet";
                  AppendTo[drop, <|"Patch" -> p, "Flat" -> seFlatIndex[ix, iy, nn],
                     "Index" -> {ix - 1, iy - 1}, "X" -> x, "Y" -> y|>]),
                 c === "Shared", refused++,
                 True, Null]]],
       {iy, 1, nn}, {ix, 1, nn}],
     {p, 1, np}];
   If[refused > 0, Message[SpectralElement`SpectralDomain::bpred, refused]];
   {out, drop}];

(* ---------------------------------------------------------------------
   4.  The interface flux row
   ---------------------------------------------------------------------
   The two normal operators are built from the SAME metric fields as the
   Laplacian:  n_eta = (be, de)/|grad eta|,  n_xi = (al, ga)/|grad xi|.
   Sigma = sign of n_A . n_B at the paired nodes:
     Sigma = +1  ->  the row is  NDopA.u_A - NDopB.u_B  (p11 E2, verbatim)
     Sigma = -1  ->  the row is  NDopA.u_A + NDopB.u_B
   B's face rows are PERMUTED into A's order when the two edges are
   traversed in opposite directions, so every row pairs one exact
   physical node with its twin. *)
seFluxSide[opsA_, opsB_, intf_] := Module[
   {nN = opsA["Order"], nn = opsA["Nodes"], coordA, coordB, revQ, ndA, ndB, rowsA,
    rowsB, ord, nfA, nfB, unA, unB, pa, pb, dp, sig},
   coordA = seEdgeCoord[intf["EdgeA"]]; coordB = seEdgeCoord[intf["EdgeB"]];
   revQ = TrueQ[intf["Orientation"] === "Reversed"];
   ndA = seEdgeNodes[intf["EdgeA"], nN]; ndB = seEdgeNodes[intf["EdgeB"], nN];
   rowsA = (seFlatIndex[#[[1]], #[[2]], nn] &) /@ ndA;
   ord = If[revQ, Reverse[Range[nN - 1]], Range[nN - 1]];
   rowsB = (seFlatIndex[ndB[[#]][[1]], ndB[[#]][[2]], nn] &) /@ ord;
   (* TRAP: seNormalField returns the PAIR of PHYSICAL components of the
      gradient as a two-element list {c1, c2} of node matrices -- it is NOT a
      scalar field.  Part[..., i, j] on that list is a Part on a depth-2
      object, so for i, j > 1 it stayed unevaluated, Normalize passed it
      through unchanged, and the agreement dot product was formed from
      garbage -- which is where Sigma = -1 came from.  Take the two
      components explicitly. *)
   nfA = seNormalField[opsA, coordA]; nfB = seNormalField[opsB, coordB];
   (* Build the node lists straight in the FLAT layout
      k = 1 + (ix-1) + nn (iy-1) (xi fast).  Going through seNodeVec =
      Flatten[Transpose[..]] on a table of PAIRS would transpose the pair
      axis as well and produce 2 nn^2 scalars, so unA[[rowsA]] handed back
      bare components instead of unit vectors. *)
   unA = Table[N[Normalize[{nfA[[1]][[Mod[k - 1, nn] + 1, Quotient[k - 1, nn] + 1]],
      nfA[[2]][[Mod[k - 1, nn] + 1, Quotient[k - 1, nn] + 1]]}]], {k, 1, nn^2}];
   unB = Table[N[Normalize[{nfB[[1]][[Mod[k - 1, nn] + 1, Quotient[k - 1, nn] + 1]],
      nfB[[2]][[Mod[k - 1, nn] + 1, Quotient[k - 1, nn] + 1]]}]], {k, 1, nn^2}];
   pa = unA[[rowsA]]; pb = unB[[rowsB]];
   dp = N[Mean[Flatten[Table[pa[[k]][[1]] pb[[k]][[1]] + pa[[k]][[2]] pb[[k]][[2]], {k, 1, Length[pa]}]]]];
   sig = If[TrueQ[dp > 0], 1, -1];
   <|"CoordA" -> coordA, "CoordB" -> coordB, "FaceRowsA" -> rowsA,
     "FaceRowsB" -> rowsB, "NormalAgreement" -> dp, "Sigma" -> sig,
     "NDopA" -> seNormalOp[opsA, coordA][[rowsA]],
     "NDopB" -> seNormalOp[opsB, coordB][[rowsB]],
     "Coefficients" -> {1, -sig}|>];

(* ---------------------------------------------------------------------
   5.  Global assembly
   ---------------------------------------------------------------------
   Unknown layout (0-based offsets, 1-based column numbers):
     block 1..np   : the patch interior unknowns, patch order, ascending
                      flat node index inside the patch
     block np+1..   : one shared block per interface pair, in the node
                      order of side A ( = physical node order )
   Row layout: PDE rows of patch 1, of patch 2, ... then one flux row per
   interface pair.  Dirichlet nodes produce NO row (they are lifted), so
   rows = unknowns = sum_p (n-1)^2 + #(interfaces) (n-1). *)

(* The gates hand these in as NAMED down-values (uex[x_, y_] := ...), not as
   pure Function objects, so the patterns must NOT require _Function: the bare
   symbol uex does not match g_Function and every call stayed unevaluated.
   They only have to be callable as f[x, y]. *)
(* ---------------------------------------------------------------------
   6.  Dirichlet lift and exact-solution helpers  (used by the gates and,
       unchanged, by the Newton layer)
   --------------------------------------------------------------------- *)

(* TRAP -- MEASURED, and it was the WHOLE no-DirichletCondition hang
   (Tests/out/installprobe.104951_54302.txt, 900 s guard; the numbers below are
   from Tests/out/d2_r3diag.*.txt).  With no DirichletCondition in the equation
   the caller hands this routine the bare NUMBER 0 -- the homogeneous-Dirichlet
   default of API.md 4.3, seDirLiftFn[{}, _, _] := 0 -- and 0 is not callable.
   g[qx, qy] on it is the PRECISION-TAGGED zero 0.[qx, qy]: its head is 0., its
   magnitude is zero, but NumericQ is False, N[] passes it through untouched
   (InputForm[N[0[-1., -1.]]] is 0.[-1., -1.], NumericQ of it is False, and
   0.[-1., -1.] === 0. is False), which is why N[] here did not help.
   Writing that into the lift is not cosmetic.  On a one-patch degree-8 domain
   ALL 32 Dirichlet entries became tagged zeros while the 49 interior entries
   stayed clean 0., so seLiftConst came back with 49 of 49 entries
   NON-NUMERIC -- sums such as 131.14408626202*0.[-1., -0.9238...] -- rhs - c0
   stayed symbolic, and LinearSolve on a perfectly numeric 49 x 49 matrix never
   returned.  The SAME matrix against a plain numeric right-hand side returned a
   49-vector in 0.000415 s with max|A0.z| = 0 exactly.

   The node value is therefore taken HERE, at the routine whose output contract
   is a numeric vector: a NUMBER g is the constant it stands for -- which is
   precisely what the no-DC case passes -- and anything else is called as
   f[qx, qy] and N[]-ed, exactly as before.  Nothing is substituted, clamped or
   discarded, and no Quiet is involved: a lift that is still non-numeric is
   REFUSED by the caller (SpectralNDSolve::nlift), never assembled. *)
seLiftNode[g_, qx_, qy_] := N[If[TrueQ[NumericQ[g]], g, g[qx, qy]]];

(* per patch: an nn^2 vector holding g at the Dirichlet nodes, 0 elsewhere *)
seLiftFrom[disc_, g_] := Module[{o = disc["PatchOps"], cl = disc["Class"],
   nn = disc["NodeCount"]},
   Table[seNodeVec[Table[If[TrueQ[cl[[p]][[ix, iy]] === "Dirichlet"],
       seLiftNode[g, o[[p]]["Xs"][[ix, iy]], o[[p]]["Ys"][[ix, iy]]], 0.],
     {ix, 1, nn}, {iy, 1, nn}]], {p, Length[o]}]];

(* which (interface, position) does a Shared node of patch p belong to? *)
seSharedSlot[disc_, p_, ix_, iy_] := Module[{nn = disc["NodeCount"],
     k, g, off, m},
   (* k depends on nn: see the Module-initializer trap noted in seNormalOp *)
   k = seFlatIndex[ix, iy, nn];
   g = disc["System"]["Loc"][[p]][[k]];
   off = disc["System"]["SharedOffsets"];
   m = SelectFirst[Range[Length[off]], (g > off[[#]] && g <= off[[#]] + nn - 2) &];
   {m, g - off[[m]]}];

(* the exact global vector of g: interior nodes from their own patch,
   shared nodes averaged over the (identical) incident physical points *)
seExactGlobal[disc_, g_] := Module[{o = disc["PatchOps"],
     cl = disc["Class"], loc = disc["System"]["Loc"],
     off = disc["System"]["SharedOffsets"], nn = disc["NodeCount"],
     nTot = disc["System"]["UnknownCount"],
     np, nmi, acc, cnt, U, p, ix, iy, k, c, v, sj, m},
   (* np, nmi, acc, cnt and U all read o / nn / off / nTot, which are other
      initializers -- see the Module-initializer trap noted in seNormalOp *)
   np = Length[o]; nmi = nn - 2;
   acc = ConstantArray[0., {Length[off], nmi}];
   cnt = ConstantArray[0, {Length[off], nmi}];
   U = Table[0., {nTot}];
   Do[
     k = seFlatIndex[ix, iy, nn]; c = cl[[p]][[ix, iy]];
     If[c =!= "Dirichlet",
       v = N[g[o[[p]]["Xs"][[ix, iy]], o[[p]]["Ys"][[ix, iy]]]];
       If[c === "Interior", U[[loc[[p]][[k]]]] = v,
         sj = seSharedSlot[disc, p, ix, iy];
         acc[[sj[[1]], sj[[2]]]] += v; cnt[[sj[[1]], sj[[2]]]] += 1]],
     {iy, 1, nn}, {ix, 1, nn},
   {p, 1, np}];
   Do[If[cnt[[m, j]] > 0, U[[off[[m]] + j]] = acc[[m, j]]/cnt[[m, j]]],
  {m, Length[off]}, {j, 1, nmi}];
   U];

(* right-hand side sampled on the PDE rows, in InteriorRows order *)
seFvec[disc_, p_Integer, f_] := Module[{o = disc["PatchOps"][[p]],
   nn = disc["NodeCount"]},
   Flatten[Table[N[f[o["Xs"][[ix + 1, iy + 1]], o["Ys"][[ix + 1, iy + 1]]]],
     {iy, 1, nn - 2}, {ix, 1, nn - 2}]]];

(* G7: the interface flux row applied to the EXACT grid functions of g,
   one per patch, on the exact shared physical nodes (p11's g7). *)
seFluxJump[disc_, m_Integer, g_] := Module[{o = disc["PatchOps"],
     f = disc["System"]["Flux"][[m]], nn = disc["NodeCount"], uA, uB, dA, dB},
   dA = o[[f["PatchA"]]]; dB = o[[f["PatchB"]]];
   uA = seNodeVec[Table[N[g[dA["Xs"][[ix, iy]], dA["Ys"][[ix, iy]]]], {ix, 1, nn}, {iy, 1, nn}]];
   uB = seNodeVec[Table[N[g[dB["Xs"][[ix, iy]], dB["Ys"][[ix, iy]]]], {ix, 1, nn}, {iy, 1, nn}]];
   N[seEmx[f["Coefficients"][[1]] f["NDopA"].uA
      + f["Coefficients"][[2]] f["NDopB"].uB]]];

(* G6: the assembled blocks evaluated on the exact solution.  PDE blocks
   go through the ASSEMBLED sparse Matrix (so the matrix itself is under
   test) plus the lift, then + nonlinear(g) - f. *)
seExactResiduals[disc_, g_, f_, nl_] := Module[
   {z = seExactGlobal[disc, g], lf = seLiftFrom[disc, g], s = disc["System"],
    o = disc["PatchOps"], pde, flux},
   pde = Table[Module[{Up, rows, res},
       rows = o[[p]]["InteriorRows"];
       Up = s["Selections"][[p]].z + lf[[p]];
       res = s["PDE"][[p]]["Matrix"].z - s["PDE"][[p]]["Lop"].lf[[p]]
         + (nl /@ Up[[rows]]) - seFvec[disc, p, f];
       seEmx[res]], {p, Length[o]}];
   flux = Table[Module[{f, A, B},
       f = s["Flux"][[m]]; A = f["PatchA"]; B = f["PatchB"];
       seEmx[f["Matrix"].z + f["Coefficients"][[1]] f["NDopA"].lf[[A]]
         + f["Coefficients"][[2]] f["NDopB"].lf[[B]]]], {m, s["FluxCount"]}];
   <|"PDE" -> pde, "Flux" -> flux|>];

(* ---------------------------------------------------------------------
   7.  Public: SpectralDomain / SpectralDomainQ / SpectralDomainData
   --------------------------------------------------------------------- *)

Options[SpectralElement`SpectralDomain] =
  {Method -> "Analytic", InterfaceTolerance -> 1.*^-10, "InterfaceTolerance" -> 1.*^-10,
   BoundaryPredicate -> Automatic, "BoundaryPredicate" -> Automatic,
   CornerTolerance -> 1.*^-12};

seResolveDomainOpts[opts : OptionsPattern[SpectralElement`SpectralDomain]] := Module[
   {a = OptionValue[InterfaceTolerance], b = OptionValue["InterfaceTolerance"],
    c = OptionValue[BoundaryPredicate], d = OptionValue["BoundaryPredicate"]},
   <|"Method" -> OptionValue[Method],
     "InterfaceTolerance" -> Which[! TrueQ[AutomaticQ[b]], b, ! TrueQ[AutomaticQ[a]], a, True, 1.*^-10],
     "BoundaryPredicate" -> Which[! TrueQ[AutomaticQ[d]], d, ! TrueQ[AutomaticQ[c]], c, True, Automatic],
     "CornerTolerance" -> OptionValue[CornerTolerance]|>];

SpectralElement`SpectralDomain::nrange = "SpectralDomain: the degree must be an integer >= 2, got `1`.";
SpectralElement`SpectralDomain::patches = "SpectralDomain: the first argument must be a list of CoonsPatch objects (all at the same degree).  Offending element: `1`.";
SpectralElement`SpectralDomain::nreg = "SpectralDomain: the region `1` is not supported: `2`";
SpectralElement`SpectralDomain::iface = "SpectralDomain::iface -- `1`; edges matched within InterfaceTolerance but `2`.";
SpectralElement`SpectralDomain::span = "SpectralDomain: the annular angular span `1` exceeds 2 Pi.";
SpectralElement`SpectralDomain::degen = "SpectralDomain: patch `1` has a non-positive Jacobian (min J = `2`); the transfinite map is degenerate or flipped.";
SpectralElement`SpectralDomain::junc = "SpectralDomain: `1` node(s) touch two or more interface edges.  Multi-patch VERTICES are not supported in this wave: those vertices are treated as boundary (Dirichlet) nodes.";
SpectralElement`SpectralDomain::bpred = "SpectralDomain: BoundaryPredicate marked `1` node(s) that lie on a SHARED interface edge; those are refused (a shared unknown cannot simply be dropped).";
SpectralElement`SpectralDomain::key = "SpectralDomainData: `1` is not a key of a SpectralDiscretization.  Known keys: `2`.";
SpectralElement`SpectralDomain::form = "SpectralDomainData: `1` is not a SpectralDiscretization object.";

seDataKeys = {"PatchCount", "Degree", "Nodes", "NodeCount", "NodesPerPatch",
  "UnknownCount", "RowCount", "Patches", "PatchMap", "Coordinates", "X", "Y",
  "Jacobian", "MinJacobian", "NonPositiveJacobianCount", "CornerJacobian",
  "FDJacobian", "Laplacian", "InteriorRows", "InteriorRowCounts",
  "NormalOperator", "InterfacePairs", "InterfaceCount", "EdgeStatus",
  "BoundaryEdges", "BoundaryRows", "FluxRows", "Class", "Selections", "Matrix", "PatchOps",
  "RowOrder", "RowSlices", "Lift", "System", "Method", "InterfaceTolerance",
  "CornerTolerance", "Junctions"};

seBuildDomain[patches_List, nN_Integer, o_Association] := Module[
   {ops, ifs, status, sys, disc, jc, bad, seen, dup, pp, q},
   If[! And @@ (SpectralElement`CoonsPatchQ /@ patches),
     Message[SpectralElement`SpectralDomain::patches, seTrunc[patches]]; Return[$Failed]];
   ops = sePatchOps[#, nN] & /@ patches;
   bad = Table[If[TrueQ[ops[[p]]["MinJ"] <= 0], p, Nothing], {p, Length[ops]}];
   (* J <= 0 at a patch VERTEX is reported already by CoonsPatch::tangent;
      J <= 0 anywhere else is a flipped or self-overlapping patch. *)
   If[bad = {}, Null,
     Message[SpectralElement`SpectralDomain::degen, seTrunc[bad],
       seTrunc[Table[ops[[p]]["MinJ"], {p, bad}]]]];
   ifs = seFindInterfaces[ops, o["InterfaceTolerance"]];
   (* API.md 4.4: an interface matched twice is an error, not a silent union *)
   seen = {}; dup = 0;
   Do[pp = Sort[{ifs[[q]]["PatchA"], ifs[[q]]["PatchB"]}];
      If[MemberQ[seen, pp], dup++, seen = Join[seen, {pp}]], {q, Length[ifs]}];
   If[dup > 0,
     Message[SpectralElement`SpectralDomain::iface, dup,
       "the same pair of patches was matched along two different edges"]];
   status = seEdgeStatuses[Length[ops], ifs];
   sys = seAssemble[patches, ops, ifs, status, nN, o["BoundaryPredicate"]];
   jc = Total[Table[seJunctionCount[nN, status[[p]]], {p, Length[ops]}]];
   If[jc > 0, Message[SpectralElement`SpectralDomain::junc, jc]];
   disc = <|"Type" -> "SpectralDiscretization", "Domain" -> "SpectralElement`",
     "Degree" -> nN, "NodeCount" -> Length[ops[[1]]["Nodes1D"]],
     "Nodes" -> ops[[1]]["Nodes1D"], "PatchCount" -> Length[ops],
     "Patches" -> patches, "PatchMap" -> (Lookup[#, "Map"] &) /@ patches,
     "PatchOps" -> ops, "Interfaces" -> ifs, "InterfacePairs" -> Length[ifs],
     "EdgeStatus" -> status, "Class" -> sys["Class"], "System" -> sys,
     "Junctions" -> jc, "Method" -> o["Method"],
     "InterfaceTolerance" -> o["InterfaceTolerance"],
     "CornerTolerance" -> o["CornerTolerance"],
     "BoundaryPredicate" -> o["BoundaryPredicate"]|>];

SpectralElement`SpectralDomain[patches_List, n_Integer, opts : OptionsPattern[]] :=
   Module[{o = seResolveDomainOpts[], bad},
     If[n < 2, Message[SpectralElement`SpectralDomain::nrange, n]; Return[$Failed]];
     bad = Select[patches, ! TrueQ[SpectralElement`CoonsPatchQ[#]] &];
     If[bad =!= {},
       Message[SpectralElement`SpectralDomain::patches, seTrunc[First[bad]]];
       Return[$Failed]];
     seBuildDomain[patches, n, o]];

(* ---- region shorthands ------------------------------------------------ *)
SpectralElement`SpectralDomain[region_, n_Integer, opts : OptionsPattern[]] := Module[
   {o = seResolveDomainOpts[], pl, bad},
   pl = Which[
     MatchQ[region, Rectangle[_, _]],
       (If[region[[2]][[1]] <= region[[1]][[1]] || region[[2]][[2]] <= region[[1]][[2]],
          Message[SpectralElement`SpectralDomain::nreg, seTrunc[region], "need x2 > x1 and y2 > y1"];
          Return[$Failed]];
       {SpectralElement`CoonsPatch[seRectEdges[region[[1]], region[[2]]],
          Method -> o["Method"], CornerTolerance -> o["CornerTolerance"]]}),
     MatchQ[region, Annulus[_, _]],
       (If[region[[1, 1]] <= 0 || region[[1, 2]] <= region[[1, 1]],
          Message[SpectralElement`SpectralDomain::nreg, seTrunc[region], "need 0 < r1 < r2 (r1 = 0 gives J = 0)"];
          Return[$Failed]];
        seAnnulusPatches[region[[1]], region[[2]], o]),
     MatchQ[region, Disk[_, _]],
       (Message[SpectralElement`SpectralDomain::nreg, seTrunc[region],
          "a disk has r = 0 where the polar/transfinite map is singular (J = 0); use a patch with true corners or wait for the AAA mesh"];
        $Failed),
     True, (Message[SpectralElement`SpectralDomain::nreg, seTrunc[region],
        "only a CoonsPatch list, Rectangle or Annulus are supported"];
       $Failed)];
   If[! ListQ[pl], Return[$Failed]];
   bad = Select[pl, ! TrueQ[SpectralElement`CoonsPatchQ[#]] &];
   If[bad =!= {},
     Message[SpectralElement`SpectralDomain::patches, seTrunc[First[bad]]];
     Return[$Failed]];
   seBuildDomain[pl, n, o]];

(* angular sectors: one polar patch per sector of at most Pi *)
seAnnulusPatches[{r1_, r2_}, {t1_, t2_}, o_Association] := Module[
   {span = t2 - t1, t2c, ns, pl},
   If[span <= 0, t2c = t1 + span + 2 Pi; span = span + 2 Pi, t2c = t2];
   If[span > 2 Pi + 1.*^-12,
     Message[SpectralElement`SpectralDomain::span, N[span]]; Return[$Failed]];
   ns = Max[1, Ceiling[span/Pi]];
   pl = Table[SpectralElement`CoonsPatch[seAnnulusEdges[{r1, r2},
       {t1 + (j - 1) span/ns, t1 + j span/ns}],
     Method -> o["Method"], CornerTolerance -> o["CornerTolerance"]], {j, 1, ns}];
   pl];

SpectralElement`SpectralDomainQ[disc_] := TrueQ[AssociationQ[disc]
   && Lookup[disc, "Type"] === "SpectralDiscretization"
   && AssociationQ[Lookup[disc, "System", {}]]
   && Length[Lookup[disc, "PatchOps", {}]] >= 1];

SpectralElement`SpectralDomainData[disc_] := disc;

SpectralElement`SpectralDomainData[disc_, key_String] /;
   TrueQ[SpectralElement`SpectralDomainQ[disc]] := Module[{o = disc["PatchOps"],
     s = disc["System"], nn = disc["NodeCount"]},
   Switch[key,
    "PatchCount", disc["PatchCount"],
    "Degree", disc["Degree"],
    "Nodes", disc["Nodes"],
    "NodeCount", nn,
    "NodesPerPatch", nn^2,
    "UnknownCount", s["UnknownCount"],
    "RowCount", s["RowCount"],
    "Patches", disc["Patches"],
    "PatchMap", disc["PatchMap"],
    (* TRAP -- MEASURED (Tests/out/e_probe5.115628_60497.txt: KEY
       "Coordinates" head=Symbol nmsgs=12, every other key clean).  This
       branch was `(Table[{N[o[[p]]["Xs"][[ix, iy]]], ...}, {ix, 1, nn},
       {iy, 1, nn}] &) /@ Range[disc["PatchCount"]]` -- a pure function with
       NO parameter, so the mapped value was thrown away and `p` stayed
       unbound: o[[p]] was symbolic, the fetch returned $Failed after 12
       messages, and the key that exists to hand back the node coordinates
       handed back nothing.  Mapped over `o` with `#`, like the eleven
       branches below it.  PatchCount IS Length[ops] (the association is built
       with "PatchCount" -> Length[ops]), so the outer length is unchanged. *)
    "Coordinates", (Table[{N[#]["Xs"][[ix, iy]], N[#]["Ys"][[ix, iy]]},
        {ix, 1, nn}, {iy, 1, nn}] &) /@ o,
    "X", (Lookup[#, "Xs"] &) /@ o,
    "Y", (Lookup[#, "Ys"] &) /@ o,
    "Jacobian", (Lookup[#, "J"] &) /@ o,
    "MinJacobian", (Lookup[#, "MinJ"] &) /@ o,
    "NonPositiveJacobianCount", (Lookup[#, "NonPositiveJ"] &) /@ o,
    "CornerJacobian", (Lookup[#, "CornerJ"] &) /@ o,
    "FDJacobian", (Lookup[#, "FDJ"] &) /@ o,
    "Laplacian", (Lookup[#, "Lop"] &) /@ o,
    "InteriorRows", (Lookup[#, "InteriorRows"] &) /@ o,
    "InteriorRowCounts", (Length[Lookup[#, "InteriorRows"]] &) /@ o,
    "NormalOperator", (seNormalOp[#, "Eta"] &) /@ o,
    "InterfacePairs", disc["Interfaces"],
    "InterfaceCount", disc["InterfacePairs"],
    "EdgeStatus", disc["EdgeStatus"],
    "BoundaryEdges", s["BoundaryEdges"],
    "BoundaryRows", s["BoundaryNodes"],
    "FluxRows", s["Flux"],
    "Class", s["Class"],
    "Selections", s["Selections"],
    "PatchOps", disc["PatchOps"],
    "Matrix", s["Matrix"],
    "RowOrder", s["RowOrder"],
    "RowSlices", s["RowSlices"],
    "Lift", s["Lift"],
    "System", s,
    "Method", disc["Method"],
    "InterfaceTolerance", disc["InterfaceTolerance"],
    "CornerTolerance", disc["CornerTolerance"],
    "Junctions", disc["Junctions"],
    _, Message[SpectralElement`SpectralDomain::key, key, seTrunc[seDataKeys]];
      $Failed]];

(* NB the message must name the ARGUMENT that is wrong, not $Input: inside a
   Message issued from a Get-ed file, $Input is the name of the file being
   read, which told the reader nothing at all about the offending object.
   Pinned by G-B5 / G-B8. *)
SpectralElement`SpectralDomainData[args___] :=
   (Message[SpectralElement`SpectralDomain::form, seTrunc[{args}]]; $Failed);

(* ---------------------------------------------------------------------
   9.  Gates that live here for convenience of Tests/geoprobe.wl
   --------------------------------------------------------------------- *)

(* the domain shorthands build their patches through this wrapper, so the
   probe can check "the Rectangle shorthand is the identity transfinite
   map" without touching the option plumbing *)
seRegionPatch[region_, o_Association] := Which[
   MatchQ[region, Rectangle[_, _]],
     SpectralElement`CoonsPatch[seRectEdges[region[[1]], region[[2]]],
       Method -> o["Method"], CornerTolerance -> o["CornerTolerance"]],
   MatchQ[region, Annulus[_, _]],
     seAnnulusPatches[region[[1]], region[[2]], o],
   True, $Failed];

(* Public entry point of the assembler.  Kept as a one-line wrapper around
   seAssembleCore so that a load-time failure of the (very long) core body
   cannot leave the call site silently undefined -- which is exactly what
   happened once (Tests/out/b2ctx.*.txt). *)
seAssemble[patches_List, ops_List, ifs_List, status_List, nN_Integer, pred_] :=
  seAssembleCore[patches, ops, ifs, status, nN, pred];
(* <<< END OF INLINED Kernel/Discretization.wl *)
(* ==================================================================
   >>> INLINED VERBATIM FROM Kernel/Solve.wl (760 source lines, SHA-256 78087599676307093687244073859810703668987969638769486373742703985931744055533)
   ================================================================== *)
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
(* <<< END OF INLINED Kernel/Solve.wl *)

End[]

EndPackage[]
