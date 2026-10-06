(* p11m3 -- after p11m2 found two REAL defects, this probe proves the fixes:
   (1) operator bug: first-order chain-rule terms of Laplacian were wrong:
         correct d10 = a a_xi + b a_eta + g g_xi + d g_eta
         correct d01 = a b_xi + b b_eta + g d_xi + d d_eta
       (code had a a_xi + b b_xi + ... ; vanishes for constant metrics so
       the rectangle case never saw it).
   (2) transfinite map on a SMOOTH boundary degenerates at the 4 patch
       corners (adjacent boundary curves share a tangent -> J==0, seen on
       the disk).  Fix: patch vertices = TRUE corners of the domain.
   Cases: rect (constant metric baseline), wavy square (parabolic bulges,
   one concave side), pincushion star (4 concave arcs meeting at 4 corners),
   smooth star amp .2 (expected: J_corner~0, lapErr still poisoned -> the
   documented negative), annulus sector (analytic reference, corners 90 deg).
   Per case: corner consistency, minJ, J at 4 corner nodes, lapErr vs -Lap. *)
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

mkMap4[c1_, c2_, c3_, c4_] := Module[{V1, V2, V3, V4, sm, ec},
   V1 = c1[-1]; V2 = c1[1]; V3 = c2[-1]; V4 = c2[1];
   ec = Max[Abs[V1 - c3[-1]], Abs[V2 - c4[-1]], Abs[V3 - c3[1]],
     Abs[V4 - c4[1]]];
   sm[xx_, yy_] := Module[{a0 = (1 - xx)/2, a1 = (1 + xx)/2,
       b0 = (1 - yy)/2, b1 = (1 + yy)/2},
      b0 c1[xx] + b1 c2[xx] + a0 c3[yy] + a1 c4[yy]
       - (a0 b0 V1 + a1 b0 V2 + a0 b1 V3 + a1 b1 V4)];
   {sm, ec}];

testMap[sm_, nN_] := Module[{nn, xg, yg, Xs, Ys, Dm, D2m, xxi, xe, yxi, ye,
    Jm, al, be, ga, de, AA, BB, CCc, d10, d01, vv, Id, Lop, Um, fm, intR,
    resOp, pv, jcor},
  nn = nN + 1;
  xg = cgl[-1., 1., nn]; yg = cgl[-1., 1., nn];
  Xs = Table[sm[a, b][[1]], {a, xg}, {b, yg}];
  Ys = Table[sm[a, b][[2]], {a, xg}, {b, yg}];
  Dm = chebD1[xg]; D2m = Dm.Dm;
  xxi = Dm.Xs; xe = Xs.Transpose[Dm]; yxi = Dm.Ys; ye = Ys.Transpose[Dm];
  Jm = xxi*ye - xe*yxi;
  pv = Flatten[Transpose[Jm]];
  jcor = {Jm[[1, 1]], Jm[[nn, 1]], Jm[[1, nn]], Jm[[nn, nn]]};
  al = ye/Jm; be = -yxi/Jm; ga = -xe/Jm; de = xxi/Jm;
  AA = al^2 + ga^2; BB = 2 (al be + ga de); CCc = be^2 + de^2;
  (* first-order terms, CORRECTED:  d10 = a a_x + b a_y + g g_x + d g_y
                                     d01 = a b_x + b b_y + g d_x + d d_y *)
  d10 = al*(Dm.al) + be*(al.Transpose[Dm]) + ga*(Dm.ga) + de*(ga.Transpose[Dm]);
  d01 = al*(Dm.be) + be*(be.Transpose[Dm]) + ga*(Dm.de) + de*(de.Transpose[Dm]);
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
  {Min[pv], Count[pv, _?(# <= 0 &)], ef[resOp], tst[jcor]}];

report[name_, mk_] := Module[{r = mk[[1]], ec = mk[[2]]},
   sf[name, " cornerConsist=", ec, "  (minJ, #J<=0, lapErr, Jcorners)=",
     tst[testMap[r, 16]]]];

nN = 16;
(* 1. rectangle: affine, exact baseline *)
report["rect", mkMap4[{#1, -1} &, {#1, 1} &, {-1, #1} &, {1, #1} &]];
(* 2. wavy square: parabolic bulges, left side CONCAVE (delta<0) *)
db = 0.35; dt = 0.25; dl = -0.35; dr = 0.2;
report["wavy", mkMap4[
  {#1, -1 - db (1 - #1^2)} &, {#1, 1 + dt (1 - #1^2)} &,
  {-1 - dl (1 - #1^2), #1} &, {1 + dr (1 - #1^2), #1} &]];
(* 3. pincushion star: 4 concave quadratic arcs, corners at ( +/-1,0),(0,+/-1) *)
pinc[g_] := Module[{K = {{1, 0}, {0, 1}, {-1, 0}, {0, -1}}, mm},
  Table[mm = g (K[[k]] + K[[Mod[k, 4] + 1]])/2;
    With[{K0 = K[[k]], K1 = K[[Mod[k, 4] + 1]], m = mm},
     Function[t, (1 - t)^2 K0 + 2 t (1 - t) m + t^2 K1]], {k, 1, 4}]];
pg = pinc[0.6];
c2t[f_] := Function[t, f[(1 + t)/2]];
c2tr[f_] := Function[t, f[(1 - t)/2]];
(* edges: eta=-1: K4->K1 ; xi=+1: K1->K2 ; eta=+1: K3->K2 (reversed) ;
   xi=-1: K4->K3 (reversed) *)
report["pinc6", mkMap4[
  c2t[pg[[4]]], c2tr[pg[[2]]], c2tr[pg[[3]]], c2t[pg[[1]]]]];
pg2 = pinc[0.75];
report["pinc75", mkMap4[
  c2t[pg2[[4]]], c2tr[pg2[[2]]], c2tr[pg2[[3]]], c2t[pg2[[1]]]]];
(* 4. smooth star amp .2 -- EXPECT J_corner ~ 0 and poisoned lapErr *)
rad[ph_] := 1 + 0.2 Sin[3 ph];
sc1[xx_] := With[{ph = -Pi/2 + xx Pi/4}, rad[ph] {Cos[ph], Sin[ph]}];
sc2[xx_] := With[{ph = Pi/2 - xx Pi/4}, rad[ph] {Cos[ph], Sin[ph]}];
sc3[yy_] := With[{ph = -3 Pi/4 - (yy + 1) Pi/4}, rad[ph] {Cos[ph], Sin[ph]}];
sc4[yy_] := With[{ph = yy Pi/4}, rad[ph] {Cos[ph], Sin[ph]}];
report["starA2", mkMap4[sc1, sc2, sc3, sc4]];
(* 5. annulus sector (analytic, corners are true 90-deg corners) *)
rlo = 1.; rhi = 2.;
th[xx_] := Pi (1 + xx)/4;
rr[yy_] := (rlo + rhi)/2 + (rhi - rlo)/2 yy;
report["annul", mkMap4[
  Function[t, rr[-1] {Cos[th[t]], Sin[th[t]]}],
  Function[t, rr[1] {Cos[th[t]], Sin[th[t]]}],
  Function[t, rr[t] {1, 0}],
  Function[t, rr[t] {-1, 0}]]];
sf["DONE-p11m3"];
sfClose[];
Quit[];
