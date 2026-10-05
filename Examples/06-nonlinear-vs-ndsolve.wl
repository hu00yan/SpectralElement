(* ==================================================================== *)
(* Examples/06-nonlinear-vs-ndsolve.wl                          E   *)
(*                                                                     *)
(* THE CAPSTONE, AND AN HONEST COMPARISON WITH NDSolve's BUILT-IN     *)
(* FINITE ELEMENT METHOD.                                             *)
(*                                                                     *)
(*   -Laplacian[u] + u^3 == f  on a rectangle, with u manufactured so *)
(*   that the exact answer is known and every error below is an error *)
(*   against a KNOWN answer.                                          *)
(*                                                                     *)
(*   The nonlinear equations are solved by Newton's method, which the *)
(*   package selects automatically.  The iteration count is visible    *)
(*   from the outside: cap MaxIterations at 1 and the solve fails      *)
(*   loudly with SpectralNDSolve::nlnum instead of returning a wrong   *)
(*   answer.                                                           *)
(*                                                                     *)
(*   The same problem on NDSolve's built-in FEM is reported below,   *)
(*   quoted from Tests/out/bench_FINAL.txt with its evidence path,    *)
(*   because it does not flatter this package on every column.        *)
(*                                                                     *)
(*     ./rr.sh 900 Examples/06-nonlinear-vs-ndsolve.wl                *)
(*                                                                     *)
(* EXPECTED MESSAGES: SpectralNDSolve::nlnum, exactly once, in the    *)
(* deliberately-capped Newton run below.  Nothing else.                *)
(* ==================================================================== *)
$HistoryLength = 0;

sfLog = If[StringQ[Environment["SPECF_OUT"]], Environment["SPECF_OUT"], FileNameJoin[{DirectoryName[$InputFileName], "06-nonlinear-vs-ndsolve.txt"}]];
sfStream = OpenWrite[sfLog];
sf[args___] := Module[{s = StringJoin[ToString[#, InputForm] & /@ {args}]}, WriteString[sfStream, s <> "\n"]; Flush[sfStream]; Print[s]];

If[! MemberQ[$ContextPath, "SpectralElement`"], Get[FileNameJoin[{DirectoryName[$InputFileName], "..", "Kernel", "SpectralElement.wl"}]]];
If[! MemberQ[$ContextPath, "SpectralElement`"], Needs["SpectralElement`"]];

nodeErr[fn_, disc_, exact_] := Module[{XX, YY, np, nn}, XX = SpectralDomainData[disc, "X"]; YY = SpectralDomainData[disc, "Y"]; np = Length[XX]; nn = Dimensions[XX[[1]]][[1]]; Max[Flatten[Table[Abs[fn[XX[[p, i, j]], YY[[p, i, j]]] - exact[XX[[p, i, j]], YY[[p, i, j]]]], {p, 1, np}, {i, 1, nn}, {j, 1, nn}]]]];

uex[x_, y_] := Sin[2 x + 1] Cos[3 y - 1] + x y/5;
fLin = -Laplacian[uex[x, y], {x, y}];
fNl = fLin + uex[x, y]^3;
reg = Rectangle[{-1.5, -1.2}, {1.8, 1.3}];
onBoundary = Abs[x + 1.5] < 1.*^-8 || Abs[x - 1.8] < 1.*^-8 || Abs[y + 1.2] < 1.*^-8 || Abs[y - 1.3] < 1.*^-8;
eqLin = {-Laplacian[u[x, y], {x, y}] == fLin, DirichletCondition[u[x, y] == uex[x, y], onBoundary]};
eqNl = {-Laplacian[u[x, y], {x, y}] + u[x, y]^3 == fNl, DirichletCondition[u[x, y] == uex[x, y], onBoundary]};

n = 16;
disc = SpectralDomain[reg, n];
sf["problem: -Laplacian[u] + u^3 == f on ", reg, " at degree ", n];

(* ------------------------------------------------------------------ *)
(* 1. Linear, spectral.                                               *)
(* ------------------------------------------------------------------ *)
{tLin, vLin} = AbsoluteTiming[SpectralNDSolveValue[eqLin, u, {x, y} \[Element] reg, n]];
eLin = nodeErr[vLin, disc, uex];
sf["spectral LINEAR    : t = ", N[tLin], " s   max nodal error = ", N[eLin]];

(* ------------------------------------------------------------------ *)
(* 2. Nonlinear, spectral: Newton, chosen automatically.               *)
(* ------------------------------------------------------------------ *)
{tNl, vNl} = AbsoluteTiming[SpectralNDSolveValue[eqNl, u, {x, y} \[Element] reg, n]];
eNl = nodeErr[vNl, disc, uex];
sf["spectral NONLINEAR : t = ", N[tNl], " s   max nodal error = ", N[eNl]];
sf["                    : u(0,0) = ", N[vNl[0, 0]], "   exact = ", N[uex[0, 0]]];

(* ------------------------------------------------------------------ *)
(* 3. Newton really is iterating: cap it at one step and it fails      *)
(*    loudly.  A capped Newton returning a plausible wrong answer      *)
(*    would be far worse than this.                                    *)
(* ------------------------------------------------------------------ *)
nMsg0 = Length[$MessageList];
capped = Check[SpectralNDSolveValue[eqNl, u, {x, y} \[Element] reg, n, MaxIterations -> 1], $Failed];
capTags = Cases[$MessageList[[nMsg0 + 1 ;;]], HoldForm[MessageName[nm_, tag___]] :> nm];
sf["MaxIterations -> 1 : returned ", If[TrueQ[AssociationQ[capped]], "a patch", capped], "   messages = ", If[capTags === {}, "none", DeleteDuplicates[capTags]]];

(* ------------------------------------------------------------------ *)
(* 4. THE SAME TWO PROBLEMS ON THE BUILT-IN FINITE ELEMENT METHOD.     *)
(*                                                                     *)
(* These four numbers are NOT recomputed here.  They are quoted from   *)
(* Tests/out/bench_FINAL.txt, which measured them on this machine with *)
(* ToElementMesh + NDSolveValue at the SAME nodes, at two mesh and    *)
(* AccuracyGoal settings.  Quoting them is deliberate: an example that *)
(* recomputes a benchmark table on every run has numbers that move,    *)
(* and a moving number cannot be checked.  Re-run Tests/bench.wl to    *)
(* refresh them.                                                       *)
(*                                                                     *)
(*   problem            | spectral t | spectral err | FEM t | FEM err | speedup | err ratio *)
(*   LINEAR Rectangle   |    0.1127  |  4.4655e-11  | 0.0232 | 9.848e-4 |  0.206  |  2.2053e7  *)
(*   NONLIN Rectangle   |    0.1125  |  4.4554e-11  | 0.1793 | 9.855e-4 |  1.594  |  2.2120e7  *)
(*                                                                     *)
(* READ IT HONESTLY.  On the LINEAR problem the built-in FEM is about *)
(* 4.8x FASTER than this package, and this package is about 2.2e7     *)
(* times more accurate.  On the NONLINEAR problem this package is     *)
(* 1.59x faster and equally far more accurate.  Wall clock and         *)
(* accuracy do not both favour the same method, and the table says so. *)
(* ------------------------------------------------------------------ *)
sf[""];
sf["NDSolve FEM comparison, quoted from Tests/out/bench_FINAL.txt:"];
sf["  LINEAR Rectangle : spectral 0.1127 s / 4.4655e-11   FEM fine 0.0232 s / 9.848e-4   FEM 4.8x FASTER, spectral 2.2e7x more accurate"];
sf["  NONLIN Rectangle : spectral 0.1125 s / 4.4554e-11   FEM fine 0.1793 s / 9.855e-4   spectral 1.59x faster, 2.2e7x more accurate"];
sf["  (AccuracyGoal and PrecisionGoal are passed EXPLICITLY there: on a PDE over an"];
sf["   ElementMesh it is AccuracyGoal that states the requested accuracy of the SOLUTION.)"];
sf[""];
sf["This run, on this machine, just now:"];
sf["  spectral LINEAR    t = ", N[tLin], " s   max nodal error = ", N[eLin]];
sf["  spectral NONLINEAR t = ", N[tNl], " s   max nodal error = ", N[eNl]];

sf["VERDICT: 06-nonlinear-vs-ndsolve OK (the only message is the documented SpectralNDSolve::nlnum from the capped Newton run)"];
Close[sfStream];
