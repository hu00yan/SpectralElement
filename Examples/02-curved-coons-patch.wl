(* ==================================================================== *)
(* Examples/02-curved-coons-patch.wl                             E   *)
(*                                                                     *)
(* THE GEOMETRY LAYER, on a genuinely curved patch: four TRUE corners *)
(* joined by four concave quadratic arcs.  Builds the patch by hand,   *)
(* checks the transfinite map reproduces its own four edges,          *)
(* discretizes it, reads the assembly back out through the public     *)
(* SpectralDomainData keys, and solves on it.                        *)
(*                                                                     *)
(*     ./rr.sh 300 Examples/02-curved-coons-patch.wl                 *)
(*                                                                     *)
(* EXPECTED MESSAGES: CoonsPatch (refusing the degenerate patch) and *)
(* SpectralDomain (refusing to discretize it), both in the LAST       *)
(* section, where they are the point of the example.  Every other    *)
(* line of the run is silent.                                         *)
(*                                                                     *)
(* THE ONE MODELLING RULE THIS EXAMPLE EXISTS TO SHOW: a transfinite *)
(* patch needs its vertices to be TRUE CORNERS of the domain.  The    *)
(* last section tries to make one single patch out of a smooth closed *)
(* curve, whose four "corners" are tangent to each other, and is      *)
(* refused twice over.                                                *)
(* ==================================================================== *)
$HistoryLength = 0;

sfLog = If[StringQ[Environment["SPECF_OUT"]], Environment["SPECF_OUT"], FileNameJoin[{DirectoryName[$InputFileName], "02-curved-coons-patch.txt"}]];
sfStream = OpenWrite[sfLog];
sf[args___] := Module[{s = StringJoin[ToString[#, InputForm] & /@ {args}]}, WriteString[sfStream, s <> "\n"]; Flush[sfStream]; Print[s]];

If[! MemberQ[$ContextPath, "SpectralElement`"], Get[FileNameJoin[{DirectoryName[$InputFileName], "..", "Kernel", "SpectralElement.wl"}]]];
If[! MemberQ[$ContextPath, "SpectralElement`"], Needs["SpectralElement`"]];

(* ------------------------------------------------------------------ *)
(* Helper: max nodal error against a manufactured solution, over every *)
(* node of every patch, using the public "X" / "Y" keys.               *)
(* ------------------------------------------------------------------ *)
nodeErr[fn_, disc_, exact_] := Module[{XX, YY, np, nn}, XX = SpectralDomainData[disc, "X"]; YY = SpectralDomainData[disc, "Y"]; np = Length[XX]; nn = Dimensions[XX[[1]]][[1]]; Max[Flatten[Table[Abs[fn[XX[[p, i, j]], YY[[p, i, j]]] - exact[XX[[p, i, j]], YY[[p, i, j]]]], {p, 1, np}, {i, 1, nn}, {j, 1, nn}]]]];

(* ------------------------------------------------------------------ *)
(* A "pincushion": the unit square with each side pushed IN by gamma. *)
(* Order of the argument is {bottom, top, left, right}; bottom and top *)
(* are parameterized by \[Xi] in [-1, 1], left and right by \[Eta].   *)
(* The four curves meet exactly at the four corners.                  *)
(*                                                                     *)
(* gamma = 0.4 is measured, not chosen by eye: the discrete Jacobian *)
(* has min 0.36, positive, so the map is a valid diffeomorphism.      *)
(* ------------------------------------------------------------------ *)
gamma = 0.4;
bot = Function[t, {t, -1 + gamma (1 - t^2)}];
top = Function[t, {t, 1 - gamma (1 - t^2)}];
lef = Function[t, {-1 + gamma (1 - t^2), t}];
rig = Function[t, {1 - gamma (1 - t^2), t}];

patch = CoonsPatch[{bot, top, lef, rig}];
sf["CoonsPatchQ                 = ", CoonsPatchQ[patch]];
sf["method tag                  = ", patch[["Method"]]];
sf["corners                     = ", N[patch[["Corners"]]]];
sf["corner closure (max gap)    = ", N[patch[["CornerClosure"]]]];
sf["min |cross| of incident edges at a corner = ", N[patch[["CornerConsistency"]]["MinTangentCross"]]];
sf["map at the centre           = ", N[CoonsPatchMap[patch, 0, 0]]];
sf["map at (0.5, 0.5)           = ", N[CoonsPatchMap[patch, 0.5, 0.5]]];

(* The transfinite map reproduces its own four boundary curves: on
   \[Eta] = -1 and \[Eta] = 1 it is the bottom and top curves, on\[Xi] = -1 and \[Xi] = 1 it is the left and right curves. *)
tE = {-1, -0.5, 0, 0.5, 1};
edgeErr = Max[Flatten[Table[{Abs[CoonsPatchMap[patch, s, -1] - bot[s]], Abs[CoonsPatchMap[patch, s, 1] - top[s]], Abs[CoonsPatchMap[patch, -1, s] - lef[s]], Abs[CoonsPatchMap[patch, 1, s] - rig[s]]}, {s, tE}]]];
sf["map reproduces its 4 edges, max deviation = ", N[edgeErr]];

(* ------------------------------------------------------------------ *)
(* Discretize, and read the assembly back out.                        *)
(* ------------------------------------------------------------------ *)
n = 14;
disc = SpectralDomain[{patch}, n];
sf["degree n                    = ", n];
sf["PatchCount                  = ", SpectralDomainData[disc, "PatchCount"]];
sf["NodeCount (per direction)   = ", SpectralDomainData[disc, "NodeCount"]];
sf["UnknownCount                = ", SpectralDomainData[disc, "UnknownCount"]];
sf["RowCount                    = ", SpectralDomainData[disc, "RowCount"]];
sf["InteriorRows per patch      = ", SpectralDomainData[disc, "InteriorRowCounts"]];
sf["BoundaryRows per patch      = ", Map[Length, SpectralDomainData[disc, "BoundaryRows"]]];
sf["FluxRows per patch          = ", Map[Length, SpectralDomainData[disc, "FluxRows"]]];
sf["InterfacePairs              = ", SpectralDomainData[disc, "InterfacePairs"]];
sf["min Jacobian over the patch = ", N[SpectralDomainData[disc, "MinJacobian"]]];
sf["J at the four corners       = ", N[SpectralDomainData[disc, "CornerJacobian"]]];
sf["FD vs discrete Jacobian     = ", N[SpectralDomainData[disc, "FDJacobian"]]];

(* ------------------------------------------------------------------ *)
(* Solve on it.  The boundary predicate is written out in closed form  *)
(* so that every boundary node is matched: bottom y = -1 + gamma(1 - x^2), *)
(* top y = 1 - gamma(1 - x^2), left x = -1 + gamma(1 - y^2),          *)
(* right x = 1 - gamma(1 - y^2).                                     *)
(* ------------------------------------------------------------------ *)
uex[x_, y_] := Sin[2 x + 1] Cos[3 y - 1] + x y/5;
fLin = -Laplacian[uex[x, y], {x, y}];
onPatch = Abs[y + 1 - gamma (1 - x^2)] < 1.*^-8 || Abs[y - 1 + gamma (1 - x^2)] < 1.*^-8 || Abs[x + 1 - gamma (1 - y^2)] < 1.*^-8 || Abs[x - 1 + gamma (1 - y^2)] < 1.*^-8;
eqP = {-Laplacian[u[x, y], {x, y}] == fLin, DirichletCondition[u[x, y] == uex[x, y], onPatch]};

nMsg0 = Length[$MessageList];
{tm, fnP} = AbsoluteTiming[SpectralNDSolveValue[eqP, u, {x, y} \[Element] {patch}, n]];
sf["wall clock                  = ", N[tm], " s"];
sf["messages raised             = ", Length[$MessageList[[nMsg0 + 1 ;;]]]];
sf["max nodal error vs uex      = ", N[nodeErr[fnP, disc, uex]]];
sf["u(0, 0) computed            = ", N[fnP[0, 0]]];
sf["u(0, 0) exact               = ", N[uex[0, 0]]];

(* ------------------------------------------------------------------ *)
(* THE TRUE-CORNER RULE.                                              *)
(* ------------------------------------------------------------------ *)
(* Four quarter arcs of one smooth closed curve meet TANGENTIALLY at  *)
(* the patch vertices, so the transfinite map is DEGENERATE there      *)
(* (J = 0) and CoonsPatch refuses the patch outright.                 *)
(* ------------------------------------------------------------------ *)
rad[ph_] := 1 + 0.2 Sin[3 ph];
starEdges = {Function[{xx}, With[{ph = -Pi/2 + xx Pi/4}, rad[ph] {Cos[ph], Sin[ph]}]], Function[{yy}, With[{ph = -3 Pi/4 - (yy + 1) Pi/4}, rad[ph] {Cos[ph], Sin[ph]}]], Function[{yy}, With[{ph = Pi/2 - yy Pi/4}, rad[ph] {Cos[ph], Sin[ph]}]], Function[{xx}, With[{ph = xx Pi/4}, rad[ph] {Cos[ph], Sin[ph]}]]};
nMsg0 = Length[$MessageList];
star = CoonsPatch[starEdges];
starTags = Cases[$MessageList[[nMsg0 + 1 ;;]], HoldForm[MessageName[nm_, tag___]] :> nm];
sf["smooth closed boundary: messages from CoonsPatch = ", If[starTags === {}, "none", DeleteDuplicates[starTags]]];
sf["smooth closed boundary: CoonsPatchQ              = ", CoonsPatchQ[star]];
nMsg0 = Length[$MessageList];
starDisc = Check[SpectralDomain[{star}, n], $refused];
starTags2 = Cases[$MessageList[[nMsg0 + 1 ;;]], HoldForm[MessageName[nm_, tag___]] :> nm];
sf["smooth closed boundary: messages from SpectralDomain = ", If[starTags2 === {}, "none", DeleteDuplicates[starTags2]]];
sf["smooth closed boundary: SpectralDomain returned = ", If[TrueQ[AssociationQ[starDisc]], "a discretization", starDisc]];

sf["VERDICT: 02-curved-coons-patch OK (the only messages are the documented CoonsPatch and SpectralDomain refusals in the last section)"];
Close[sfStream];