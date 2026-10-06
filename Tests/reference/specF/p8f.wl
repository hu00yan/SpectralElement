(* pin down Mathematica's Fourier convention + storage order *)
$HistoryLength = 0;
Get[FileNameJoin[{Directory[], "helpers.wl"}]];
tst[e_] := ToString[N[e], InputForm];
f8 = N[{1, 2, 3, 4, 5, 6, 7, 8}];
F8 = Fourier[f8];
sf["Fourier[{1..8}] real parts: ", tst[Re[F8]]];
sf["Fourier[{1..8}] imag parts: ", tst[Im[F8]]];
n = 8;
(* reconstruction both signs, plain FFT-order pairing 0..3,-4..-1 *)
kw = Join[Range[0, Floor[n/2]], -Range[Ceiling[n/2] - 1, 1, -1]];
sf["kw = ", tst[N[kw]]];
recP = Table[Re[Sum[F8[[mm]] Exp[2 Pi I kw[[mm]] (j - 1)/n], {mm, n}]/n], {j, 1, n}];
recM = Table[Re[Sum[F8[[mm]] Exp[-2 Pi I kw[[mm]] (j - 1)/n], {mm, n}]/n], {j, 1, n}];
sf["orig          = ", tst[f8]];
sf["rec(+sign)    = ", tst[recP], "  maxerr=", tst[Max[Abs[recP - f8]]]];
sf["rec(-sign)    = ", tst[recM], "  maxerr=", tst[Max[Abs[recM - f8]]]];
(* asymmetric delta: which slot gets the unit magnitude? *)
d = N[{0, 1, 0, 0, 0, 0, 0, 0}];
Fd = Fourier[d];
sf["Fourier[delta@2] |.| = ", tst[Abs[Fd]], "  arg/pi = ", tst[Arg[Fd]/Pi]];
(* also check: does our rFFT structure work at TT=0 for a NON-symmetric grid fn? *)
sfClose[];
Quit[];
