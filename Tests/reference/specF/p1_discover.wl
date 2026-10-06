(* specF / p1 : DISCOVERY of the built-in route.
   STRICT one-statement-per-line so the per-line bracket audit is exact.
   NOTE: Quiet[Check[expr,$Failed,mm]] returns the UNEVALUATED Check
   when no message fires -> useless as an acceptance test.
   Use $MessageList capture instead.  All output is a STRING. *)
$HistoryLength = 0;
Get[FileNameJoin[{Directory[], "helpers.wl"}]];
t2[e_] := If[Head[e] === String, e, ToString[N[e], InputForm]].
ev2[expr_] := Module[{r, ms}, Block[{$MessageList = {}}, r = Quiet[expr]]; ms = $MessageList; {r, If[Length[ms] === 0, "clean", t2[First[ms]]]}].
cls[v_] := If[TrueQ[v === $Failed], "FAILED", If[TrueQ[AtomQ[v]], "ATOMIC:" <> Head[v], "LIST len=" <> ToString[Length[v]] <> " head=" <> Head[v]]];
dmp[tag_, lst_] := Do[sf["   ", tag, " ", t2[lst[[i]]]], {i, 1, Length[lst]}].
asym[m_] := If[MatrixQ[m], t2[N[Max[Abs[N[m + Transpose[m]]]]]], "notmatrix"];
dimsof[m_] := If[MatrixQ[m], ToString[Dimensions[m]], "notmatrix"];
nu = 1.;
TT = 0.05;
mkHeat[dord_, extra_] := {"MethodOfLines", "SpatialDiscretization" -> Join[{"TensorProductGrid", "DifferenceOrder" -> dord}, extra]}.
sf["kernel ", $Version].
sf["S0 start"].

(* ---- A: heat eq, periodic BC, documented FFT/pseudospectral route ---- *)
{rA, mA} = ev2[NDSolveValue[{u'[t] == nu u''[x], u[x, 0] == Exp[-3 x^2], u[-Pi, t] == u[Pi, t]}, u[x, TT], {x, -Pi, Pi}, Method -> mkHeat["Pseudospectral", {}]]].
sf["A heat+periodic+Pseudospectral : ", cls[rA], "  msg=", mA].
If[!TrueQ[rA === $Failed] && !TrueQ[AtomQ[rA]], sf["   A first3=", t2[Take[rA, 3]]]].
sf["S-A done"].

(* ---- B: same route but with Dirichlet ends instead of periodic ------- *)
{rB, mB} = ev2[NDSolveValue[{u'[t] == nu u''[x], u[x, 0] == Exp[-3 x^2], u[-Pi, t] == 0, u[Pi, t] == 0}, u[x, TT], {x, -Pi, Pi}, Method -> mkHeat["Pseudospectral", {}]]].
sf["B heat+Dirichlet+Pseudospectral : ", cls[rB], "  msg=", mB].
sf["S-B done"].

(* ---- C: periodic BC with DEFAULT MethodOfLines (is FFT the default?) -- *)
{rC, mC} = ev2[NDSolveValue[{u'[t] == nu u''[x], u[x, 0] == Exp[-3 x^2], u[-Pi, t] == u[Pi, t]}, u[x, TT], {x, -Pi, Pi}, Method -> "MethodOfLines"]].
sf["C heat+periodic+defaultMoM : ", cls[rC], "  msg=", mC].
sf["S-C done"].

(* ---- D: NDSolve object form, to inspect the grid it reports ----------- *)
rD = ev2[NDSolve[{u'[t] == nu u''[x], u[x, 0] == Exp[-3 x^2], u[-Pi, t] == u[Pi, t]}, u, {x, -Pi, Pi, 20}, {t, 0, TT}, Method -> mkHeat["Pseudospectral", {}]]].
sf["D NDSolve(obj) : ", cls[rD[[1]]], " msg=", rD[[2]]].
sf["S-D done"].

(* ---- E: do the candidate grid-type SYMBOLS exist at all? -------------- *)
cands = {"TensorProductGrid", "FiniteDifferenceGrid", "FiniteElementGrid", "ChebyshevGrid", "ClenshawCurtisGrid", "PeriodicGrid", "Pseudospectral", "SpectralGrid", "FiniteVolumeGrid", "CartesianGrid", "UniformGrid", "Grid"}.
Do[Module[{s = Symbol[cands[[i]]]}, sf["E sym ", cands[[i]], " ctx=", Context[s], " ownv=", Length[OwnValues[Unevaluated[s]]]]], {i, Length[cands]}].
sf["S-E done"].

(* ---- F: NDSolve`FiniteDifferenceDerivative with Pseudospectral --------- *)
g = uGrid[-Pi, Pi, 17].
fdprobe[d_] := Module[{r, ms}, Block[{$MessageList = {}}, r = Quiet[NDSolve`FiniteDifferenceDerivative[2, g, "DifferenceOrder" -> d, PeriodicInterpolation -> True]]]; ms = $MessageList; sf["F NDDeriv DOrder=", ToString[d, InputForm], " : ", cls[r], " msg=", If[Length[ms] === 0, "clean", t2[First[ms]]], " dim=", dimsof[r], " asym=", asym[r]]].
Do[fdprobe[d], {d, {"Pseudospectral", "FiniteDifference", 2, 4}}].
sf["S-F1 done"].
ov = ev2[Options[NDSolve`FiniteDifferenceDerivative]].
sf["F opts count: ", cls[ov[[1]]], " msg=", ov[[2]]].
If[!TrueQ[ov[[1]] === $Failed], dmp["NDDopt", ov[[1]]]].
sf["S-F done"].

(* ---- G: internal grid maker symbols ---------------------------------- *)
mkprobe[i_] := Module[{r, ms}, Block[{$MessageList = {}}, r = Quiet[NDSolve`FiniteDifference`TensorProductGrid[{"TensorProductGrid", "DifferenceOrder" -> 2}, {-Pi, Pi, 17}]]]]; ms = $MessageList; sf["G mk : ", cls[r], " msg=", If[Length[ms] === 0, "clean", t2[First[ms]]]];
Do[mkprobe[i], {i, 1}].
sf["S-G done"].

sf["DONE-p1"];
sfClose[];
Quit[];