(* Tests/probes/p_lsprobe.wl -- DIAGNOSTIC (not a gate).

   Attribute the hang observed in Tests/probes/p_solvebisect.wl step 9 to an
   exact expression: is the right-hand side symbolic, or is LinearSolve
   itself stuck on a numeric system?

   Run: ./rr.sh 150 Tests/probes/p_lsprobe.wl *)
$HistoryLength = 0;
PacletDirectoryLoad[FileNameJoin[{DirectoryName[DirectoryName[$InputFileName]]}]];
Check[Needs["SpectralElement`"], Null];

disc = Quiet[SpectralElement`SpectralDomain[Rectangle[{-1, -1}, {1, 1}], 8]];
parts = SpectralElement`Private`seOperatorParts[Laplacian[u[x, y], {x, y}] == 0, u, {x, y}];
lf = SpectralElement`Private`seLiftFrom[disc, 0];
A0 = SpectralElement`Private`seStackOperator[disc, parts["OperatorCoefficient"]];
c0 = SpectralElement`Private`seLiftConst[disc, parts["OperatorCoefficient"], lf];
rhs = SpectralElement`Private`seAssembleRHS[disc, parts["RHS"], x, y];
b = rhs - c0;

Print["=== the assembled objects ==="];
Print["A0 head      = ", Head[A0]];
Print["A0 dims      = ", Dimensions[A0]];
Print["A0 numeric?  = ", VectorQ[Flatten[A0], NumericQ]];
Print["A0[1,1]      = ", N[A0[[1, 1]]], "   ", Head[N[A0[[1, 1]]]]];
Print["lift head    = ", Head[lf], "  elem head = ", Head[Flatten[lf][[1]]]];
Print["lift elem    = ", InputForm[Flatten[lf][[1]]]];
Print["c0 head      = ", Head[c0], "  len = ", Length[c0]];
Print["c0[[1]]      = ", N[c0[[1]]]];
Print["c0[[1]] in   = ", ToString[c0[[1]], InputForm]];
Print["c0 numeric?  = ", VectorQ[Flatten[c0], NumericQ]];
Print["rhs numeric? = ", VectorQ[Flatten[rhs], NumericQ]];
Print["b numeric?   = ", VectorQ[Flatten[b], NumericQ]];
Print["b[[1]] in    = ", ToString[b[[1]], InputForm]];
Print["Det-free check: row norms = ", N[Max[Abs[A0.#]]]];
Print["=== now the two LinearSolve calls ==="];
Print["--> LS-a: the assembled A0 against a plain numeric zero vector"];
zs = Quiet[Check[LinearSolve[A0, ConstantArray[0., Length[b]]], $Failed]];
Print["<-- LS-a returned ", Head[zs], "  len=", Length[zs]];
Print["--> LS-b: A0 against the solver's own rhs minus c0"];
zz = Quiet[Check[LinearSolve[A0, b], $Failed]];
Print["<-- LS-b returned ", Head[zz], "  len=", Length[zz]];
Print["DONE-lsprobe"];
Quit[];
