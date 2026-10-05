(* D2 P0 isolation, final form.

   ONE run produces BOTH the BEFORE and the AFTER numbers: the old (defective)
   row->node decode and the new one are computed side by side here, so the
   comparison is reproducible and does not depend on a reverted source tree.

     OLD decode (the wave-2 defect):  node = xi-fast decode of the ROW
       POSITION j.  Rows holds flat node indices separated by a full stride
       nn, so position j and rows[[j]] disagree from the second line on.
     NEW decode (the fix, Solve.wl seRowFvec / seRowTermVec):
       node = xi-fast decode of rows[[j]].

   TRAP 1: a context SHORTHAND does not work.  PR = SpectralElement`Private
   parses as a PRODUCT, and the Private context is NOT on $ContextPath, so
   every Private call must be written out in full.
   TRAP 2: inside Do[...] a TRAILING COMMA ends the BODY and starts a new
   ARGUMENT.  Body statements are separated by ";"; only the last one
   carries the comma that introduces the iterator. *)
$HistoryLength = 0;
p[args___] := Print[Row[{args}]];
Get["/Users/huyan00/mycode/SpectralElement/Kernel/SpectralElement.wl"];
uexz[x_, y_] := Sin[2 x + 1] Cos[3 y - 1] + x y/5;
bdR = Abs[x + 1.5] < 1.*^-8 || Abs[x - 1.8] < 1.*^-8 || Abs[y + 1.2] < 1.*^-8 || Abs[y - 1.3] < 1.*^-8;
regR = Rectangle[{-1.5, -1.2}, {1.8, 1.3}];
fexpr = -Laplacian[uexz[x, y], {x, y}];
fnum[xx_, yy_] := fexpr /. {x -> xx, y -> yy};
eq = {-Laplacian[u[x, y], {x, y}] == fexpr, DirichletCondition[u[x, y] == uexz[x, y], bdR]};
p["needed Private names present: ", Sort[Select[Names["SpectralElement`Private`se*"], MemberQ[{"seExactGlobal", "seStackOperator", "seLiftConst", "seAssembleRHS", "seRowFvec", "seFvec", "seLinSolve", "seGather", "seNodeVec", "seLiftFrom"}]]]];
p["deg |  a_old     c_old     e_old     |  a_new     c_new     b_new     d  |e_new      retErr"];
Do[
  disc = Quiet[SpectralElement`SpectralDomain[regR, n]];
  s = disc["System"];
  ops = disc["PatchOps"];
  np = Length[ops];
  nn = disc["NodeCount"];
  zex = SpectralElement`Private`seExactGlobal[disc, uexz];
  lf = SpectralElement`Private`seLiftFrom[disc, uexz];
  A0 = SpectralElement`Private`seStackOperator[disc, -1.];
  c0 = SpectralElement`Private`seLiftConst[disc, -1., lf];
  rhsNew = SpectralElement`Private`seAssembleRHS[disc, fexpr, x, y];
  rws = s["PDE"][[1]]["Rows"];
  nr = Length[rws];
  rhsOld = Table[Module[{jj, ii}, jj = Mod[k - 1, nn] + 1; ii = Quotient[k - 1, nn] + 1; N[fnum[ops[[1]]["Xs"][[jj, ii]], ops[[1]]["Ys"][[jj, ii]]]]], {k, 1, nr}];
  gtab = SpectralElement`Private`seNodeVec[Table[N[uexz[ops[[1]]["Xs"][[ix, iy]], ops[[1]]["Ys"][[ix, iy]]]], {ix, 1, nn}, {iy, 1, nn}]];
  tgt = -((ops[[1]]["Lop"].gtab)[[rws]]);
  bNew = N[Max[Abs[Flatten[A0[[1 ;; nr]].zex + c0[[1 ;; nr]] - tgt]]]];
  cNew = N[Max[Abs[Flatten[rhsNew[[1 ;; nr]] - tgt]]]];
  aNew = N[Max[Abs[Flatten[A0.zex + c0 - rhsNew]]]];
  cOld = N[Max[Abs[Flatten[rhsOld - tgt]]]];
  aOld = N[Max[Abs[Flatten[A0.zex + c0 - Join[rhsOld, ConstantArray[0., s["RowCount"] - nr]]]]]];
  dNum = Length[rws] - s["RowSlices"][[1]]["Count"];
  zOld = SpectralElement`Private`seLinSolve[A0, Join[rhsOld, ConstantArray[0., s["RowCount"] - nr]] - c0];
  zNew = SpectralElement`Private`seLinSolve[A0, rhsNew - c0];
  uOld = SpectralElement`Private`seGather[disc, lf, zOld][[1]];
  uNew = SpectralElement`Private`seGather[disc, lf, zNew][[1]];
  eOld = N[Max[Abs[Flatten[uOld - gtab]]]];
  eNew = N[Max[Abs[Flatten[uNew - gtab]]]];
  refv = N[Max[Abs[Flatten[SpectralElement`Private`seRowFvec[disc, 1, fnum] - SpectralElement`Private`seFvec[disc, 1, fnum]]]]];
  fnv = Quiet[Check[SpectralElement`SpectralNDSolveValue[eq, u, {x, y} \[Element] regR, n], $Failed]];
  retErr = 1.*^30;
  If[TrueQ[AssociationQ[SpectralElement`Private`seLastSolve] && TrueQ[Lookup[SpectralElement`Private`seLastSolve, "Ok"] === True]], fnv = Lookup[SpectralElement`Private`seLastSolve, "Function"]; retErr = N[Max[Abs[Table[N[fnv[ops[[1]]["Xs"][[ix, iy]], ops[[1]]["Ys"][[ix, iy]]]] - gtab[[ix + nn (iy - 1)]], {ix, 1, nn}, {iy, 1, nn}]]]]];
  p["n=", n, " | ", aOld, " ", cOld, " ", eOld, " | ", aNew, " ", cNew, " ", bNew, " ", dNum, " | ", eNew, " ", retErr, "   |seRowFvec-seFvec|=", refv],
  {n, 6, 16, 2}];
p["DONE-d2_isolate"];
