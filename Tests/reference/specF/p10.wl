(* p10 -- stage 4: complex boundary.  L-shaped domain
   Omega = [-1,1]x[-1,0] U [-1,0]x[0,1]  (reentrant corner at origin, 3Pi/2).
   Sections:
     E0  exact solution uex = Sin[2x+1]Cos[3y-1] + xy/5 (nonzero interface trace),
         f = -Lap uex = 13 Cos[1-3y] Sin[1+2x], fixed sample points (SeedRandom 42).
     E2  geometry representability: scanline y=0.5 cuts Omega at [-1,0].
         Global Chebyshev interpolant of that indicator -> Gibbs, max err stuck O(1)
         at every n; two-patch piecewise (each patch boundary axis-aligned) -> exact.
         This is the single-patch weakness; patching is the fix.
     E1  reference: NDSolve FEM with WL built-in ToElementMesh mesh generation,
         4 refinements (MaxCellMeasure /4 each -> h/2), errors at same samples.
     E3  multi-domain Chebyshev COLLOCATION, direct coupled solve:
         - two tensor patches (CGL grids), C0 continuity by shared interface trace W =
           patch2 bottom-row interior nodes (xs2 interior), interpolated spectrally
           (barycentric) onto patch1's top row at xs1 interior nodes in [-1,0];
         - flux rows: Dy u1(x,0-) - Dy u2(x,0+) = 0 at xs2 interior nodes
           (patch1's y-derivative top profile interpolated in x to xs2 nodes);
         - physical Dirichlet values folded into RHS (lift); unknowns =
           [I1 interior; I2 interior; W], size 2(Ne-1)^2+(Ne-1), sparse LinearSolve.
         Gates per Ne: G1 chebD1 on x^4 (<=1e-9); G2 trace interpolation vs direct
         uex (<=1e-6); G3 flux rows on the EXACT grid functions of uex (<=1e-8).
   Guards (from p9 lessons): rmax-style NumericQ guards (emx), no N-shadowing,
   Outer[Subtract] only, Cos exact -> N[] before machine compares, VectorQ guards.
   WL trap found here (p10 v1/v2): (a) barycentric cardinal = (w_j/(t-g_j)) /
   Total[...], missing the denominator gave E2/E3 errors ~1e5 (2-patch constant
   -> 8.4e5); node-hit branch was accidentally correct, masking it in mental tests.
   (b) KroneckerProduct[P,Q]: Q's index is the FAST one, so with flat = ix + n*iy
   (x fast) the x-operator must be the 2nd argument; original L/Dy args swapped
   gave G3=1.08 constant across Ne, Ne=8 singular, solve errs ~1e14. Gates G4/G5
   (L.aex + f = 0 at interior) now pin the Laplacian orientation directly.
   (c) RHS sign: L = Laplacian but f = -Laplacian[u], so the row is
   L.x = -f - Lsub.r; writing +f solved the wrong-sign PDE -> err flat 1.61 for
   every Ne, sysRes(pde) ~ 2|f| ~ 25 while flux rows were already ~1e-13.
   Needs["NDSolve`FEM`"] for ToElementMesh. *)
$HistoryLength = 0;
Get[FileNameJoin[{Directory[], "helpers.wl"}]];
tst[e_] := StringTake[ToString[e, InputForm],
   Min[300, StringLength[ToString[e, InputForm]]]];
emx[v_] := If[VectorQ[v, NumericQ], N[Max[Abs[v]]], -1.];

(* --- helpers: ascending CGL grid, Chebyshev D1, barycentric --- *)
cgl[a_, b_, nn_] := Table[(a + b)/2 - (b - a)/2 Cos[k Pi/(nn - 1)], {k, 0, nn - 1}];
chebD1[xx_] := Module[{nn = Length[xx], cc, sg, aa, bb, d, ii},
   cc = Table[If[i == 1 || i == nn, 2., 1.], {i, nn}];
   sg = (-1.)^Range[0, nn - 1];
   aa = sg cc; bb = sg/cc;
   d = Outer[Times, aa, bb]/(Outer[Subtract, xx, xx] + IdentityMatrix[nn])
      - IdentityMatrix[nn];
   ii = -Map[Total, d];
   d + DiagonalMatrix[ii]];
baryW[g_] := Module[{nn = Length[g]},
   Table[1./Product[If[k == j, 1., g[[j]] - g[[k]]], {k, nn}], {j, nn}]];
baryVec[g_, w_, t_] := Module[{nn = Length[g], wl, dd, hp, num},
   wl = w/Max[Abs[w]]; dd = t - g;
   hp = FirstPosition[Abs[dd], x_ /; x < 1.*^-13];
   If[hp =!= Missing["NotFound"],
    Return[ReplacePart[ConstantArray[0., nn], First[hp] -> 1.]]];
   num = wl/dd; num/Total[num]];
baryMat[src_, tgt_] := Module[{w = baryW[src]}, Table[baryVec[src, w, t], {t, tgt}]];

(* ================= E0: setup ================= *)
uex[x_, y_] := Sin[2 x + 1] Cos[3 y - 1] + x y/5;
fexpr = Simplify[-Laplacian[uex[x, y], {x, y}]];
ue[x_, y_] := N[uex[x, y]];
SeedRandom[42];
pp = Select[RandomReal[{-0.98, 0.98}, {3000, 2}],
   ! (#[[1]] > 0 && #[[2]] > 0) && ! (#[[1]] > -0.02 && #[[2]] > -0.02) &];
sf["E0: f=", tst[fexpr], " nSamples=", Length[pp],
   " uex on interface (x=-0.5): ", tst[N[uex[-0.5, 0.]]]];

(* ================= E2: geometry representability ================= *)
sf["--- E2: scanline y=0.5 -> indicator of [-1,0]; global Chebyshev vs 2-patch ---"];
fine = Range[-1., 1., 2./4000];
chi[x_] := If[x <= 0., 1., 0.];
e2g = {};
Do[g = cgl[-1., 1., nn]; w = baryW[g];
  v = chi /@ g;
  ee = emx[Table[baryVec[g, w, t] . v, {t, fine}] - chi /@ fine];
  AppendTo[e2g, ee];
  sf["  n=", nn, " globalCheb maxErr=", ee], {nn, {33, 65, 129, 257}}];
gl = cgl[-1., 0., 129]; gr = cgl[0., 1., 129];
el = emx[Table[baryVec[gl, baryW[gl], t] . ConstantArray[1., 129] - 1.,
    {t, Select[fine, # < -1.*^-6 &]}]];
er = emx[Table[baryVec[gr, baryW[gr], t] . ConstantArray[0., 129],
    {t, Select[fine, # > 1.*^-6 &]}]];
sf["  2-patch piecewise constants: leftErr=", el, " rightErr=", er];

(* ================= E1: NDSolve FEM (built-in mesh) ================= *)
sf["--- E1: NDSolve FEM via WL built-in ToElementMesh ---"];
Needs["NDSolve`FEM`"];
om = RegionUnion[Rectangle[{-1, -1}, {1, 0}], Rectangle[{-1, 0}, {0, 1}]];
sf["  RegionQ=", tst[RegionQ[om]]];
femErrs = {}; femTs = {};
Do[{tm, m} = AbsoluteTiming[ToElementMesh[om, "MaxCellMeasure" -> mcm]];
  {ts, us} = AbsoluteTiming[NDSolveValue[{-Laplacian[u[x, y], {x, y}] == fexpr,
      DirichletCondition[u[x, y] == uex[x, y],
       x <= -1 || y <= -1 || x >= 1 || (x >= 0 && y >= 0) || y >= 1]},
     u, {x, y} \[Element] m]];
  ne = Length[First[First[m["MeshElements"]]]];
  ee = emx[Table[us[p[[1]], p[[2]]] - ue[p[[1]], p[[2]]], {p, pp}]];
  AppendTo[femErrs, ee]; AppendTo[femTs, tm + ts];
  sf["  mcm=", mcm, " nElem=", ne, " tMesh=", tm, " tSolve=", ts, " err=", ee],
  {mcm, {0.04, 0.01, 0.0025, 0.000625}}];
sf["  FEM rates (h halved): ",
   tst[Table[Log[2, femErrs[[k - 1]]/femErrs[[k]]],
     {k, 2, Length[femErrs]}]]];

(* ================= E3: multi-domain spectral ================= *)
sf["--- E3: multi-domain Chebyshev collocation (2 patches, direct coupled solve) ---"];
errs3 = {}; tbs3 = {}; tss3 = {};
Do[Ne = nev; n = Ne + 1; ntot = 2 (Ne - 1)^2 + (Ne - 1);
  xs1 = cgl[-1., 1., n]; ys1 = cgl[-1., 0., n];
  xs2 = cgl[-1., 0., n]; ys2 = cgl[0., 1., n];
  {tB, eq} = AbsoluteTiming[
    (* operators *)
    D1x1 = chebD1[xs1]; D2x1 = D1x1 . D1x1;
    D1y1 = chebD1[ys1]; D2y1 = D1y1 . D1y1;
    D1x2 = chebD1[xs2]; D2x2 = D1x2 . D1x2;
    D1y2 = chebD1[ys2]; D2y2 = D1y2 . D1y2;
    Iden = SparseArray[IdentityMatrix[n]];
    (* Kronecker: 2nd arg index = FAST = x in our flat ix + n*iy layout *)
    L1 = KroneckerProduct[Iden, SparseArray[D2x1]] + KroneckerProduct[SparseArray[D2y1], Iden];
    L2 = KroneckerProduct[Iden, SparseArray[D2x2]] + KroneckerProduct[SparseArray[D2y2], Iden];
    Dy1op = KroneckerProduct[SparseArray[D1y1], Iden];
    Dy2op = KroneckerProduct[SparseArray[D1y2], Iden];
    topRows = Table[1 + ix + n Ne, {ix, 0, Ne}];
    botRows = Table[1 + ix, {ix, 0, Ne}];
    Cmat = baryMat[xs1, xs2]; (* rows targets xs2, cols sources xs1 *)
    F1 = Take[Cmat . Dy1op[[topRows]], {2, Ne}];
    F2 = Take[Dy2op[[botRows]], {2, Ne}];
    (* trace interpolation onto patch1 top interior nodes xs1, x in (-1,0) *)
    targ = Take[xs1, {2, Ne/2}];
    Bfull = baryMat[xs2, targ];
    BW = Bfull[[All, 2 ;; n - 1]];
    c1v = Bfull[[All, 1]] uex[-1., 0.] + Bfull[[All, n]] uex[0., 0.];
    (* col offsets: I1 | I2 | W *)
    o1 = 0; o2 = (Ne - 1)^2; ow = 2 (Ne - 1)^2;
    rules1 = Join[
      Flatten[Table[{1 + ix + n iy,
          o1 + (ix - 1) + (Ne - 1) (iy - 1) + 1} -> 1.,
         {iy, 1, Ne - 1}, {ix, 1, Ne - 1}], 1],
      Flatten[Table[{1 + ix + n Ne, ow + j} -> BW[[ix, j]],
         {ix, 1, Ne/2 - 1}, {j, 1, Ne - 1}], 1]];
    rules2 = Join[
      Flatten[Table[{1 + ix + n iy,
          o2 + (ix - 1) + (Ne - 1) (iy - 1) + 1} -> 1.,
         {iy, 1, Ne - 1}, {ix, 1, Ne - 1}], 1],
      Table[{1 + ix, ow + ix} -> 1., {ix, 1, Ne - 1}]];
    M1 = SparseArray[rules1, {n^2, ntot}];
    M2 = SparseArray[rules2, {n^2, ntot}];
    (* lifts: physical Dirichlet values + interface c1v *)
    r1 = Table[0., {n^2}];
    Do[If[iy == 0 || ix == 0 || ix == Ne || (iy == Ne && ix >= Ne/2),
        r1[[1 + ix + n iy]] = uex[xs1[[ix + 1]], ys1[[iy + 1]]]],
      {iy, 0, Ne}, {ix, 0, Ne}];
    Do[r1[[1 + ix + n Ne]] = c1v[[ix]], {ix, 1, Ne/2 - 1}];
    r2 = Table[0., {n^2}];
    Do[If[ix == 0 || ix == Ne || iy == Ne,
        r2[[1 + ix + n iy]] = uex[xs2[[ix + 1]], ys2[[iy + 1]]]],
      {iy, 0, Ne}, {ix, 0, Ne}];
    (* PDE rows at interior nodes *)
    intRows = Flatten[Table[1 + ix + n iy, {iy, 1, Ne - 1}, {ix, 1, Ne - 1}]];
    L1sub = L1[[intRows]]; L2sub = L2[[intRows]];
    f1sub = Table[With[{ix = Mod[r - 1, n], iy = Quotient[r - 1, n]},
        N[fexpr /. {x -> xs1[[ix + 1]], y -> ys1[[iy + 1]]}]], {r, intRows}];
    f2sub = Table[With[{ix = Mod[r - 1, n], iy = Quotient[r - 1, n]},
        N[fexpr /. {x -> xs2[[ix + 1]], y -> ys2[[iy + 1]]}]], {r, intRows}];
    A1 = L1sub . M1; b1 = -f1sub - L1sub . r1;
    A2 = L2sub . M2; b2 = -f2sub - L2sub . r2;
    A3 = F1 . M1 - F2 . M2; b3 = F2 . r2 - F1 . r1;
    A = Join[A1, A2, A3]; bb = Join[b1, b2, b3];
    (* gates *)
    g1 = emx[D1x1 . (xs1^4) - 4 xs1^3];
    trv = Table[uex[xs2[[j + 1]], 0.], {j, 1, Ne - 1}];
    tg = uex[#, 0.] & /@ targ;
    g2 = emx[BW . trv + c1v - tg];
    a1ex = Flatten[Table[uex[xs1[[ix + 1]], ys1[[iy + 1]]], {iy, 0, Ne}, {ix, 0, Ne}]];
    a2ex = Flatten[Table[uex[xs2[[ix + 1]], ys2[[iy + 1]]], {iy, 0, Ne}, {ix, 0, Ne}]];
    g3 = emx[F1 . a1ex - F2 . a2ex];
    g4 = emx[(L1 . a1ex)[[intRows]] + f1sub];
    g5 = emx[(L2 . a2ex)[[intRows]] + f2sub];
    ];
  {tS, xsol} = AbsoluteTiming[LinearSolve[A, bb]];
  If[! VectorQ[xsol, NumericQ], sf["  Ne=", Ne, " SOLVE FAILED: ", tst[Head[xsol]]],
   a1 = M1 . xsol + r1; a2 = M2 . xsol + r2;
   (* self-diagnostics: exact grid vector into the system, split by row block;
      grid-value error vs sample-point error separates solve-bug from eval-bug *)
   xex = Join[Table[a1ex[[r]], {r, intRows}],
     Table[a2ex[[r]], {r, intRows}],
     Table[a2ex[[1 + j]], {j, 1, Ne - 1}]];
   rAll = A . xex - bb;
   n1 = (Ne - 1)^2;
   eg1 = emx[a1 - a1ex]; eg2 = emx[a2 - a2ex];
   sys = emx[rAll];
   sp1 = emx[Take[rAll, n1]];
   sp2 = emx[Take[rAll, {n1 + 1, 2 n1}]];
   sfl = emx[Take[rAll, {2 n1 + 1, ntot}]];
   w1y = baryW[ys1]; w1x = baryW[xs1]; w2y = baryW[ys2]; w2x = baryW[xs2];
   m1 = Partition[a1, n]; m2 = Partition[a2, n];
   e3v = Table[If[p[[2]] <= 0,
        baryVec[ys1, w1y, p[[2]]] . m1 . baryVec[xs1, w1x, p[[1]]],
        baryVec[ys2, w2y, p[[2]]] . m2 . baryVec[xs2, w2x, p[[1]]]
        ] - ue[p[[1]], p[[2]]], {p, pp}];
   e3 = If[VectorQ[e3v, NumericQ], N[Max[Abs[e3v]]], -1.];
   wpi = Ordering[Abs[e3v], -1][[1]];
   AppendTo[errs3, e3]; AppendTo[tbs3, tB]; AppendTo[tss3, tS];
   sf["  Ne=", Ne, " ntot=", ntot, " err=", e3,
      " tBuild=", tB, " tSolve=", tS,
      " G1=", g1, " G2=", g2, " G3=", g3, " G4=", g4, " G5=", g5];
   sf["      sysRes(exact in A,b)=", sys, " pde1=", sp1, " pde2=", sp2,
      " flux=", sfl, " eg1=", eg1, " eg2=", eg2,
      " worst=", tst[pp[[wpi]]], " diff=", e3v[[wpi]]]];
  If[g1 > 1.*^-8 || g2 > 1.*^-5 || g3 > 1.*^-4 || g4 > 1.*^-3 || g5 > 1.*^-3,
   sf["  GATE FAIL Ne=", Ne, " g1=", g1, " g2=", g2, " g3=", g3,
      " g4=", g4, " g5=", g5]],
  {nev, {8, 12, 16, 24, 32}}];

(* ================= E4: verdict ================= *)
sf["E4: FEM errs=", tst[femErrs], " times=", tst[femTs]];
sf["E4: spectral errs=", tst[errs3], " tBuild=", tst[tbs3], " tSolve=", tst[tss3]];
sf["E4: FEM finest t=", tst[femTs[[-1]]], " err=", tst[femErrs[[-1]]],
   " || spectral coarsest->finest err=", tst[errs3],
   " worst spectral t=", tst[Max[tbs3 + tss3]]];
sf["DONE-p10"];
sfClose[];
Quit[];