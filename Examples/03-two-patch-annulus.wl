(* ==================================================================== *)
(* Examples/03-two-patch-annulus.wl                             E   *)
(*                                                                     *)
(* THE MULTI-PATCH LAYER.  The upper half-annulus 1 <= r <= 2,         *)
(* 0 <= \[Theta] <= \[Pi],  split radially at r = 1.5 into TWO transfinite*)
(* patches.  The two share the circle r = 1.5 exactly, and the solver  *)
(* couples them the way a conforming continuous-Galerkin assembly does: *)
(* one shared unknown per physical node on the interface, plus one     *)
(* explicit normal-flux continuity row per interior interface node.    *)
(*                                                                     *)
(*     ./rr.sh 300 Examples/03-two-patch-annulus.wl                   *)
(*                                                                     *)
(* EXPECTED MESSAGES: none.  The run is silent.                       *)
(* ==================================================================== *)
$HistoryLength = 0;

sfLog = If[StringQ[Environment["SPECF_OUT"]], Environment["SPECF_OUT"], FileNameJoin[{DirectoryName[$InputFileName], "03-two-patch-annulus.txt"}]];
sfStream = OpenWrite[sfLog];
sf[args___] := Module[{s = StringJoin[ToString[#, InputForm] & /@ {args}]}, WriteString[sfStream, s <> "\n"]; Flush[sfStream]; Print[s]];

If[! MemberQ[$ContextPath, "SpectralElement`"], Get[FileNameJoin[{DirectoryName[$InputFileName], "..", "Kernel", "SpectralElement.wl"}]]];
If[! MemberQ[$ContextPath, "SpectralElement`"], Needs["SpectralElement`"]];

nodeErr[fn_, disc_, exact_] := Module[{XX, YY, np, nn}, XX = SpectralDomainData[disc, "X"]; YY = SpectralDomainData[disc, "Y"]; np = Length[XX]; nn = Dimensions[XX[[1]]][[1]]; Max[Flatten[Table[Abs[fn[XX[[p, i, j]], YY[[p, i, j]]] - exact[XX[[p, i, j]], YY[[p, i, j]]]], {p, 1, np}, {i, 1, nn}, {j, 1, nn}]]]];

(* ------------------------------------------------------------------ *)
(* One annular sector.  g is written as a + b tt, so g[-1] and g[1] are *)
(* the inner and outer radii; tt runs over [-1, 1] and is mapped to an *)
(* angle that DECREASES with tt, which is the orientation that makes J  *)
(* positive (see the comment in Kernel/Geometry.wl on seAnnulusEdges). *)
(* ------------------------------------------------------------------ *)
thE[tt_] := Pi (1 - tt)/2;
mkHalf[g_] := {Function[tt, g[-1] {Cos[thE[tt]], Sin[thE[tt]]}], Function[tt, g[1] {Cos[thE[tt]], Sin[thE[tt]]}], Function[tt, g[tt] {-1, 0}], Function[tt, g[tt] {1, 0}]};
inner = Function[tt, 1.25 + 0.25 tt];
outer = Function[tt, 1.75 + 0.25 tt];

pA = CoonsPatch[mkHalf[inner]];
pB = CoonsPatch[mkHalf[outer]];
patches = {pA, pB};
sf["patch 1 radii = ", N[{inner[-1], inner[1]}], "   patch 2 radii = ", N[{outer[-1], outer[1]}], "   shared circle r = ", N[inner[1]]];

n = 16;
disc = SpectralDomain[patches, n];
sf["degree n                    = ", n];
sf["PatchCount                  = ", SpectralDomainData[disc, "PatchCount"]];
sf["InterfacePairs              = ", SpectralDomainData[disc, "InterfacePairs"]];
sf["InterfaceCount              = ", SpectralDomainData[disc, "InterfaceCount"]];
sf["FluxRows per patch          = ", Map[Length, SpectralDomainData[disc, "FluxRows"]]];
sf["BoundaryRows per patch      = ", Map[Length, SpectralDomainData[disc, "BoundaryRows"]]];
sf["InteriorRows per patch      = ", SpectralDomainData[disc, "InteriorRowCounts"]];
sf["UnknownCount                = ", SpectralDomainData[disc, "UnknownCount"]];
sf["RowCount                    = ", SpectralDomainData[disc, "RowCount"]];
sf["min Jacobian per patch      = ", N[SpectralDomainData[disc, "MinJacobian"]]];
(* The interface nodes are SHARED: two patches of 17 x 17 = 289 nodes
   each would be 578 unknowns if they were independent.  They are not:
   the shared circle costs one unknown per node, and the flux rows add
   one equation per interior interface node, so the two blocks are
   square and the counts line up. *)
sf["2 x 17^2 = ", 2 17^2, "  vs UnknownCount = ", SpectralDomainData[disc, "UnknownCount"]];

(* ------------------------------------------------------------------ *)
(* Solve.  THE BOUNDARY PREDICATE MUST NAME EVERY SIDE, INCLUDING THE  *)
(* TWO RADIAL EDGES ON y = 0.  Annulus[{r1, r2}, {t1, t2}] is only a    *)
(* sub-annulus: leave the radial edges out and those nodes fall back   *)
(* to the homogeneous-Dirichlet default u == 0, which uex does not     *)
(* satisfy, and the reported error becomes O(1) and stops converging.  *)
(* ------------------------------------------------------------------ *)
uex[x_, y_] := Sin[2 x + 1] Cos[3 y - 1] + x y/5;
fLin = -Laplacian[uex[x, y], {x, y}];
onHalf = Abs[Sqrt[x^2 + y^2] - 1] < 1.*^-8 || Abs[Sqrt[x^2 + y^2] - 2] < 1.*^-8 || Abs[y] < 1.*^-8;
eqP = {-Laplacian[u[x, y], {x, y}] == fLin, DirichletCondition[u[x, y] == uex[x, y], onHalf]};

nMsg0 = Length[$MessageList];
{tm, fnA} = AbsoluteTiming[SpectralNDSolveValue[eqP, u, {x, y} \[Element] patches, n]];
sf["wall clock                  = ", N[tm], " s"];
sf["messages raised             = ", Length[$MessageList[[nMsg0 + 1 ;;]]]];
sf["max nodal error vs uex      = ", N[nodeErr[fnA, disc, uex]]];
sf["u at (0.75, 0.75) computed  = ", N[fnA[0.75, 0.75]]];
sf["u at (0.75, 0.75) exact     = ", N[uex[0.75, 0.75]]];

(* A continuous value ACROSS the interface circle: the two patches are
   coupled, so the function does not jump at r = 1.5. *)
across = N[{fnA[1.5 Cos[Pi/4], 1.5 Sin[Pi/4] - 1.*^-12], fnA[1.5 Cos[Pi/4], 1.5 Sin[Pi/4] + 1.*^-12]}];
sf["either side of r = 1.5      = ", across];
sf["jump across the interface   = ", N[Abs[across[[1]] - across[[2]]]]];

sf["VERDICT: 03-two-patch-annulus OK (no messages)"];
Close[sfStream];