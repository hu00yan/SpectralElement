(* D2 diagnostic 2: literal context spelling vs shorthand PR. *)
$HistoryLength = 0;
p[args___] := Print[Row[{args}]];
Get["/path/to/SpectralElement/Kernel/SpectralElement.wl"];
PR = SpectralElement`Private;
p["1 ToString PR = ", ToString[PR, InputForm]];
p["2 Context PR = ", Context[PR]];
p["3 ContextPath[] = ", ContextPath[]];
p["4 Context of public = ", Context[SpectralElement`SpectralDomain]];
p["5 nNames literal = ", Length[Names["SpectralElement`Private`se*"]]];
p["6 nNames PR pattern = ", Length[Names["PR`se*"]]];
p["7 literal apply = ", SpectralElement`Private`seNodeVec[{{1., 2.}, {3., 4.}}]];
p["8 PR apply = ", PR`seNodeVec[{{1., 2.}, {3., 4.}}]];
p["9 literal downvalues = ", Length[DownValues[SpectralElement`Private`seNodeVec]]];
p["10 PR downvalues = ", Length[DownValues[PR`seNodeVec]]];
p["11 sameQ = ", SameQ[SpectralElement`Private`seNodeVec, PR`seNodeVec]];
p["12 bare apply = ", seNodeVec[{{1., 2.}, {3., 4.}}]];
p["13 bare context = ", Context[seNodeVec]];
p["DONE-d2_diag2"];
