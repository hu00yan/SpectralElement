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

Get[FileNameJoin[{DirectoryName[$InputFileName], "AAA.wl"}]]
Get[FileNameJoin[{DirectoryName[$InputFileName], "Geometry.wl"}]]
Get[FileNameJoin[{DirectoryName[$InputFileName], "Discretization.wl"}]]
Get[FileNameJoin[{DirectoryName[$InputFileName], "Solve.wl"}]]

End[]

EndPackage[]
