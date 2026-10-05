(* D2: audit the messages the NONLINEAR public path emits (gate G6h needs
   the answer, and an unexplained Part:: is a real defect). *)
$HistoryLength = 0;
p[args___] := Print[Row[{args}]];
Get["/Users/huyan00/mycode/SpectralElement/Kernel/SpectralElement.wl"];
uexz[x_, y_] := Sin[2 x + 1] Cos[3 y - 1] + x y/5;
bdR = Abs[x + 1.5] < 1.*^-8 || Abs[x - 1.8] < 1.*^-8 || Abs[y + 1.2] < 1.*^-8 || Abs[y - 1.3] < 1.*^-8;
regR = Rectangle[{-1.5, -1.2}, {1.8, 1.3}];
fLin = -Laplacian[uexz[x, y], {x, y}];
fNl = -Laplacian[uexz[x, y], {x, y}] + uexz[x, y]^3;
eqLin = {-Laplacian[u[x, y], {x, y}] == fLin, DirichletCondition[u[x, y] == uexz[x, y], bdR]};
eqNl = {-Laplacian[u[x, y], {x, y}] + u[x, y]^3 == fNl, DirichletCondition[u[x, y] == uexz[x, y], bdR]};
aud[tag_, eq_, n_] := Module[{m0, ml, nn}, m0 = Length[$MessageList]; Quiet[Check[SpectralElement`SpectralNDSolve[eq, u, {x, y} \[Element] regR, n, MaxIterations -> 8], $Failed]]; ml = $MessageList[[m0 + 1 ;; Length[$MessageList]]]; nn = Sort[DeleteDuplicates[Cases[ml, HoldForm[MessageName[s_, t___]] :> s]]]; p["  ", tag, " n=", n, "  newMessages=", Length[ml], "  names=", nn]; Do[p["      ", ToString[ml[[i]], InputForm]], {i, 1, Min[3, Length[ml]]}]];
p["--- LINEAR ---"];
aud["LIN", eqLin, 8];
p["--- NONLINEAR ---"];
aud["NL", eqNl, 8];
p["--- NONLINEAR again (is it first-call only?) ---"];
aud["NL2", eqNl, 8];
p["--- NONLINEAR at n=10 ---"];
aud["NL10", eqNl, 10];
p["--- discrete domain build, un-Quieted, LINEAR problem ---"];
aud["LINdisc", eqLin, 6];
p["DONE-d2_msgaudit"];
