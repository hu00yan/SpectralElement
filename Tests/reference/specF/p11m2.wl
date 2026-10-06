(* p11m2 -- diagnose p11m A-section failure:
   (1) emx needs FLAT vectors -- fix call sites, recheck boundary repro
       and annulus metric (these were false negatives);
   (2) split the curvedLap=22512 failure: run the SAME operator machinery
       on R==1 (square->disk transfinite map, cannot fold).  If that passes
       the operator is right and the star fold (minJ<0) is the culprit;
   (3) scan amplitude of R = 1 + amp Sin[3 phi] (and a 2-fold variant)
       for minJ>0; locate the worst node. *)
$HistoryLength = 0;
Get[FileNameJoin[{Directory[], "helpers.wl"}]];
tst[e_] := StringTake[ToString[e, InputForm],
   Min[300, StringLength[ToString[e, InputForm]]]];
emx[v_] := If[VectorQ[v, NumericQ], N[Max[Abs[v]]], -1.];
ef[m_] := emx[Flatten[m]];
cgl[a_, b_, nn_] := Table[(a + b)/2 - (b - a)/2 Cos[k Pi/(nn - 1)],
   {k, 0, nn - 1}];
chebD1[xx_] := Module[{nn = Length[xx], cc, sg, aa, bb, d, ii},
   cc = Table[If[i == 1 || i == nn, 2., 1.], {i, nn}];
   sg = (-1.)^Range[0, nn - 1];
   aa = sg cc; bb = sg/cc;
   d = Outer[Times, aa, bb]/(Outer[Subtract, xx, xx] + IdentityMatrix[nn])
      - IdentityMatrix[nn];
   ii = -Map[Total, d];
   d + DiagonalMatrix[ii]];
nodeVec[m_] := Flatten[Transpose[m]];

uex[x_, y_] := Sin[2 x + 1] Cos[3 y - 1] + x y/5;
flin = Simplify[-Laplacian[uex[x, y], {x, y}]];

(* --- map builder parameterized by radius law rad[ph] --- *)
mkMap[rad_] := Module[{c1, c2, c3, c4, V1, V2, V3, V4, sm},
   c1[xx_] := With[{ph = -Pi/2 + xx Pi/4}, rad[ph] {Cos[ph], Sin[ph]}];
   c2[xx_] := With[{ph = Pi/2 - xx Pi/4}, rad[ph] {Cos[ph], Sin[ph]}];
   c3[yy_] := With[{ph = -3 Pi/4 - (yy + 1) Pi/4}, rad[ph] {Cos[ph], Sin[ph]}];
   c4[yy_] := With[{ph = yy Pi/4}, rad[ph] {Cos[ph], Sin[ph]}];
   V1 = c1[-1]; V2 = c1[1]; V3 = c2[-1]; V4 = c2[1];
   sm[xx_, yy_] := Module[{a0 = (1 - xx)/2, a1 = (1 + xx)/2,
       b0 = (1 - yy)/2, b1 = (1 + yy)/2},
      b0 c1[xx] + b1 c2[xx] + a0 c3[yy] + a1 c4[yy]
       - (a0 b0 V1 + a1 b0 V2 + a0 b1 V3 + a1 b1 V4)];
   sm];

(* --- operator + checks for one map --- *)
testMap[sm_, nN_] := Module[{nn, xg, yg, Xs, Ys, Dm, D2m, xxi, xe, yxi, ye,
    Jm, al, be, ga, de, AA, BB, CCc, d10, d01, vv, Id, Lop, Um, fm, intR,
    resOp, pv, pos, ebc},
  nn = nN + 1;
  xg = cgl[-1., 1., nn]; yg = cgl[-1., 1., nn];
  Xs = Table[sm[a, b][[1]], {a, xg}, {b, yg}];
  Ys = Table[sm[a, b][[2]], {a, xg}, {b, yg}];
  Dm = chebD1[xg]; D2m = Dm.Dm;
  xxi = Dm.Xs; xe = Xs.Transpose[Dm]; yxi = Dm.Ys; ye = Ys.Transpose[Dm];
  Jm = xxi*ye - xe*yxi;
  pv = Flatten[Transpose[Jm]];
  pos = Ordering[pv, 1][[1]];
  al = ye/Jm; be = -yxi/Jm; ga = -xe/Jm; de = xxi/Jm;
  AA = al^2 + ga^2; BB = 2 (al be + ga de); CCc = be^2 + de^2;
  d10 = al*(Dm.al) + be*(Dm.be) + ga*(Dm.ga) + de*(Dm.de);
  d01 = al*(al.Transpose[Dm]) + be*(be.Transpose[Dm])
      + ga*(ga.Transpose[Dm]) + de*(de.Transpose[Dm]);
  vv[v_] := SparseArray[Band[{1, 1}] -> nodeVec[v]];
  Id = SparseArray[IdentityMatrix[nn]];
  Lop = vv[AA].KroneckerProduct[Id, SparseArray[D2m]]
      + vv[BB].KroneckerProduct[SparseArray[Dm], SparseArray[Dm]]
      + vv[CCc].KroneckerProduct[SparseArray[D2m], Id]
      + vv[d10].KroneckerProduct[Id, SparseArray[Dm]]
      + vv[d01].KroneckerProduct[SparseArray[Dm], Id];
  Um = Table[uex[Xs[[i, j]], Ys[[i, j]]], {i, nn}, {j, nn}];
  fm = Table[flin /. {x -> Xs[[i, j]], y -> Ys[[i, j]]}, {i, nn}, {j, nn}];
  intR = Flatten[Table[1 + ix + nn iy, {iy, 1, nN - 1}, {ix, 1, nN - 1}]];
  resOp = (Lop.nodeVec[Um])[[intR]] - nodeVec[fm][[intR]];
  {Min[pv], Count[pv, _?(# <= 0 &)], Max[pv], ef[resOp],
   tst[Mod[pos - 1, nn]], tst[Quotient[pos - 1, nn]]}];

nN = 16;
(* 1. disk: R==1, cannot fold -> operator-only check *)
sf["disk  (minJ, #J<=0, maxJ, lapErr, worstIx, worstIy) = ",
   tst[testMap[mkMap[1 &], nN]]];
(* 2. amplitude scan, Sin[3 phi] *)
Do[sf["amp=", amp, "  ", tst[testMap[mkMap[1 + amp Sin[3 #] &], nN]]],
   {amp, {0.25, 0.2, 0.15, 0.1, 0.05}}];
(* 3. 2-fold and 4-fold variants at amp 0.2 *)
sf["sin2 amp0.2  ", tst[testMap[mkMap[1 + 0.2 Sin[2 #] &], nN]]];
sf["cos2 amp0.2  ", tst[testMap[mkMap[1 + 0.2 Cos[2 #] &], nN]]];
sf["sin3+cos1    ", tst[testMap[mkMap[1 + 0.15 Sin[3 #] + 0.05 Cos[#] &], nN]]];
sf["DONE-p11m2"];
sfClose[];
Quit[];
