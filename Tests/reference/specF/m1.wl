(* specF / m1 : minimal bisect probe *)
$HistoryLength = 0;
Get[FileNameJoin[{Directory[], "helpers.wl"}]];
sf["M1 line1 version ", $Version].
sf["M1 line2 start"].
t2[e_] := If[Head[e] === String, e, ToString[N[e], InputForm]].
sf["M1 line3 after t2 def"].
cls[v_] := If[TrueQ[v === $Failed], "FAILED", If[TrueQ[AtomQ[v]], "ATOMIC:" <> Head[v], "LIST len=" <> ToString[Length[v]] <> " head=" <> Head[v]]];
sf["M1 line4 after cls def"].
nu = 1.;
TT = 0.05;
sf["M1 line5 nu=", nu, " TT=", TT].
mkHeat[dord_, extra_] := {"MethodOfLines", "SpatialDiscretization" -> Join[{"TensorProductGrid", "DifferenceOrder" -> dord}, extra]}.
sf["M1 line6 after mkHeat def"].
ev2[expr_] := Module[{r, ms}, Block[{$MessageList = {}}, r = Quiet[expr]]; ms = $MessageList; {r, If[Length[ms] === 0, "clean", t2[First[ms]]]}].
sf["M1 line7 after ev2 def"].
sf["DONE-m1"];
sfClose[];
Quit[];