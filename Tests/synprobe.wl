(* synprobe.wl -- parse check only: Get the four kernel files (top level is
   definitions, so a Get is safe and reports Syntax::sntx WITH line numbers),
   then SyntaxQ the probe scripts without executing them. Evidence via SPECF_OUT. *)
sfLog = If[StringQ[Environment["SPECF_OUT"]], Environment["SPECF_OUT"],
   "Tests/out/synprobe.txt"];
sfStream = OpenWrite[sfLog];
w[s_] := WriteString[sfStream, s <> "\n"];

kfiles = {"Kernel/SpectralElement.wl", "Kernel/AAA.wl",
   "Kernel/Geometry.wl", "Kernel/Discretization.wl", "Kernel/Solve.wl"};

Do[
  w["=== GET " <> f];
  Check[Get[f], w["SYNTAX-ERR-IN " <> f], Syntax::sntx];
  w["GET-OK " <> f];
  ,
  {f, kfiles}
];

pfiles = {"Tests/aaaprobe.wl", "Tests/loadprobe.wl", "Tests/synprobe.wl",
   "PacletInfo.wl"};
Do[
  w["=== SYNTAXQ " <> f <> " ==> " <> ToString[SyntaxQ[Import[f, "String"]]]];
  ,
  {f, pfiles}
];

w["SYNPROBE-DONE"];
Close[sfStream];
Print["SYNPROBE-DONE"];
