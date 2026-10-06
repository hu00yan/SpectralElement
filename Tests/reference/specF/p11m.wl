(* p11m -- probe for p11 (nonlinearity + curved/arbitrary domains).
   Three external risks, each probed standalone before p11 commits:
   A. star transfinite map: boundary repro, corners, J>0 (no folding),
      and the chain-rule Laplacian on the curved map vs analytic -Lap uex.
   B. annulus-sector map: spectral metric vs analytic derivatives.
   C. NDSolve side: ToElementMesh on (1) star ImplicitRegion,
      (2) boolean annulus-sector region; fallback chain for the star;
      then one quick nonlinear NDSolveValue each (timing + err). *)
$HistoryLength = 0;
Get[FileNameJoin[{Directory[], "helpers.wl"}]];
tst[e_] := StringTake[ToString[e, InputForm],
   Min[300, StringLength[ToString[e, InputForm]]]];
emx[v_] := If[VectorQ[v, NumericQ], N[Max[Abs[v]]], -1.];
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

(* ============ manufactured solution ============ *)
uex[x_, y_] := Sin[2 x + 1] Cos[3 y - 1] + x y/5;
flin = Simplify[-Laplacian[uex[x, y], {x, y}]];

(* ============ A. star map ============ *)
rc[ph_] := 1 + 0.25 Sin[3 ph];
c1[xx_] := With[{ph = -Pi/2 + xx Pi/4}, rc[ph] {Cos[ph], Sin[ph]}];
c2[xx_] := With[{ph = Pi/2 - xx Pi/4}, rc[ph] {Cos[ph], Sin[ph]}];
c3[yy_] := With[{ph = -3 Pi/4 - (yy + 1) Pi/4}, rc[ph] {Cos[ph], Sin[ph]}];
c4[yy_] := With[{ph = yy Pi/4}, rc[ph] {Cos[ph], Sin[ph]}];
V1 = c1[-1]; V2 = c1[1]; V3 = c2[-1]; V4 = c2[1];
starMap[xx_, yy_] := Module[{a0 = (1 - xx)/2, a1 = (1 + xx)/2,
    b0 = (1 - yy)/2, b1 = (1 + yy)/2},
   b0 c1[xx] + b1 c2[xx] + a0 c3[yy] + a1 c4[yy]
    - (a0 b0 V1 + a1 b0 V2 + a0 b1 V3 + a1 b1 V4)];

nN = 16; nn = nN + 1;
xg = cgl[-1., 1., nn]; yg = cgl[-1., 1., nn];
Xs = Table[starMap[a, b][[1]], {a, xg}, {b, yg}];
Ys = Table[starMap[a, b][[2]], {a, xg}, {b, yg}];
(* boundary repro + corners *)
eb = emx[Table[starMap[xg[[i]], -1.] - c1[xg[[i]]], {i, nn}]]
   + emx[Table[starMap[xg[[i]], 1.] - c2[xg[[i]]], {i, nn}]]
   + emx[Table[starMap[-1., yg[[j]]] - c3[yg[[j]]], {j, nn}]]
   + emx[Table[starMap[1., yg[[j]]] - c4[yg[[j]]], {j, nn}]];
ecor = emx[{V1 - c3[-1], V2 - c4[-1], V3 - c3[1], V4 - c4[1]}];
(* metric + chain-rule Laplacian on the curved map *)
Dm = chebD1[xg]; D2m = Dm.Dm;
xxi = Dm.Xs; xe = Xs.Transpose[Dm]; yxi = Dm.Ys; ye = Ys.Transpose[Dm];
Jm = xxi*ye - xe*yxi;
minJ = Min[Flatten[Jm]];
al = ye/Jm; be = -yxi/Jm; ga = -xe/Jm; de = xxi/Jm;
AA = al^2 + ga^2; BB = 2 (al be + ga de); CCc = be^2 + de^2;
d10 = al*(Dm.al) + be*(Dm.be) + ga*(Dm.ga) + de*(Dm.de);
d01 = al*(al.Transpose[Dm]) + be*(be.Transpose[Dm])
    + ga*(ga.Transpose[Dm]) + de*(de.Transpose[Dm]);
vv[v_] := SparseArray[Band[{1,1}] -> nodeVec[v]];
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
sf["A: minJ=", minJ, " bndRepro=", eb, " corners=", ecor,
   " curvedLap-vs-analytic=", emx[resOp]];

(* ============ B. annulus sector metric (analytic map) ============ *)
thg = cgl[0., Pi, nn];
Do[rlo = rr[[1]]; rhi = rr[[2]];
  rgg = cgl[rlo, rhi, nn];
  XA = Table[rgg[[j]] Cos[thg[[i]]], {i, nn}, {j, nn}];
  YA = Table[rgg[[j]] Sin[thg[[i]]], {i, nn}, {j, nn}];
  xa = Dm.XA; xae = XA.Transpose[Dm]; ya = Dm.YA; yae = YA.Transpose[Dm];
  e1 = emx[xa - Table[-rgg[[j]] Sin[thg[[i]]] Pi/4, {i, nn}, {j, nn}]];
  e2 = emx[xae - Table[(rhi - rlo)/2 Cos[thg[[i]]], {i, nn}, {j, nn}]];
  e3 = emx[ya - Table[rgg[[j]] Cos[thg[[i]]] Pi/4, {i, nn}, {j, nn}]];
  e4 = emx[yae - Table[(rhi - rlo)/2 Sin[thg[[i]]], {i, nn}, {j, nn}]];
  sf["B: r=", tst[rr], " metricErrs x_xi/x_eta/y_xi/y_eta=", e1, " ", e2,
     " ", e3, " ", e4], {rr, {{1., 1.5}, {1.5, 2.}}}];

(* ============ C. mesh + nonlinear NDSolve ============ *)
Needs["NDSolve`FEM`"];
fexpr = Simplify[-Laplacian[uex[x, y], {x, y}] + uex[x, y]^3];
starMesh = Quiet[Check[
   ToElementMesh[ImplicitRegion[
     x^2 + y^2 <= (1 + 0.25 Sin[3 ArcTan[y, x]])^2, {x, y}],
    "MaxCellMeasure" -> 0.02], $Failed]];
starSrc = "implicit";
If[starMesh === $Failed,
  starSrc = "polygon2000";
  starMesh = Quiet[Check[ToElementMesh[
     Polygon[Table[With[{ph = 2 Pi (k - 1)/2000}, rc[ph] {Cos[ph], Sin[ph]}],
       {k, 1, 2000}]], "MaxCellMeasure" -> 0.02], $Failed]]];
If[starMesh === $Failed, starSrc = "ALL FAILED"];
sf["C: star mesh via ", starSrc, If[starMesh === $Failed, " FAILED",
   " ok nElem=" <> tst[Length[First[First[starMesh["MeshElements"]]]]]]];

annBool = RegionIntersection[RegionDifference[Disk[{0, 0}, 2], Disk[{0, 0}, 1]],
   Rectangle[{-2, 0}, {2, 2}]];
annMesh = Quiet[Check[ToElementMesh[annBool, "MaxCellMeasure" -> 0.02], $Failed]];
sf["C: annulus-sector mesh ", If[annMesh === $Failed, " FAILED",
   "ok nElem=" <> tst[Length[First[First[annMesh["MeshElements"]]]]]]];

If[starMesh =!= $Failed,
 {t1, us1} = AbsoluteTiming[NDSolveValue[{-Laplacian[u[x, y], {x, y}] +
      u[x, y]^3 == fexpr, DirichletCondition[u[x, y] == uex[x, y], True]},
    u, {x, y} \[Element] starMesh]];
  sf["C: star nonlinear solve t=", t1,
     " errs=", tst[Table[Abs[us1[p[[1]], p[[2]]] - uex[p[[1]], p[[2]]]],
       {p, {{0., 0.}, {0.4, 0.3}, {-0.6, -0.2}, {0.6, 0.5}}}]]];
  sf["C: star solution head= ", tst[Head[us1]]]];
If[annMesh =!= $Failed,
 {t2, us2} = AbsoluteTiming[NDSolveValue[{-Laplacian[u[x, y], {x, y}] +
      u[x, y]^3 == fexpr, DirichletCondition[u[x, y] == uex[x, y], True]},
    u, {x, y} \[Element] annMesh]];
  sf["C: ann nonlinear solve t=", t2,
     " errs=", tst[Table[Abs[us2[p[[1]], p[[2]]] - uex[p[[1]], p[[2]]]],
       {p, {{1.2, 0.5}, {1.5, 0.9}, {-1.3, 1.1}, {-1.7, 0.3}}}]]];
  sf["C: ann solution head= ", tst[Head[us2]]]];
sf["DONE-p11m"];
sfClose[];
Quit[];
