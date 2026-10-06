(* specF / m2 : verify the fix -- ; terminators only, never a bare "." *)
$HistoryLength = 0;
Get[FileNameJoin[{Directory[], "helpers.wl"}]];
sf["M2 line1 version ", $Version];
sf["M2 line2 start"];
t2[e_] := If[Head[e] === String, e, ToString[N[e], InputForm]];
sf["M2 line3 after t2 def"];
cls[v_] := If[TrueQ[v === $Failed], "FAILED", If[TrueQ[AtomQ[v]], "ATOMIC:" <> Head[v], "LIST len=" <> ToString[Length[v]] <> " head=" <> Head[v]]];
sf["M2 line4 after cls def"];
nu = 1.;
TT = 0.05;
sf["M2 line5 nu=", nu, " TT=", TT];
ev2[expr_] := Module[{r, ms}, Block[{$MessageList = {}}, r = Quiet[expr]]; ms = $MessageList; {r, If[Length[ms] === 0, "clean", t2[First[ms]]]}];
sf["M2 line6 after ev2 def"];
sf["DONE-m2"];
sfClose[];
Quit[];