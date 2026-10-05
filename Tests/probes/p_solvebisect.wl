(* Tests/probes/p_solvebisect.wl -- DIAGNOSTIC (not a gate).

   Walk the solver's own pipeline one private step at a time, printing
   before each, so the call that never returns is named exactly.

   Run: ./rr.sh 200 Tests/probes/p_solvebisect.wl *)
$HistoryLength = 0;
PacletDirectoryLoad[FileNameJoin[{DirectoryName[DirectoryName[$InputFileName]]}]];
Check[Needs["SpectralElement`"], Null];

Print["1. region"];
linReg = Rectangle[{-1, -1}, {1, 1}];
Print["2. build the discretization"];
disc = Quiet[SpectralElement`SpectralDomain[linReg, 8]];
Print["   discQ=", Quiet[SpectralElement`SpectralDomainQ[disc]]];
Print["   unknowns=", disc["System"]["UnknownCount"], "  rows=", disc["System"]["RowCount"]];

vars = {x, y};
Print["3. equation parts"];
parts = SpectralElement`Private`seOperatorParts[Laplacian[u[x, y], {x, y}] == 0, u, vars];
Print["   opc=", parts["OperatorCoefficient"]];
Print["   rest=", parts["Rest"]];
Print["   rhs=", parts["RHS"]];
Print["   nonlinear=", parts["NonlinearQ"]];

Print["4. dirichlet conditions"];
dc = SpectralElement`Private`seDirConditions[Laplacian[u[x, y], {x, y}] == 0, u, vars];
Print["   dc=", dc];
bn = Total[Length /@ disc["System"]["BoundaryNodes"]];
Print["   boundary nodes=", bn];

Print["5. lift from the (zero) lift function"];
lf = SpectralElement`Private`seLiftFrom[disc, SpectralElement`Private`seDirLiftFn[dc, x, y]];
Print["   lift dims=", Dimensions[lf]];
Print["   lift max=", N[Max[Abs[Flatten[lf]]]]];

Print["6. stack the operator"];
A0 = SpectralElement`Private`seStackOperator[disc, parts["OperatorCoefficient"]];
Print["   A0 dims=", Dimensions[A0]];

Print["7. lift constant"];
c0 = SpectralElement`Private`seLiftConst[disc, parts["OperatorCoefficient"], lf];
Print["   c0 len=", Length[c0]];
Print["   c0 max=", N[Max[Abs[c0]]]];

Print["8. assemble the right-hand side"];
rhs = SpectralElement`Private`seAssembleRHS[disc, parts["RHS"], x, y];
Print["   rhs max=", N[Max[Abs[rhs]]]];
Print["   rhs max=", N[Max[Abs[rhs]]]];

Print["9. linear solve"];
z = SpectralElement`Private`seLinSolve[A0, rhs - c0];
Print["   z len=", Length[z]];
Print["   z max=", N[Max[Abs[z]]]];

Print["   z max=", N[Max[Abs[z]]]];
rr = SpectralElement`Private`seResidual[z, A0, c0, ConstantArray[0., Length[rhs]], rhs];
Print["   |R|=", N[SpectralElement`Private`seEmx2[rr]]];

Print["11. build the returned function"];
fn = Quiet[SpectralElement`Private`seSolutionFn[disc, z, lf], {Part::partw, Part::partd}];
Print["   FunctionQ=", FunctionQ[fn]];

Print["12. evaluate it at one point"];
Print["   fn[0.3,-0.5]=", N[fn[0.3, -0.5]]];
Print["DONE-solvebisect"];
Quit[];
