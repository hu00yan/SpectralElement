(* p11 -- stage 5: NONLINEAR PDE on ARBITRARY CURVED domains via transfinite
   (Coons) spectral elements.  PDE:  -Lap u + u^3 = f  with manufactured
     uex = Sin[2x+1]Cos[3y-1] + xy/5,  f = -Lap uex + uex^3 (WL Laplacian).
   Probe chain (all green, files p11m*.wl / *.txt):
     p11m  region meshing + nonlinear NDSolve feasibility
     p11m2 found: (i) 1st-order chain-rule terms of Lap were wrong;
                (ii) transfinite map on a SMOOTH boundary has J=0 at the 4
                patch corners (adjacent boundary curves share a tangent)
                -> patch vertices must be TRUE corners of the domain.
     p11m3 proved the operator fix (its lapErr~25.5 was the PROBE's own ref
           sign bug: Lop = +Lap, ref was -Lap -> residual exactly 2 Lap uex
           <= 26; annul c4 pointed at wrong ray -> orientation J<0)
     p11m4 fixed ref sign + annul orientation; all metrics + G3 FD-Jacobian
           green; starA2 (smooth) confirmed Jcorner~-2e-11 -> REJECTED.
     p11m5 G5 spectral collapse: annul 1.2e-3 -> 1.0e-7 -> 2.3e-10 (n 16/24/32)
   Sections:
     E0  G2 flat-degeneracy: Lop(rect) == p10's flat Kron Laplacian.
     E1  single patch = pincushion star (gamma=0.6, four quadratic concave
         arcs, TRUE corners), nonlinear Newton, n = 16/24/32;
         G1 minJ, G3 fdJ, G4 Newton delta sequence (quadratic), nodal err.
     E2  half-annulus r in [1,2], theta in [0,pi], split radially at r=1.5
         into 2 patches.  Both patches: xi <-> theta (decreasing), eta <-> r
         (increasing) => interface arc r=1.5 is an ETA-edge in BOTH patches
         and J = r*pi/8 > 0.  Same xi-grid both sides => shared interface
         trace W pointwise (no cross-grid interpolation, unlike p10).
         Flux = normal derivative along grad(eta) = +r-hat in both patches:
           d/dn = [(a b + g d) u_xi + (b^2 + d^2) u_eta] / sqrt(b^2 + d^2)
           (flat check: -> u_y, p10's Dy)
         rows = [PDE-A interior; PDE-B interior; flux at interface xi-int],
         Newton on the coupled system, n = 16/24/32.
         G6 per-block residuals at convergence + exact-grid-function PDE
         residuals; G7 flux row on EXACT grid functions of uex (curved-
         interface operator consistency).
     E3  NDSolve FEM on the SAME half-annulus (built-in ToElementMesh from
         boolean Disk regions), 4 refinements; err evaluated at the spectral
         interior nodes of BOTH patches (same points => apples to apples),
         mesh+solve times vs E2.
     E4  verdict lines.
   Conventions (p10-compatible): flat = xi + n*eta (xi FAST) so the xi
   operator is the 2nd Kronecker argument; nodeVec = Flatten[Transpose].
   Traps pinned here: Lop = +Lap (PDE row is -Lop.u + u^3 = f); transfinite
   needs TRUE corners; FEM Dirichlet predicate needs tolerance (mesh coords
   on the circle are 1+/-eps).
   Guards: emx numeric guard (-1 on non-numeric), VectorQ after LinearSolve,
   per-run unique $SPECF_OUT from r.sh. *)
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
lapu = Simplify[Laplacian[uex[x, y], {x, y}]];
fexpr = -lapu + uex[x, y]^3;

mkMap4[c1_, c2_, c3_, c4_] := Module[{V1, V2, V3, V4, sm, ec},
   V1 = c1[-1]; V2 = c1[1]; V3 = c2[-1]; V4 = c2[1];
   ec = Max[Abs[V1 - c3[-1]], Abs[V2 - c4[-1]], Abs[V3 - c3[1]],
     Abs[V4 - c4[1]]];
   sm[xx_, yy_] := Module[{a0 = (1 - xx)/2, a1 = (1 + xx)/2,
       b0 = (1 - yy)/2, b1 = (1 + yy)/2},
      b0 c1[xx] + b1 c2[xx] + a0 c3[yy] + a1 c4[yy]
       - (a0 b0 V1 + a1 b0 V2 + a0 b1 V3 + a1 b1 V4)];
   {sm, ec}];

(* mkOps: given parametrization sm and degree nN, return
   {nn, Xs, Ys, Dm, Lop, Jm, fdrel, intRows, ABe, SQ}
   Lop discretizes +Lap; ABe = a b + g d and SQ = sqrt(b^2+d^2) are the
   fields of the eta-normal derivative; fdrel = G3 FD Jacobian rel.err. *)
mkOps[sm_, nN_] := Module[{nn, xg, yg, Xs, Ys, Dm, D2m, xxi, xe, yxi, ye,
    Jm, al, be, ga, de, AA, BB, CCc, d10, d01, vv, Id, Lop, i0, j0, x0, y0,
    h, xip, xet, yip, yet, jfd, fdrel, intRows},
  nn = nN + 1;
  xg = cgl[-1., 1., nn]; yg = cgl[-1., 1., nn];
  Xs = Table[sm[a, b][[1]], {a, xg}, {b, yg}];
  Ys = Table[sm[a, b][[2]], {a, xg}, {b, yg}];
  Dm = chebD1[xg]; D2m = Dm.Dm;
  xxi = Dm.Xs; xe = Xs.Transpose[Dm]; yxi = Dm.Ys; ye = Ys.Transpose[Dm];
  Jm = xxi*ye - xe*yxi;
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
  intRows = Flatten[Table[1 + ix + nn iy, {iy, 1, nn - 2}, {ix, 1, nn - 2}]];
  i0 = Floor[nn/2]; j0 = i0; x0 = xg[[i0]]; y0 = yg[[j0]]; h = 1.*^-6;
  xip = (sm[x0 + h, y0][[1]] - sm[x0 - h, y0][[1]])/(2 h);
  xet = (sm[x0, y0 + h][[1]] - sm[x0, y0 - h][[1]])/(2 h);
  yip = (sm[x0 + h, y0][[2]] - sm[x0 - h, y0][[2]])/(2 h);
  yet = (sm[x0, y0 + h][[2]] - sm[x0, y0 - h][[2]])/(2 h);
  jfd = xip*yet - xet*yip;
  fdrel = Abs[jfd - Jm[[i0, j0]]]/Abs[Jm[[i0, j0]]];
  {nn, Xs, Ys, Dm, Lop, Jm, fdrel, intRows, al be + ga de, Sqrt[be^2 + de^2]}];

(* ================= E0: G2 flat-degeneracy vs p10 ================= *)
sf["E0: G2 flat-degeneracy -- Lop(rect) vs p10 flat Kron Laplacian"];
{smR, ecR} = mkMap4[{#1, -1} &, {#1, 1} &, {-1, #1} &, {1, #1} &];
oR = mkOps[smR, 24];
(* NB: must be ONE line -- at top level a newline after a syntactically
   complete expr terminates it, so a leading '+' on the next line is a
   separate (discarded) expr; this bug made Lopflat = 1st Kron only and
   g2 = max|D2| = 3.5e4 (caught by p11dbg1-5). *)
Lopflat = KroneckerProduct[SparseArray[IdentityMatrix[oR[[1]]]], SparseArray[oR[[4]].oR[[4]]]] + KroneckerProduct[SparseArray[oR[[4]].oR[[4]]], SparseArray[IdentityMatrix[oR[[1]]]]];
g2 = emx[Flatten[Normal[oR[[5]] - Lopflat]]];
sf["E0 cornerConsist=", ecR, " g2=", g2, " minJ=", Min[Flatten[oR[[6]]]],
   " fdJ=", oR[[7]]];

(* ================= E1: pincushion, single patch, Newton ================= *)
pinc[g_] := Module[{K = {{1, 0}, {0, 1}, {-1, 0}, {0, -1}}, mm},
  Table[mm = g (K[[k]] + K[[Mod[k, 4] + 1]])/2;
    With[{K0 = K[[k]], K1 = K[[Mod[k, 4] + 1]], m = mm},
     Function[t, (1 - t)^2 K0 + 2 t (1 - t) m + t^2 K1]], {k, 1, 4}]];
c2t[f_] := Function[t, f[(1 + t)/2]];
c2tr[f_] := Function[t, f[(1 - t)/2]];
pg = pinc[0.6];
{smE1, ecE1} = mkMap4[c2t[pg[[4]]], c2tr[pg[[2]]], c2tr[pg[[3]]], c2t[pg[[1]]]];
sf["--- E1: pincushion gamma=0.6, single patch, -Lap u + u^3 = f, Newton ---"];
sf["E1 cornerConsist=", ecE1, " (expect 0: patch verts = true corners)"];
e1E = {}; e1T = {}; e1D = {};
Do[
  Ne = nN; n = nN + 1; nint = (Ne - 1)^2;
  o = mkOps[smE1, nN];
  nn = o[[1]]; Xs1 = o[[2]]; Ys1 = o[[3]]; Lop1 = o[[5]]; Jm1 = o[[6]];
  fd1 = o[[7]]; intRows1 = o[[8]];
  tb0 = AbsoluteTime[];
  mxRules = Flatten[Table[{1 + ix + n iy,
       (ix - 1) + (Ne - 1) (iy - 1) + 1} -> 1.,
      {iy, 1, Ne - 1}, {ix, 1, Ne - 1}], 1];
  M1 = SparseArray[mxRules, {n^2, nint}];
  r1 = Table[0., {n^2}];
  Do[If[ix == 0 || iy == 0 || ix == Ne || iy == Ne,
     r1[[1 + ix + n iy]] =
      uex[Xs1[[ix + 1, iy + 1]], Ys1[[ix + 1, iy + 1]]]],
    {iy, 0, Ne}, {ix, 0, Ne}];
  fvec = Flatten[Table[
     N[fexpr /. {x -> Xs1[[ix + 1, iy + 1]], y -> Ys1[[ix + 1, iy + 1]]}],
     {iy, 1, Ne - 1}, {ix, 1, Ne - 1}]];
  Lsub = Lop1[[intRows1]];
  A0 = -Lsub.M1;
  Mint = M1[[intRows1]];
  a1ex = nodeVec[Table[uex[Xs1[[i, j]], Ys1[[i, j]]], {i, 1, n}, {j, 1, n}]];
  tB1 = AbsoluteTime[] - tb0;
  xk = Table[0., {nint}];
  dels = {};
  tn0 = AbsoluteTime[];
  Do[
    Uk = M1.xk + r1;
    Uki = Uk[[intRows1]];
    RA = -Lsub.Uk + Uki^3 - fvec;
    Jk = A0 + SparseArray[Band[{1, 1}] -> (3 Uki^2)].Mint;
    dx = LinearSolve[Jk, -RA];
    If[! VectorQ[dx, NumericQ],
     AppendTo[dels, -1.];
     sf["E1 n=", nN, " SOLVE FAILED: ", tst[Head[dx]]];
     Break[],
     AppendTo[dels, emx[dx]];
     xk = xk + dx;
     If[dels[[-1]] < 1.*^-13, Break[]]],
    {it, 1, 30}];
  tN1 = AbsoluteTime[] - tn0;
  a1 = M1.xk + r1;
  Uk = M1.xk + r1; Uki = Uk[[intRows1]];
  g6e1 = emx[-Lsub.Uk + Uki^3 - fvec];
  e1err = emx[(a1 - a1ex)[[intRows1]]];
  AppendTo[e1E, e1err]; AppendTo[e1T, tB1 + tN1]; AppendTo[e1D, dels];
  sf["E1 n=", nN, " minJ=", Min[Flatten[Jm1]], " fdJ=", fd1,
     " err=", e1err, " tB=", tB1, " tN=", tN1,
     " iters=", Length[dels], " finRes=", g6e1,
     " dels=", tst[dels]],
  {nN, {16, 24, 32}}];

(* ===== E2: half-annulus, 2 patches, shared-W interface, Newton ===== *)
sf["--- E2: half-annulus r[1,2] theta[0,pi] split at r=1.5, 2 patches ---"];
thE[xx_] := Pi (1 - xx)/2;
rrA[yy_] := 1.25 + 0.25 yy;
rrB[yy_] := 1.75 + 0.25 yy;
mkHalf[rr_] := mkMap4[
  Function[t, rr[-1] {Cos[thE[t]], Sin[thE[t]]}],
  Function[t, rr[1] {Cos[thE[t]], Sin[thE[t]]}],
  Function[t, rr[t] {-1, 0}],
  Function[t, rr[t] {1, 0}]];
{smA, ecA} = mkHalf[rrA];
{smB, ecB} = mkHalf[rrB];
sf["E2 cornerConsist A=", ecA, " B=", ecB, " (expect 0)"];
e2EA = {}; e2EB = {}; e2T = {}; e2D = {};
Do[
  Ne = nN; n = nN + 1; nint = (Ne - 1)^2;
  ntot = 2 nint + (Ne - 1); ow = 2 nint; o2 = nint;
  tb0 = AbsoluteTime[];
  oA = mkOps[smA, nN]; oB = mkOps[smB, nN];
  nn = oA[[1]]; XsA = oA[[2]]; YsA = oA[[3]]; LopA = oA[[5]];
  JmA = oA[[6]]; fdA = oA[[7]]; intRowsA = oA[[8]];
  XsB = oB[[2]]; YsB = oB[[3]]; LopB = oB[[5]];
  JmB = oB[[6]]; fdB = oB[[7]]; intRowsB = oB[[8]];
  (* flux rows: d/dn along grad(eta) = +r-hat in BOTH patches *)
  Idn = SparseArray[IdentityMatrix[n]];
  DxiA = KroneckerProduct[Idn, SparseArray[oA[[4]]]];
  DetaA = KroneckerProduct[SparseArray[oA[[4]]], Idn];
  DxiB = KroneckerProduct[Idn, SparseArray[oB[[4]]]];
  DetaB = KroneckerProduct[SparseArray[oB[[4]]], Idn];
  intFaceA = Table[1 + ix + n Ne, {ix, 1, Ne - 1}];
  intFaceB = Table[1 + ix, {ix, 1, Ne - 1}];
  NDopA = (SparseArray[Band[{1, 1}] -> nodeVec[oA[[9]]/oA[[10]]]].DxiA
       + SparseArray[Band[{1, 1}] -> nodeVec[oA[[10]]]].DetaA)[[intFaceA]];
  NDopB = (SparseArray[Band[{1, 1}] -> nodeVec[oB[[9]]/oB[[10]]]].DxiB
       + SparseArray[Band[{1, 1}] -> nodeVec[oB[[10]]]].DetaB)[[intFaceB]];
  (* selection + lift *)
  rules1 = Join[
    Flatten[Table[{1 + ix + n iy,
        (ix - 1) + (Ne - 1) (iy - 1) + 1} -> 1.,
       {iy, 1, Ne - 1}, {ix, 1, Ne - 1}], 1],
    Table[{1 + ix + n Ne, ow + ix} -> 1., {ix, 1, Ne - 1}]];
  M1 = SparseArray[rules1, {n^2, ntot}];
  r1 = Table[0., {n^2}];
  Do[If[ix == 0 || ix == Ne || iy == 0,
     r1[[1 + ix + n iy]] =
      uex[XsA[[ix + 1, iy + 1]], YsA[[ix + 1, iy + 1]]]],
    {iy, 0, Ne}, {ix, 0, Ne}];
  rules2 = Join[
    Flatten[Table[{1 + ix + n iy,
        o2 + (ix - 1) + (Ne - 1) (iy - 1) + 1} -> 1.,
       {iy, 1, Ne - 1}, {ix, 1, Ne - 1}], 1],
    Table[{1 + ix, ow + ix} -> 1., {ix, 1, Ne - 1}]];
  M2 = SparseArray[rules2, {n^2, ntot}];
  r2 = Table[0., {n^2}];
  Do[If[ix == 0 || ix == Ne || iy == Ne,
     r2[[1 + ix + n iy]] =
      uex[XsB[[ix + 1, iy + 1]], YsB[[ix + 1, iy + 1]]]],
    {iy, 0, Ne}, {ix, 0, Ne}];
  fvecA = Flatten[Table[
     N[fexpr /. {x -> XsA[[ix + 1, iy + 1]], y -> YsA[[ix + 1, iy + 1]]}],
     {iy, 1, Ne - 1}, {ix, 1, Ne - 1}]];
  fvecB = Flatten[Table[
     N[fexpr /. {x -> XsB[[ix + 1, iy + 1]], y -> YsB[[ix + 1, iy + 1]]}],
     {iy, 1, Ne - 1}, {ix, 1, Ne - 1}]];
  LsubA = LopA[[intRowsA]]; LsubB = LopB[[intRowsB]];
  A0A = -LsubA.M1; A0B = -LsubB.M2;
  MintA = M1[[intRowsA]]; MintB = M2[[intRowsB]];
  A3 = NDopA.M1 - NDopB.M2;
  a1ex = nodeVec[Table[uex[XsA[[i, j]], YsA[[i, j]]], {i, 1, n}, {j, 1, n}]];
  a2ex = nodeVec[Table[uex[XsB[[i, j]], YsB[[i, j]]], {i, 1, n}, {j, 1, n}]];
  tB2 = AbsoluteTime[] - tb0;
  xk = Table[0., {ntot}];
  dels = {};
  tn0 = AbsoluteTime[];
  Do[
    UA = M1.xk + r1; UB = M2.xk + r2;
    Uai = UA[[intRowsA]]; Ubi = UB[[intRowsB]];
    RA = -LsubA.UA + Uai^3 - fvecA;
    RB = -LsubB.UB + Ubi^3 - fvecB;
    R3 = NDopA.UA - NDopB.UB;
    J1 = A0A + SparseArray[Band[{1, 1}] -> (3 Uai^2)].MintA;
    J2 = A0B + SparseArray[Band[{1, 1}] -> (3 Ubi^2)].MintB;
    dx = LinearSolve[Join[J1, J2, A3], Join[-RA, -RB, -R3]];
    If[! VectorQ[dx, NumericQ],
     AppendTo[dels, -1.];
     sf["E2 n=", nN, " SOLVE FAILED: ", tst[Head[dx]]];
     Break[],
     AppendTo[dels, emx[dx]];
     xk = xk + dx;
     If[dels[[-1]] < 1.*^-13, Break[]]],
    {it, 1, 30}];
  tN2 = AbsoluteTime[] - tn0;
  UA = M1.xk + r1; UB = M2.xk + r2;
  Uai = UA[[intRowsA]]; Ubi = UB[[intRowsB]];
  g6a = emx[-LsubA.UA + Uai^3 - fvecA];
  g6b = emx[-LsubB.UB + Ubi^3 - fvecB];
  g6f = emx[NDopA.UA - NDopB.UB];
  g6ea = emx[-LsubA.a1ex + a1ex[[intRowsA]]^3 - fvecA];
  g6eb = emx[-LsubB.a2ex + a2ex[[intRowsB]]^3 - fvecB];
  g7 = emx[NDopA.a1ex - NDopB.a2ex];
  eA = emx[(UA - a1ex)[[intRowsA]]];
  eB = emx[(UB - a2ex)[[intRowsB]]];
  AppendTo[e2EA, eA]; AppendTo[e2EB, eB];
  AppendTo[e2T, tB2 + tN2]; AppendTo[e2D, dels];
  sf["E2 n=", nN, " minJA=", Min[Flatten[JmA]], " minJB=", Min[Flatten[JmB]],
     " fdA=", fdA, " fdB=", fdB];
  sf["E2 n=", nN, " errA=", eA, " errB=", eB, " tB=", tB2, " tN=", tN2,
     " iters=", Length[dels], " dels=", tst[dels]];
  sf["E2 n=", nN, " G6 fin: pdeA=", g6a, " pdeB=", g6b, " flux=", g6f,
     " | exact-grid: pdeA=", g6ea, " pdeB=", g6eb, " G7flux=", g7],
  {nN, {16, 24, 32}}];

(* ================= E3: NDSolve FEM, same half-annulus ================= *)
sf["--- E3: NDSolve FEM, same half-annulus, built-in ToElementMesh ---"];
Needs["NDSolve`FEM`"];
reg = RegionIntersection[RegionDifference[Disk[{0, 0}, 2], Disk[{0, 0}, 1]],
   Rectangle[{-2, 0}, {2, 2}]];
sf["E3 RegionQ=", tst[RegionQ[reg]]];
femT = {}; femE = {};
Do[
  {tm, m} = AbsoluteTiming[
    ToElementMesh[reg, "MaxCellMeasure" -> mcm]];
  {ts, us} = AbsoluteTiming[
    NDSolveValue[{-Laplacian[u[x, y], {x, y}] + u[x, y]^3 == fexpr,
       DirichletCondition[u[x, y] == uex[x, y],
        x^2 + y^2 <= 1.0000000001 || x^2 + y^2 >= 1.9999999999 ||
         y <= 1.*^-10]},
      u, {x, y} \[Element] m]];
  ne = Length[First[First[m["MeshElements"]]]];
  errN = emx[Join[
     Flatten[Table[
       us[XsA[[ix + 1, iy + 1]], YsA[[ix + 1, iy + 1]]] -
        uex[XsA[[ix + 1, iy + 1]], YsA[[ix + 1, iy + 1]]],
       {iy, 1, Ne - 1}, {ix, 1, Ne - 1}]],
     Flatten[Table[
       us[XsB[[ix + 1, iy + 1]], YsB[[ix + 1, iy + 1]]] -
        uex[XsB[[ix + 1, iy + 1]], YsB[[ix + 1, iy + 1]]],
       {iy, 1, Ne - 1}, {ix, 1, Ne - 1}]]]];
  AppendTo[femT, tm + ts]; AppendTo[femE, errN];
  sf["E3 mcm=", mcm, " nElem=", ne, " tMesh=", tm, " tSolve=", ts,
     " err@spectralNodes=", errN],
  {mcm, {0.04, 0.01, 0.0025, 0.000625}}];
sf["E3 FEM rates (h halved): ",
   tst[Table[Log[2, femE[[k - 1]]/femE[[k]]], {k, 2, Length[femE]}]]];

(* ================= E4: verdict ================= *)
sf["E4: E1(pinc n=16,24,32) errs=", tst[e1E], " times=", tst[e1T]];
sf["E4: E2(half-ring 2pt) errA=", tst[e2EA], " errB=", tst[e2EB],
   " times=", tst[e2T]];
sf["E4: FEM errs=", tst[femE], " times=", tst[femT]];
sf["E4: spectral finest errA=", e2EA[[-1]], " errB=", e2EB[[-1]],
   " worst spectral time=", Max[e2T],
   " || FEM finest err=", femE[[-1]], " time=", femT[[-1]],
   " || FEM has ", Length[femE], " levels vs spectral ",
   Length[e2EA], " (same points, interior nodes of both patches)"];
sf["DONE-p11"];
sfClose[];
Quit[];
