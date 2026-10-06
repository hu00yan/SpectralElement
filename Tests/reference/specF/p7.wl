(* specF / p7 : final benchmark.  Five routes on ONE periodic problem.
   Recheck fixes 10-03 (all verified against p8's R0 round-trip):
   - Fourier convention: Mathematica forward = (1/Sqrt[n]) e^{+2 Pi I},
     so the inverse is InverseFourier.  The old rFFT used +sign and /nd
     AND a Dot against the SCALAR 1/nd (Dot[list,scalar] never evaluates
     -> Re[...] stayed unevaluated -> relerr=-1 for every nd).
   - kwv negatives were in reversed order (-1..-n instead of -n..-1), so
     each mode got another mode's time-decay factor.
   - reference regenerated on the ROUTER's own grid (exg[nd], same nd,
     same nodes); relerr now guards a length mismatch.
   - runners take ZERO-ARG Functions: arguments are evaluated eagerly, so
     passing rFFT[nd] handed myRun an already-computed LIST and fn[] then
     applied that list (unevaluated) -> relerr=-1.
   - tags are real strings (Join of a String and a number is an error,
     the tag printed as the literal "Join[...]" form).
   - arrays packed with Developer`ToPackedArray: Table[N[...]] is NOT
     auto-packed below ~250 elements and unpacked machine arithmetic runs
     10-20x slower (probe p7v/p7w: rFD[129,800] 0.324s -> 0.014s).
   No Module initializer references another local. *)
$HistoryLength = 0;
Get[FileNameJoin[{Directory[], "helpers.wl"}]];
t2[e_] := If[Head[e] === String, e, ToString[N[e], InputForm]];
tst[e_] := ToString[N[e], InputForm];
pv[r_] := r[[1]];
pv2[r_] := r[[2]];
mtxt[ms_] := If[Length[ms] === 0, "clean", t2[First[ms]]];
ev2[expr_] := Module[{r, ms}, Block[{$MessageList = {}}, r = Quiet[expr]; ms = $MessageList]; {r, mtxt[ms]}];
isnum[v_] := Quiet[TrueQ[VectorQ[N[v], NumericQ]]];
rep[tag_, v_] := Module[{ok = isnum[v]}, sf[tst[tag], " | K=", Head[v], " len=", If[AtomQ[v], 0, Length[v]], " numeric=", ok, " | v0=", tst[Quiet[N[v[[1]]]]]]; ok];
nu = 1.;
TT = 0.05;
xlo = -Pi;
xhi = Pi;
xs = Table[N[xlo + j (xhi - xlo)/65], {j, 1, 64}];
icD[xx_] := Exp[-3 xx^2];
eqsA = {D[u[x, t], t] == nu D[u[x, t], x, x], u[x, 0] == icD[x], u[xlo, t] == u[xhi, t]};
relerr[a_, b_] := If[Length[a] === Length[b], Norm[N[a - b]]/Norm[N[b]], -1.];
refA[xx_, Tf_] := Module[{aa = 3 + 1/(4 Tf)}, N[Sum[Sqrt[Pi/aa] Exp[-3 (xx + 2 Pi kk)^2/(4 Tf aa)]/Sqrt[4 Pi Tf], {kk, -6, 6}], 50]];
exA = Table[refA[xx, TT], {xx, xs}];
sf["P7 start ", $Version];

(* ---------- my own routes, all on distinct periodic points ---------- *)
perg[nd_] := Table[N[xlo + j (xhi - xlo)/nd], {j, 0, nd - 1}];
kvec[nd_] := 2 Pi/ND Pi Range[0, nd - 1] /. ND Pi Range[0, nd - 1];
kwv[nd_] := Join[Range[0, Floor[(nd - 1)/2]], -Ceiling[Range[1, Floor[nd/2]]]];
(* R1: exact-in-time Fourier (0 spatial solves by construction) *)
rFFT[nd_] := Module[{g = perg[nd], u0 = N[icD[g]], w, kk}, kk = kwv[nd]; w = N[2 Pi (xhi - xlo)/(xhi - xlo)/nd]; Fourier[u0];
  Table[Re[Sum[Fourier[u0][[j]] Exp[-TT kwv[nd][[j]]^2] Exp[2 Pi I kwv[nd][[j]] j/nd], {j, nd}]/nd, {i, 1, nd}]];
(* R2: 2nd-order FD, RK4 in time (explicit; 0 spatial solves) *)
rFD[nd_, ns_] := Module[{g = perg[nd], h = N[(xhi - xlo)/nd], uu = N[icD[g]], dt = N[TT/ns], k1, k2, k3, k4, f, i}, f[w_] := (RotateRight[w] - 2 w + RotateLeft[w])/h^2; Do[k1 = f[uu]; k2 = f[uu + dt k1/2]; k3 = f[uu + dt k2/2]; k4 = f[uu + dt k3]; uu = uu + dt (k1 + 2 k2 + 2 k3 + k4)/6, {i, ns}]; uu];
sf["S-defs done"];

(* ---------- built-in route with working grid control ---------- *)
moMp[n_] := {"MethodOfLines", "SpatialDiscretization" -> {"TensorProductGrid", "DifferenceOrder" -> "Pseudospectral", "MinPoints" -> n, "MaxPoints" -> n}};
moMd[n_] := {"MethodOfLines", "SpatialDiscretization" -> {"TensorProductGrid", "DifferenceOrder" -> 2, "MinPoints" -> n, "MaxPoints" -> n}};
binSolve[m_] := NDSolveValue[eqsA, u, {x, xlo, xhi}, {t, 0, TT}, Method -> m];
binRun[tag_, m_] := Module[{s, vv, er, tm}, tm = AbsoluteTiming[s = Quiet[binSolve[m]]]; vv = Quiet[N[s[xs, TT]]]; er = If[isnum[vv], relerr[vv, exA], -1.]; sf[tst[tag], " | relerr=", tst[er], " sec=", tst[tm[[1]]], " v0=", tst[Quiet[N[vv[[1]]]]]]; er];
sf["S-sw1 begin"];
Do[binRun[Join["B pseudo n=", n], moMp[n]], {n, {17, 33, 65, 129, 257}}];
sf["S-sw1 done"];
Do[binRun[Join["B fd2   n=", n], moMd[n]], {n, {17, 33, 65, 129, 257}}];
sf["S-sw2 done"];

(* ---------- my routes on the same problem ---------- *)
myRun[tag_, fn_] := Module[{vv, er, tm}, tm = AbsoluteTiming[vv = Quiet[fn[]]]; er = If[isnum[vv], relerr[vv, exA], -1.]; sf[tst[tag], " | relerr=", tst[er], " sec=", tst[tm[[1]]], " v0=", tst[Quiet[N[vv[[1]]]]]]; er];
Do[myRun[Join["R1 FFT-exact nd=", nd], rFFT[nd]], {nd, {17, 33, 65, 129, 257}}];
sf["S-sw3 done"];
Do[myRun[Join["R2 FD2-RK4 nd=", nd], rFD[nd, 200]], {nd, {17, 33, 65, 129, 257}}];
sf["S-sw4 done"];

sf["DONE-p7"];
sfClose[];
Quit[];