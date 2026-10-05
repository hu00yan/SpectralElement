(* D2 P2: instrumented Newton ladder.

   Times every Newton phase separately (residual assembly / Jacobian /
   LinearSolve / update) so a stall localises to a PHASE and a LINE, and
   dumps the shape of the residual and the Jacobian so a symbolic leak is
   visible.  ctx is assembled here with the same Private helpers seSolveCore
   uses, so the timing survives a solve that ends in ::nsolve. *)
$HistoryLength = 0;
p[args___] := Print[Row[{args}]];
Get["/path/to/SpectralElement/Kernel/SpectralElement.wl"];
uexz[x_, y_] := Sin[2 x + 1] Cos[3 y - 1] + x y/5;
bdR = Abs[x + 1.5] < 1.*^-8 || Abs[x - 1.8] < 1.*^-8 || Abs[y + 1.2] < 1.*^-8 || Abs[y - 1.3] < 1.*^-8;
regR = Rectangle[{-1.5, -1.2}, {1.8, 1.3}];
fexpr = -Laplacian[uexz[x, y], {x, y}] + uexz[x, y]^3;
eqn = {-Laplacian[u[x, y], {x, y}] + u[x, y]^3 == fexpr, DirichletCondition[u[x, y] == uexz[x, y], bdR]};
p["=== P2 nonlinear ladder: -Lap[u] + u^3 == f, Rectangle, MaxIterations -> 8 ==="];
Do[
  tD = AbsoluteTiming[disc = Quiet[SpectralElement`SpectralDomain[regR, n]]];
  tP = AbsoluteTiming[parts = SpectralElement`Private`seOperatorParts[eqn, u, {x, y}]];
  dc = SpectralElement`Private`seDirConditions[eqn, u, {x, y}];
  ctx = <|"OperatorCoefficient" -> parts["OperatorCoefficient"], "Rest" -> parts["Rest"], "RHS" -> parts["RHS"], "RestDerivative" -> parts["RestDerivative"], "NonlinearQ" -> parts["NonlinearQ"], "vars" -> {x, y}, "u" -> u, "Lift" -> SpectralElement`Private`seLiftFrom[disc, SpectralElement`Private`seDirLiftFn[dc, x, y]]|>;
  tA = AbsoluteTiming[A0 = SpectralElement`Private`seStackOperator[disc, ctx["OperatorCoefficient"]]];
  tC = AbsoluteTiming[c0 = SpectralElement`Private`seLiftConst[disc, ctx["OperatorCoefficient"], ctx["Lift"]]];
  tR = AbsoluteTiming[rhs = SpectralElement`Private`seAssembleRHS[disc, ctx["RHS"], x, y]];
  nTot = Lookup[disc, "System"]["UnknownCount"];
  nRow = Lookup[disc, "System"]["RowCount"];
  p["--- n=", n, "  nn=", Lookup[disc, "NodeCount"], " nRow=", nRow, " nTot=", nTot, " NonlinearQ=", ctx["NonlinearQ"], " Rest=", ctx["Rest"], " dRest=", ctx["RestDerivative"], " opc=", ctx["OperatorCoefficient"]];
  p["    setup s:  domain=", N[tD[[1]], 4], " parts=", N[tP[[1]], 4], " stack=", N[tA[[1]], 4], " liftconst=", N[tC[[1]], 4], " rhs=", N[tR[[1]], 4]];
  t0 = AbsoluteTiming[sol = SpectralElement`SpectralNDSolve[eqn, u, {x, y} \[Element] regR, n, Method -> "Newton", MaxIterations -> 8]];
  info = SpectralElement`Private`seLastSolve;
  p["    PUBLIC solve wall = ", N[t0[[1]], 4], " s  Ok=", Lookup[info, "Ok"], " Converged=", Lookup[info, "Converged"], " Iterations=", Lookup[info, "Iterations"], " FinalResidual=", Lookup[info, "FinalResidual"]];
  p["    dels = ", N[Lookup[info, "Dels"]]];
  z = ConstantArray[0., nTot];
  Do[
    ta = AbsoluteTiming[R = SpectralElement`Private`seResidual[z, A0, c0, SpectralElement`Private`seNLVec[disc, z, ctx, ctx["Lift"]], rhs]];
    tb = AbsoluteTiming[J = SpectralElement`Private`seJacobian[z, A0, SpectralElement`Private`seD1Vec[disc, z, ctx, ctx["Lift"]], nRow, nTot]];
    tc = AbsoluteTiming[dz = SpectralElement`Private`seLinSolve[J, -R]];
    td = AbsoluteTiming[z = z + dz];
    p["      step ", it, " asm=", N[ta[[1]], 4], "s jac=", N[tb[[1]], 4], "s lsolve=", N[tc[[1]], 4], "s upd=", N[td[[1]], 4], "s |R|=", SpectralElement`Private`seEmx2[R], " |dz|=", SpectralElement`Private`seEmx2[dz], " RvecQ=", TrueQ[VectorQ[Flatten[R], NumericQ]], " LeafCount(R)=", LeafCount[R]],
    {it, 1, 8}],
  {n, 4, 10, 2}];
p["DONE-d2_newton"];
