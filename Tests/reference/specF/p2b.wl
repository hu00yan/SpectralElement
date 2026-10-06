(* specF / p2b : the built-in FFT/pseudospectral route, measured.
   Fixes from p2a: (i) $MessageList must be read INSIDE Block, else it is
   the restored stale list; (ii) a PDE needs D[u[x,t],t], not u'[t]
   (u'[t] misreads the argument order -> NDSolveValue::derlen). *)
$HistoryLength = 0;
Get[FileNameJoin[{Directory[], "helpers.wl"}]];
t2[e_] := If[Head[e] === String, e, ToString[N[e], InputForm]];
tst[e_] := ToString[N[e], InputForm];
pv[r_] := r[[1]];
pv2[r_] := r[[2]];
mtxt[ms_] := If[Length[ms] === 0, "clean", t2[First[ms]]];
cls[v_] := StringJoin["K=", Head[v], " atomQ=", AtomQ[v], " len=", If[AtomQ[v], 0, Length[v]]];
ev2[expr_] := Module[{r, ms}, Block[{$MessageList = {}}, r = Quiet[expr]; ms = $MessageList]; {r, mtxt[ms]}];
probe[tag_, expr_] := Module[{r = ev2[expr]}, sf[tag, " : ", cls[pv[r]], "  msg=", pv2[r]]; Null];
nu = 1.;
TT = 0.05;
xlo = -Pi;
xhi = Pi;
mkMoM[dord_] := {"MethodOfLines", "SpatialDiscretization" -> {"TensorProductGrid", "DifferenceOrder" -> dord}};
eqs[n_] := {D[u[x, t], t] == nu D[u[x, t], x, x], u[x, 0] == Exp[-3 x^2], u[xlo, t] == u[xhi, t]};
canon[dord_, n_] := NDSolveValue[eqs[n], u, {x, xlo, xhi, n}, {t, 0, TT}, Method -> mkMoM[dord]];

(* ---- two INDEPENDENT references for the periodic heat solution ---- *)
(* refA: closed-form image sum (derived analytically) *)
refA[xx_, Tf_] := Module[{aa = 3 + 1/(4 Tf), ssum}, N[Sum[Sqrt[Pi/aa] Exp[-3 (xx + 2 Pi kk)^2/(4 Tf aa)]/Sqrt[4 Pi Tf], {kk, -6, 6}], 50]];
(* refB: truncated Fourier series with coefficients by 40-digit quadrature *)
coefB[m_] := NIntegrate[Exp[-3 zz^2] Cos[m zz], {zz, -Pi, Pi}, WorkingPrecision -> 40] / Pi;
refB[xx_, Tf_] := N[Sum[coefB[0]/2 + Sum[coefB[mm] Cos[mm xx] Exp[-mm^2 Tf], {mm, 1, 200}], 50]];
sf["P2B start ", $Version];

(* sample points: interior only (the IC has a seam jump at +-Pi) *)
xs = Table[N[xlo + (j/(65)) (xhi - xlo)], {j, 1, 64}];
sf["nsamples=", Length[xs]];
exA = refA[xs, TT];
exB = refB[xs, TT];
sf["REFERENCE self-check max|refA-refB| = ", tst[Max[Abs[exA - exB]]]];
sf["REFERENCE rel diff = ", tst[Norm[exA - exB]/Norm[exA]]];
sf["ref norm = ", tst[Norm[exA]]];

(* ---- sanity: does the returned object evaluate? ---- *)
{s1, m1} = ev2[canon["Pseudospectral", 65]];
sf["SOLVE n=65 : ", cls[pv[s1]], " msg=", pv2[s1]];
Do[Module[{v = Quiet[pv[s1][xs[[jj]], TT]]}, sf["   x=", tst[xs[[jj]]], " got=", tst[v]]], {jj, {1, 32, 64}}];
sf["S1 done"];

(* ---- error vs spatial resolution ---- *)
relerr[a_, b_] := Norm[N[a - b]]/Norm[N[b]];
sweepone[dord_, n_] := Module[{r = ev2[canon[dord, n]], sol = pv[r], vals, tm}, If[TrueQ[AtomQ[sol]], sf["SWEEP dord=", tst[dord], " n=", n, " -> ATOMIC ", cls[sol], " msg=", pv2[r]], tm = AbsoluteTiming[vals = N[sol[xs, TT]]]; sf["SWEEP dord=", tst[dord], " n=", n, " err=", tst[relerr[vals, exA]], " sec=", tst[tm[[1]]]]]];
Do[sweepone["Pseudospectral", n], {n, {17, 25, 33, 49, 65, 97, 129, 193, 257}}];
sf["S2 done"];

(* ---- second-order FD for contrast (same grid machinery) ---- *)
Do[sweepone[2, n], {n, {17, 33, 65, 129, 257}}];
sf["S3 done"];

(* ---- DIAGONAL TEST: is the pseudospectral D2 a diagonal operator? ---- *)
g17 = uGrid[xlo, xhi, 17];
fsp = NDSolve`FiniteDifferenceDerivative[2, g17, "DifferenceOrder" -> "Pseudospectral", PeriodicInterpolation -> True];
ffd = NDSolve`FiniteDifferenceDerivative[2, g17, "DifferenceOrder" -> 2, PeriodicInterpolation -> True];
colprobe[fp_, jj_] := Module[{ek = UnitVector[17, jj], out}, out = Quiet[fp[ek]]; If[TrueQ[AtomQ[out]], sf["  col ", jj, " ATOMIC ", cls[out]], sf["  col ", jj, " nnz=", tst[Length[Select[Range[17], Abs[# out[[#]]] > 1.0*^-12 &]]], " diagval=", tst[N[out[[jj]]]]]]];
sf["DIAG pseudospectral: nonzero per column (dense => >1, diagonal => 1)"];
Do[colprobe[fsp, jj], {jj, {1, 5, 9, 17}}];
sf["DIAG finite-diff order 2:"];
Do[colprobe[ffd, jj], {jj, {1, 5, 9, 17}}];
sf["S4 done"];

(* ---- is the pseudospectral D2 truly diagonal?  value pattern ---- *)
sf["fsp applied to ones = ", tst[Quiet[fsp[ConstantArray[1., 17]]]]];
sf["ffd applied to ones = ", tst[Quiet[ffd[ConstantArray[1., 17]]]]];
sf["S5 done"];

sf["DONE-p2b"];
sfClose[];
Quit[];