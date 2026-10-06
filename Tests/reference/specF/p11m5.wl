(* p11m5 -- G5 spectral-convergence gate for the corrected +Lap operator.
    Open question from p11m4: annul lapErr=1.2e-3 at n=16 is 3 orders above
    the other geometries (rect 3.6e-9, wavy 3.9e-6, pinc 1e-9..1e-10).
    TRUNCATION (composition sin(2 r cos th +1) resolved only to ~n=16)
    -> lapErr collapses geometrically with n.  A leftover operator bug on
    the annul map -> lapErr stays ~1e-3 or worsens.
    Runs rect/wavy/pinc6/annul at nN = 16, 24, 32; starA2 negative control
    once at 16 (must stay O(1e3)).  Also prints minJ + fdJ per run so the
    metric gate cannot regress unnoticed. *)
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
flin = Simplify[Laplacian[uex[x, y], {x, y}]];

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
    resOp, pv, i0, j0, x0, y0, h, xip, xet, yip, yet, jfd, fdrel},
  nn = nN + 1;
  xg = cgl[-1., 1., nn]; yg = cgl[-1., 1., nn];
  Xs = Table[sm[a, b][[1]], {a, xg}, {b, yg}];
  Ys = Table[sm[a, b][[2]], {a, xg}, {b, yg}];
  Dm = chebD1[xg]; D2m = Dm.Dm;
  xxi = Dm.Xs; xe = Xs.Transpose[Dm]; yxi = Dm.Ys; ye = Ys.Transpose[Dm];
  Jm = xxi*ye - xe*yxi;
  pv = Flatten[Transpose[Jm]];
  al = ye/Jm; be = -yxi/Jm; ga = -xe/Jm; de = xxi/Jm;
  AA = al^2 + ga^2; BB = 2 (al be + ga de); CCc = be^2 + de^2;
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
  i0 = Floor[nn/2]; j0 = i0; x0 = xg[[i0]]; y0 = yg[[j0]]; h = 1.*^-6;
  xip = (sm[x0 + h, y0][[1]] - sm[x0 - h, y0][[1]])/(2 h);
  xet = (sm[x0, y0 + h][[1]] - sm[x0, y0 - h][[1]])/(2 h);
  yip = (sm[x0 + h, y0][[2]] - sm[x0 - h, y0][[2]])/(2 h);
  yet = (sm[x0, y0 + h][[2]] - sm[x0, y0 - h][[2]])/(2 h);
  jfd = xip*yet - xet*yip;
  fdrel = Abs[jfd - Jm[[i0, j0]]]/Abs[Jm[[i0, j0]]];
  {Min[pv], Count[pv, _?(# <= 0 &)], ef[resOp], fdrel}];

report[name_, mk_, nN_] := Module[{r = mk[[1]], ec = mk[[2]]},
   sf[name, "@", nN, " cornerConsist=", ec,
     "  (minJ, #J<=0, lapErr, fdJ)=", tst[testMap[r, nN]]]];

(* -- the four admissible geometries (unchanged from p11m4) -- *)
rectMK = mkMap4[{#1, -1} &, {#1, 1} &, {-1, #1} &, {1, #1} &];
db = 0.35; dt = 0.25; dl = -0.35; dr = 0.2;
wavyMK = mkMap4[
  {#1, -1 - db (1 - #1^2)} &, {#1, 1 + dt (1 - #1^2)} &,
  {-1 - dl (1 - #1^2), #1} &, {1 + dr (1 - #1^2), #1} &];
pinc[g_] := Module[{K = {{1, 0}, {0, 1}, {-1, 0}, {0, -1}}, mm},
  Table[mm = g (K[[k]] + K[[Mod[k, 4] + 1]])/2;
    With[{K0 = K[[k]], K1 = K[[Mod[k, 4] + 1]], m = mm},
     Function[t, (1 - t)^2 K0 + 2 t (1 - t) m + t^2 K1]], {k, 1, 4}]];
c2t[f_] := Function[t, f[(1 + t)/2]];
c2tr[f_] := Function[t, f[(1 - t)/2]];
pg = pinc[0.6];
pincMK = mkMap4[c2t[pg[[4]]], c2tr[pg[[2]]], c2tr[pg[[3]]], c2t[pg[[1]]]];
rlo = 1.; rhi = 2.;
th[xx_] := Pi (1 - xx)/4;
rr[yy_] := (rlo + rhi)/2 + (rhi - rlo)/2 yy;
annulMK = mkMap4[
  Function[t, rr[-1] {Cos[th[t]], Sin[th[t]]}],
  Function[t, rr[1] {Cos[th[t]], Sin[th[t]]}],
  Function[t, rr[t] {0, 1}],
  Function[t, rr[t] {1, 0}]];
rad[ph_] := 1 + 0.2 Sin[3 ph];
sc1[xx_] := With[{ph = -Pi/2 + xx Pi/4}, rad[ph] {Cos[ph], Sin[ph]}];
sc2[xx_] := With[{ph = Pi/2 - xx Pi/4}, rad[ph] {Cos[ph], Sin[ph]}];
sc3[yy_] := With[{ph = -3 Pi/4 - (yy + 1) Pi/4}, rad[ph] {Cos[ph], Sin[ph]}];
sc4[yy_] := With[{ph = yy Pi/4}, rad[ph] {Cos[ph], Sin[ph]}];
starMK = mkMap4[sc1, sc2, sc3, sc4];

Do[
  report["rect", rectMK, nN];
  report["wavy", wavyMK, nN];
  report["pinc6", pincMK, nN];
  report["annul", annulMK, nN];
  , {nN, {16, 24, 32}}];
report["starA2", starMK, 16];
sf["DONE-p11m5"];
sfClose[];
Quit[];
