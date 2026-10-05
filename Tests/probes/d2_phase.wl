(* D2: which PHASE of the degree-16 Rectangle solve emits Part::partw /
   Part::partd.  seEnsureDisc already quiets those tags around the
   SpectralDomain call, and Quiet does NOT record into $MessageList, so a
   message that IS in $MessageList cannot have come from there. *)
$HistoryLength = 0;
p[args___] := Print[Row[{args}]];
Get["/Users/huyan00/mycode/SpectralElement/Kernel/SpectralElement.wl"];
uexz[x_, y_] := Sin[2 x + 1] Cos[3 y - 1] + x y/5;
bdR = Abs[x + 1.5] < 1.*^-8 || Abs[x - 1.8] < 1.*^-8 || Abs[y + 1.2] < 1.*^-8 || Abs[y - 1.3] < 1.*^-8;
regR = Rectangle[{-1.5, -1.2}, {1.8, 1.3}];
fLin = -Laplacian[uexz[x, y], {x, y}];
eqLin = {-Laplacian[u[x, y], {x, y}] == fLin, DirichletCondition[u[x, y] == uexz[x, y], bdR]};
phase[tag_, expr_] := Module[{m0 = Length[$MessageList], r, ml}, r = Quiet[Check[expr, $Failed]]; ml = $MessageList[[m0 + 1 ;; Length[$MessageList]]]; p["  ", StringPad[tag, 26], " newMsgs=", Length[ml], "  tags=", DeleteDuplicates[Cases[ml, HoldForm[h_] :> h, {1}]]]; r];
p["=== degree 16, phase by phase ==="];
disc = phase["SpectralDomain", SpectralElement`SpectralDomain[regR, 16]];
parts = phase["seOperatorParts", SpectralElement`Private`seOperatorParts[eqLin, u, {x, y}]];
dc = phase["seDirConditions", SpectralElement`Private`seDirConditions[eqLin, u, {x, y}]];
lfFn = phase["seDirLiftFn", SpectralElement`Private`seDirLiftFn[dc, x, y]];
lf = phase["seLiftFrom", SpectralElement`Private`seLiftFrom[disc, lfFn]];
A0 = phase["seStackOperator", SpectralElement`Private`seStackOperator[disc, -1.]];
c0 = phase["seLiftConst", SpectralElement`Private`seLiftConst[disc, -1., lf]];
rhs = phase["seAssembleRHS", SpectralElement`Private`seAssembleRHS[disc, fLin, x, y]];
z = phase["seLinSolve", SpectralElement`Private`seLinSolve[A0, rhs - c0]];
fn = phase["seSolutionFn", SpectralElement`Private`seSolutionFn[disc, z, lf]];
p["=== now the public call, which must be silent ==="];
m0 = Length[$MessageList];
pub = SpectralElement`SpectralNDSolve[eqLin, u, {x, y} \[Element] regR, 16];
p["  public newMsgs=", Length[$MessageList[[m0 + 1 ;; Length[$MessageList]]]], "  tags=", DeleteDuplicates[Cases[$MessageList[[m0 + 1 ;; Length[$MessageList]]], HoldForm[h_] :> h, {1}]]];
p["=== same at degree 15 (is it degree-specific?) ==="];
m0 = Length[$MessageList];
Quiet[SpectralElement`SpectralNDSolve[eqLin, u, {x, y} \[Element] regR, 15]];
p["  n=15 newMsgs=", Length[$MessageList[[m0 + 1 ;; Length[$MessageList]]]]];
p["DONE-d2_phase"];
