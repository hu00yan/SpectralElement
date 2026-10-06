(* p9 -- FAST Chebyshev second derivative (DCT-based), stage-2 research landing.
   On N+1 CGL points x_j = Cos[Pi j/N] (descending 1 -> -1):

     values --(DCT-I)--> plain coeffs a  (u = Sum a_k T_k, Convention A)
     a --(recursion x2)--> a''
     a'' --(DCT-I, scaled)--> values

   Recursion derivation (checked by hand on T_0..T_4): T_k' = k U_{k-1},
   U_m = 2(T_m + T_{m-2} + ...) with gamma_0 = 1, so for u = Sum a_k T_k,
   u' = Sum b_k T_k with
       R_j = Sum_{i >= j+1, i = j+1 mod 2} i a_i   (= (j+1) a_{j+1} + R_{j+2})
       b_0 = R_0,  b_j = 2 R_j (j >= 1),  b_N = 0.

   WL TRAPS fixed here (all found the hard way, see p9d/p9e/p9f outputs):
   - FourierDCT[v,1] normalization is SIZE-DEPENDENT: WL = sct(N) x textbook
     unnormalized DCT-I with sct(N) = 1/Sqrt[2N] (verified at N=16,64,128).
   - Outer[Minus, x, y] builds BINARY Minus[...] which does NOT evaluate in
     WL (binary subtraction's head is Subtract) -> the whole matrix becomes
     unevaluated symbols.  Use Outer[Subtract, ...].
   - Position[expr, patt, {2}] searches levels 1..2 (rows count for a
     matrix), and skips the elements of a vector entirely -- use
     VectorQ[., MachineNumberQ] / Count[Flatten[.], ...] instead.
   - a local n = 65 in a Module shadowed a Do iterator n (all four
     validation rows printed n=65); never reuse the iterator name.

   Gates before timing: calib, round trip, T_m extraction, d1 vs d1f,
   polynomial exactness, fast-vs-dense at 4 sizes.  Dense arbiter: p8's
   bigD2 formula (= D1.D1, validated in p8t4e vs built-in NDSolve`FFD). *)
$HistoryLength = 0;
Get[FileNameJoin[{Directory[], "helpers.wl"}]];
tst[e_] := ToString[N[e], InputForm];
rmax[a_, b_] := If[VectorQ[a, MachineNumberQ] && VectorQ[b, MachineNumberQ],
   Max[Abs[a - b]], -1.];

(* ---- 0. calibrate FourierDCT[,1]: WL = sct(N) x textbook DCT-I ---- *)
NC = 16;
y0 = FourierDCT[Table[1., {NC + 1}], 1];
sct = N[y0[[1]]/(2 NC)];
y1 = FourierDCT[Cos[Range[0, NC] Pi/NC], 1];
chk1 = rmax[y1/sct, Join[{0., N[NC]}, ConstantArray[0., NC - 1]]];
sf["calib N=16: sct=", tst[sct], " 1/Sqrt[2N]=", tst[N[1/Sqrt[2 NC]]],
   " T1-vector-chk=", tst[chk1]];
sctOf[Np_] := 1/Sqrt[2 Np];

(* ---- 1. value <-> coefficient maps (halve/double the two end coeffs) ---- *)
toC[u_, Np_] := Module[{y = FourierDCT[u, 1]/(sctOf[Np] Np)},
   y[[1]] = y[[1]]/2; y[[Np + 1]] = y[[Np + 1]]/2; y];
fromC[c_, Np_] := Module[{e = c},
   e[[1]] = 2 c[[1]]; e[[Np + 1]] = 2 c[[Np + 1]];
   FourierDCT[e, 1]/(2 sctOf[Np])];

(* ---- 2. first-derivative coefficient recursion, two variants ---- *)
d1[a_, Np_] := Module[{R, b},
   R = Developer`ToPackedArray[Table[0., {Np + 3}]];
   b = Developer`ToPackedArray[Table[0., {Np + 1}]];
   Do[R[[j + 1]] = (j + 1) a[[j + 2]] + R[[j + 3]], {j, Np - 1, 0, -1}];
   b[[1]] = R[[1]];
   Do[b[[j + 1]] = 2 R[[j + 1]], {j, 1, Np - 1}];
   b];
d1f[a_, Np_] := Module[{n = Np + 1, v, se, so, b},
   v = Developer`ToPackedArray[Range[Np] a[[2 ;; n]]];
   se = Developer`ToPackedArray[Total[v[[2 ;; Np ;; 2]]] - Accumulate[v[[2 ;; Np ;; 2]]] + v[[2 ;; Np ;; 2]]];
   so = Developer`ToPackedArray[Total[v[[1 ;; Np ;; 2]]] - Accumulate[v[[1 ;; Np ;; 2]]] + v[[1 ;; Np ;; 2]]];
   b = Developer`ToPackedArray[Table[0., {n}]];
   b[[1]] = so[[1]];
   b[[2 ;; Np ;; 2]] = 2 se;
   b[[3 ;; Np ;; 2]] = 2 so[[2 ;;]];
   b];
d2fast[u_, Np_, d1fn_: d1] := fromC[d1fn[d1fn[toC[u, Np], Np], Np], Np];

(* ---- 3. dense arbiter (vectorized build of p8's formula; Subtract!) ---- *)
cglg[n_] := N[-Cos[Range[0, n - 1] Pi/(n - 1)]];
bigD2v[n_] := Module[{xx, cc, sg, a, b, dd, ii},
   xx = cglg[n]; cc = Map[If[# == 1 || # == n, 2., 1.] &, Range[n]];
   sg = (-1.)^Range[n]; a = sg cc; b = sg/cc;
   dd = Outer[Times, a, b]/(Outer[Subtract, xx, xx] + IdentityMatrix[n]) - IdentityMatrix[n];
   ii = -Map[Total, dd];
   dd = dd + DiagonalMatrix[ii];
   dd.dd];

(* ---- 4. validation gates (iterator names differ from any local!) ---- *)
NV = 64;
xv = Cos[Range[0, NV] Pi/NV];
fv = Exp[Sin[3 xv]] + 0.3/(1 + 25 xv^2);
cv = toC[fv, NV];
sf["chk roundtrip N=64: ", tst[rmax[fromC[cv, NV], fv]]];
m5 = toC[Cos[5 Range[0, NV] Pi/NV], NV];
e5 = ConstantArray[0., NV + 1]; e5[[6]] = 1.;
sf["chk T_5 coeff extraction: ", tst[rmax[m5, e5]]];
sf["chk d1 vs d1f: ", tst[rmax[d1[cv, NV], d1f[cv, NV]]]];
NP = 16;
xp = Cos[Range[0, NP] Pi/NP];
fp = xp^4 - 2 xp^2 + 1;
sf["chk poly exactness (x^4-2x^2+1, N=16): ",
   tst[rmax[d2fast[fp, NP], N[12 xp^2 - 4]]]];
(* note: Cos[Range[0,n] Pi/n] stays EXACT in WL (Cos[Pi/16] unevaluated),
   so an exact reference trips rmax's machine guard -> N[...] it (p9g) *)
Do[Module[{nn = nn0, N1, u, xf, fast, dense, rel},
   N1 = nn - 1; xf = Cos[Range[0, N1] Pi/N1];
   u = Exp[Sin[3 xf]] + 0.3/(1 + 25 xf^2);
   fast = d2fast[u, N1];
   dense = bigD2v[nn].Reverse[u];
   rel = rmax[fast, Reverse[dense]]/If[VectorQ[dense, MachineNumberQ],
      Max[Abs[dense]], 1.];
   sf["chk fast vs dense n=", tst[nn], " rel=", tst[rel]]],
  {nn0, {33, 65, 129, 257}}];

(* ---- 5. timing table: fast (d1, d1f) vs dense matvec + build cost ---- *)
repsFor[t1_] := Max[1, Min[2000, Ceiling[0.03/t1]]];
Do[Module[{N1 = nn0 - 1, u, xf, dd, dense, fastD, fastF, t1, t2, t3, tb,
      rel, drel, reps, nn = nn0},
   xf = Cos[Range[0, N1] Pi/N1];
   u = Exp[Sin[3 xf]] + 0.3/(1 + 25 xf^2);
   t1 = AbsoluteTiming[d2fast[u, N1, d1]][[1]];
   reps = repsFor[t1];
   t1 = AbsoluteTiming[Do[d2fast[u, N1, d1], {reps}]][[1]]/reps;
   t2 = AbsoluteTiming[d2fast[u, N1, d1f]][[1]];
   reps = repsFor[t2];
   t2 = AbsoluteTiming[Do[d2fast[u, N1, d1f], {reps}]][[1]]/reps;
   tb = AbsoluteTiming[dd = bigD2v[nn]][[1]];
   dense = Dot[dd, Reverse[u]];
   t3 = AbsoluteTiming[Dot[dd, dense]][[1]];
   reps = repsFor[t3];
   t3 = AbsoluteTiming[Do[Dot[dd, dense], {reps}]][[1]]/reps;
   fastD = d2fast[u, N1, d1];
   fastF = d2fast[u, N1, d1f];
   rel = rmax[fastD, Reverse[dense]]/If[VectorQ[dense, MachineNumberQ],
      Max[Abs[dense]], 1.];
   drel = rmax[fastD, fastF];
   sf["  n=", tst[nn],
      " fast(d1)=", tst[1000 t1], "ms",
      " fast(d1f)=", tst[1000 t2], "ms",
      " denseBuild=", tst[tb], "s",
      " denseMatvec=", tst[1000 t3], "ms",
      " fastVsDense=", tst[rel],
      " d1VsD1f=", tst[drel],
      " bytesDense=", tst[ByteCount[dd]],
      " pass=", tst[And[0 <= rel < 1.*^-6, 0 <= drel < 1.*^-9]]]],
  {nn0, {65, 129, 257, 513, 1025, 2049, 4097}}];
sf["DONE-p9"];
sfClose[];
Quit[];
