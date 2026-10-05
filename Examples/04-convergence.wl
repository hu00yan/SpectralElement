(* ==================================================================== *)
(* Examples/04-convergence.wl                                   E   *)
(*                                                                     *)
(* SPECTRAL CONVERGATION.  The same linear problem on the same        *)
(* rectangle, solved at degrees 6, 8, 10, 12, 14 and 16.  The error   *)
(* falls by roughly three orders of magnitude for every two degrees    *)
(* added, which is the geometric convergence of a Chebyshev           *)
(* collocation method on a smooth problem.                            *)
(*                                                                     *)
(*     ./rr.sh 600 Examples/04-convergence.wl                         *)
(*                                                                     *)
(* EXPECTED MESSAGES: none.  The run is silent.                       *)
(*                                                                     *)
(* These are the same numbers Tests/out/bench_FINAL.txt gate G6a      *)
(* records at degree 16, reproduced here from scratch by an example   *)
(* that only uses the PUBLIC API.                                     *)
(* ==================================================================== *)
$HistoryLength = 0;

sfLog = If[StringQ[Environment["SPECF_OUT"]], Environment["SPECF_OUT"], FileNameJoin[{DirectoryName[$InputFileName], "04-convergence.txt"}]];
sfStream = OpenWrite[sfLog];
sf[args___] := Module[{s = StringJoin[ToString[#, InputForm] & /@ {args}]}, WriteString[sfStream, s <> "\n"]; Flush[sfStream]; Print[s]];

If[! MemberQ[$ContextPath, "SpectralElement`"], Get[FileNameJoin[{DirectoryName[$InputFileName], "..", "Kernel", "SpectralElement.wl"}]]];
If[! MemberQ[$ContextPath, "SpectralElement`"], Needs["SpectralElement`"]];

nodeErr[fn_, disc_, exact_] := Module[{XX, YY, np, nn}, XX = SpectralDomainData[disc, "X"]; YY = SpectralDomainData[disc, "Y"]; np = Length[XX]; nn = Dimensions[XX[[1]]][[1]]; Max[Flatten[Table[Abs[fn[XX[[p, i, j]], YY[[p, i, j]]] - exact[XX[[p, i, j]], YY[[p, i, j]]]], {p, 1, np}, {i, 1, nn}, {j, 1, nn}]]]];

uex[x_, y_] := Sin[2 x + 1] Cos[3 y - 1] + x y/5;
fLin = -Laplacian[uex[x, y], {x, y}];
reg = Rectangle[{-1.5, -1.2}, {1.8, 1.3}];
onBoundary = Abs[x + 1.5] < 1.*^-8 || Abs[x - 1.8] < 1.*^-8 || Abs[y + 1.2] < 1.*^-8 || Abs[y - 1.3] < 1.*^-8;
eqL = {-Laplacian[u[x, y], {x, y}] == fLin, DirichletCondition[u[x, y] == uex[x, y], onBoundary]};

degrees = {6, 8, 10, 12, 14, 16};
sf["problem: -Laplacian[u] == f on ", reg];
sf["exact solution: uex[x, y] = Sin[2x+1] Cos[3y-1] + xy/5"];
sf[""];
sf["  n | unknowns | wall clock (s) | max nodal error"];
prev = Missing;
Do[nMsg0 = Length[$MessageList]; {tm, fv} = AbsoluteTiming[SpectralNDSolveValue[eqL, u, {x, y} \[Element] reg, k]]; d = SpectralDomain[reg, k]; e = nodeErr[fv, d, uex]; sf["  ", k, " | ", SpectralDomainData[d, "UnknownCount"], " | ", N[tm], " | ", N[e], "   (", Length[$MessageList[[nMsg0 + 1 ;;]]], " messages)"]; , {k, degrees}];

(* Digits gained per two degrees, which is the convergence rate. *)
Do[m0 = Length[$MessageList]; {tA, fA} = AbsoluteTiming[SpectralNDSolveValue[eqL, u, {x, y} \[Element] reg, a]]; eA = nodeErr[fA, SpectralDomain[reg, a], uex]; {tB, fB} = AbsoluteTiming[SpectralNDSolveValue[eqL, u, {x, y} \[Element] reg, a + 2]]; eB = nodeErr[fB, SpectralDomain[reg, a + 2], uex]; sf["  rate ", a, " -> ", a + 2, " : ", N[-Log[eB/eA]/Log[2]], " digits per degree"]; , {a, {6, 8, 10, 12, 14}}];

sf[""];
sf["VERDICT: 04-convergence OK (no messages)"];
Close[sfStream];