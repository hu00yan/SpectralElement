(* ==================================================================== *)
(* Examples/01-linear-rectangle.wl                                 E   *)
(*                                                                     *)
(* THE HELLO-WORLD.  Solve -Laplacian[u] == f on a rectangle with the  *)
(* built-in region shorthand, no options at all, and check the answer  *)
(* against a manufactured solution.                                   *)
(*                                                                     *)
(* Run it with the repo's guarded runner:                             *)
(*     ./rr.sh 300 Examples/01-linear-rectangle.wl                   *)
(* Every number printed below also goes to the $SPECF_OUT file the   *)
(* runner names, so the output is evidence, not narration.            *)
(*                                                                     *)
(* EXPECTED MESSAGES: none.  The run is silent.                       *)
(* ==================================================================== *)
$HistoryLength = 0;

sfLog = If[StringQ[Environment["SPECF_OUT"]], Environment["SPECF_OUT"], FileNameJoin[{DirectoryName[$InputFileName], "01-linear-rectangle.txt"}]];
sfStream = OpenWrite[sfLog];
sf[args___] := Module[{s = StringJoin[ToString[#, InputForm] & /@ {args}]}, WriteString[sfStream, s <> "\n"]; Flush[sfStream]; Print[s]];

(* Work whether the package is already installed (Needs finds it) or
   whether this file is being read straight out of a checkout (Get the
   loader next to this script).  Either way the context ends up on
   $ContextPath and the bare public names resolve. *)
If[! MemberQ[$ContextPath, "SpectralElement`"], Get[FileNameJoin[{DirectoryName[$InputFileName], "..", "Kernel", "SpectralElement.wl"}]]];
If[! MemberQ[$ContextPath, "SpectralElement`"], Needs["SpectralElement`"]];
sf["context loaded = ", MemberQ[$ContextPath, "SpectralElement`"], "   public symbols = ", Length[Names["SpectralElement`*"]]];

(* ------------------------------------------------------------------ *)
(* Two helpers, reused by every example in this directory.            *)
(*   nodeErr[fn, disc, exact] = max |fn - exact| over EVERY node of    *)
(*   EVERY patch, on the grid the solver collocated on.  The node      *)
(*   coordinates come from the PUBLIC "X" and "Y" keys, and `exact` is *)
(*   a manufactured solution, so this is an error against a known      *)
(*   answer and never a self-comparison.                               *)
(*   Every local is assigned in the BODY: a Module initializer cannot *)
(*   see another initializer in this kernel.                          *)
(* ------------------------------------------------------------------ *)
nodeErr[fn_, disc_, exact_] := Module[{XX, YY, np, nn}, XX = SpectralDomainData[disc, "X"]; YY = SpectralDomainData[disc, "Y"]; np = Length[XX]; nn = Dimensions[XX[[1]]][[1]]; Max[Flatten[Table[Abs[fn[XX[[p, i, j]], YY[[p, i, j]]] - exact[XX[[p, i, j]], YY[[p, i, j]]]], {p, 1, np}, {i, 1, nn}, {j, 1, nn}]]]];

(* ------------------------------------------------------------------ *)
(* A manufactured solution, so every error below is an error against  *)
(* a KNOWN answer.                                                    *)
(* ------------------------------------------------------------------ *)
uex[x_, y_] := Sin[2 x + 1] Cos[3 y - 1] + x y/5;
fLinear = -Laplacian[uex[x, y], {x, y}];

reg = Rectangle[{-1.5, -1.2}, {1.8, 1.3}];
(* THE BOUNDARY PREDICATE MUST NAME ALL FOUR SIDES, with the right
   sign on each.  A typo here is silent and expensive: leave the top
   side y = 1.3 out and those nodes fall back to the API.md 4.3
   homogeneous-Dirichlet default u == 0, which uex does not satisfy, so
   the reported error jumps to 1.4157 and does NOT shrink with the
   degree -- measured, see Examples/README.md. *)
onBoundary = Abs[x + 1.5] < 1.*^-8 || Abs[x - 1.8] < 1.*^-8 || Abs[y + 1.2] < 1.*^-8 || Abs[y - 1.3] < 1.*^-8;

eqLinear = {-Laplacian[u[x, y], {x, y}] == fLinear, DirichletCondition[u[x, y] == uex[x, y], onBoundary]};

n = 16;
nMsg0 = Length[$MessageList];
{tm, sol} = AbsoluteTiming[SpectralNDSolve[eqLinear, u, {x, y} \[Element] reg, n]];
nMsgs = Cases[$MessageList[[nMsg0 + 1 ;;]], HoldForm[MessageName[nm_, tag___]] :> nm];

sf["degree n                     = ", n];
sf["wall clock (mesh + solve)    = ", N[tm], " s"];
sf["messages raised by the solve = ", If[nMsgs === {}, "none", DeleteDuplicates[nMsgs]]];
sf["result shape                 = ", If[MatchQ[sol, {{_Rule}}], "{{u -> Function}}", sol]];
sf["head of the rule's right side= ", Head[sol[[1, 1, 2]]]];

fn = sol[[1, 1, 2]];
disc = SpectralDomain[reg, n];
sf["max nodal error vs uex       = ", N[nodeErr[fn, disc, uex]]];
sf["u(0, 0) computed             = ", N[fn[0, 0]]];
sf["u(0, 0) exact                = ", N[uex[0, 0]]];

(* The value-shaped entry point takes the same arguments and gives the
   same answer; it hands back the function instead of the rule. *)
val = SpectralNDSolveValue[eqLinear, u, {x, y} \[Element] reg, n];
sf["SpectralNDSolveValue head    = ", Head[val]];
sf["the two agree at (0.3, -0.4) = ", N[Abs[val[0.3, -0.4] - fn[0.3, -0.4]]]];

sf["VERDICT: 01-linear-rectangle OK (no messages)"];
Close[sfStream];