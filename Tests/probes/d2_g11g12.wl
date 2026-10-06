(* D2: the last two gates -- ::ncond on a PDE-less call, and reuse of a
   pre-built discretization.  Entries are printed with ToString[..., InputForm]
   so nothing is guessed. *)
$HistoryLength = 0;
p[args___] := Print[Row[{args}]];
repo = DirectoryName[DirectoryName[DirectoryName[$InputFileName]]]; Get[FileNameJoin[{repo, "Kernel", "SpectralElement.wl"}]];
uexz[x_, y_] := Sin[2 x + 1] Cos[3 y - 1] + x y/5;
bdR = Abs[x + 1.5] < 1.*^-8 || Abs[x - 1.8] < 1.*^-8 || Abs[y + 1.2] < 1.*^-8 || Abs[y - 1.3] < 1.*^-8;
regR = Rectangle[{-1.5, -1.2}, {1.8, 1.3}];
fLin = -Laplacian[uexz[x, y], {x, y}];
eqLin = {-Laplacian[u[x, y], {x, y}] == fLin, DirichletCondition[u[x, y] == uexz[x, y], bdR]};
dump[tag_, ml_] := Module[{i}, p["  ", tag, " count=", Length[ml]]; Do[p["    [", i, "] ", StringTake[ToString[ml[[i]], InputForm], UpTo[150]]], {i, 1, Min[8, Length[ml]]}]];
p["=== G11: PDE-less call ==="];
parts0 = SpectralElement`Private`seOperatorParts[{DirichletCondition[u[x, y] == uexz[x, y], bdR]}, u, {x, y}];
p["  seOperatorParts alone -> ", Head[parts0]];
m0 = Length[$MessageList];
rN = SpectralElement`SpectralNDSolve[{DirichletCondition[u[x, y] == uexz[x, y], bdR]}, u, {x, y} \[Element] regR, 16];
dump["entries after PDE-less call", $MessageList[[m0 + 1 ;; Length[$MessageList]]]];
p["  rN === \$Failed : ", TrueQ[rN === $Failed]];
p["=== G12: reuse of a pre-built discretization ==="];
dPre = SpectralElement`SpectralDomain[regR, 16];
p["  dPre Q=", SpectralElement`SpectralDomainQ[dPre], " Degree=", Lookup[dPre, "Degree"], " Type=", Lookup[dPre, "Type"]];
m0 = Length[$MessageList];
rRe = SpectralElement`SpectralNDSolve[eqLin, u, {x, y} \[Element] dPre, 16];
iRe = SpectralElement`Private`seLastSolve;
dump["entries after reuse solve", $MessageList[[m0 + 1 ;; Length[$MessageList]]]];
p["  Head[rRe]=", Head[rRe], "  Ok=", Lookup[iRe, "Ok"], "  Reason=", Lookup[iRe, "Reason"]];
p["  same disc object?  ", TrueQ[SpectralElement`SpectralDomainQ[Lookup[iRe, "Disc"]]]];
p["  Region is dPre ?  ", TrueQ[Lookup[Lookup[iRe, "Region"], "Degree"] === 16], "  Region Degree=", Lookup[Lookup[iRe, "Region"], "Degree"]];
p["=== control: same call on the REGION shorthand ==="];
m0 = Length[$MessageList];
rCt = SpectralElement`SpectralNDSolve[eqLin, u, {x, y} \[Element] regR, 16];
dump["entries after region call", $MessageList[[m0 + 1 ;; Length[$MessageList]]]];
p["  Head[rCt]=", Head[rCt]];
p["DONE-d2_g11g12"];
