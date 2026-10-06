(* ============ specF shared helpers -- VERIFIED, single source ============
   Learned the hard way:
     - ToString[s_String, InputForm] ESCAPES the quotes -> t[] passes
       strings through untouched.
     - PadRight pads LIST LENGTH, not element width; and it needs a
       list.  StringPadRight is the right tool for a scalar column.
     - Round[x, 3] rounds to 3 DECIMAL PLACES, so 1e-16 prints as 0.
       f[] below rounds to 3 SIGNIFICANT digits and NEVER prints a
       non-numeric (printing one segfaulted the kernel, RC=139).
     - "Pseudospectral" + PeriodicInterpolation->True treats the grid as
       PERIODIC WITH PERIOD (last - first).  A grid with
       n*h != last-first silently returns garbage.  uGrid below always
       has first == last.  CGL grids always have first == last too.
   ====================================================================== *)

t[e_] := If[Head[e] === String, e, ToString[N[e], InputForm]];
pw[s_] := StringPadRight[t[s], 14, " "];
row[args___] := StringJoin[pw /@ (t /@ {args})];

f[e_, d_: 3] := Module[{v = Quiet[Check[N[e], $Failed]], m, ex},
   If[!TrueQ[NumericQ[v]], Return["NONNUM"]];
   If[TrueQ[v == 0], Return["0"]];
   m = Abs[N[v]];
   ex = Floor[Log[10, m]];
   t[N[Sign[N[v]]*Round[m/10^ex, 10^(1 - d)]*10^ex]]];
fi[e_] := t[e];

(* ---- grids : first point == last point (the periodic convention) --- *)
uGrid[a_, b_, n_Integer?Positive] :=
  Table[N[a + j (b - a)/(n - 1)], {j, 0, n - 1}];
cglGrid[a_, b_, n_Integer?Positive] :=
  Reverse[Table[N[(a + b)/2 + (b - a)/2 Cos[Pi j/(n - 1)], {j, 0, n - 1}]]];

ev[expr_, g_List] := Table[N[expr /. z -> g[[j]]], {j, 1, Length[g]}];
evf[fn_, g_List] := N[fn] /@ g;

optPSU = {"DifferenceOrder" -> "Pseudospectral", PeriodicInterpolation -> True};
optPSC = {"DifferenceOrder" -> "Pseudospectral"};

tryIt[e_] := Quiet[Check[e, $Failed]];
probe[e_] := Module[{mm = {}, rr = Quiet[Check[e, $Failed, mm]]},
  {rr, If[mm === {}, "clean", StringTake[t[First[mm]], 200]]}];
say[pr_] := If[TrueQ[pr[[1]] === $Failed], "REJECTED", "accepted"];

(* truncated Fourier series with a_m = Exp[-m^2/4]; used for the
   roundoff floor, where truncation and aliasing are both zero *)
(* u(xi) = Sum_{m=-M}^{M} a_m cos(m xi), a_m = Exp[-m^2/4]; purely REAL
   and period-1 on a grid of period-1 points.  Its xi-derivative is
   -2 Sum_{m=1}^{M} m a_m sin(m xi).  Getting the reference wrong here
   cost one run (the error came out at 19.1, i.e. the size of the
   answer).  M must be a MACHINE INTEGER. *)
serU[xi_, M_Integer] := N[1 + 2 Sum[Exp[-m^2/4] Cos[m xi], {m, 1, M}], 60];
serD[xi_, M_Integer] := N[-2 Sum[m Exp[-m^2/4] Sin[m xi], {m, 1, M}], 60];

(* hand-built dense spectral 1st derivative on a periodic uniform grid *)
kWave[n_Integer?EvenQ] := Join[Range[0, n/2 - 1], {n/2 - n}, Range[n/2 - 1, 1, -1]];
kWave[n_Integer?OddQ] := Join[Range[0, (n - 1)/2], Table[-m, {m, (n - 1)/2, 1, -1}]];
specD[lo_, hi_, n_Integer?Positive] := Module[{kk, L = hi - lo, jj, ph},
  kk = kWave[n];
  jj = Range[0, n - 1];
  ph = Table[N[Exp[2 Pi I kk[[i]] jj[[j]]/n]], {i, 1, n}, {j, 1, n}];
  ConjugateTranspose[ph].DiagonalMatrix[N[2 Pi I kk/L]].ph/n];

(* EXACT Fourier derivative of a period-L function from the nd = n-1
   DISTINCT samples of an n-point grid whose first==last point *)
mySpec[L_, n_] := Module[{nd = n - 1, kk, jj, ph},
  kk = kWave[nd];
  jj = Range[0, nd - 1];
  ph = Table[N[Exp[2 Pi I kk[[i]] jj[[j]]/nd]], {i, 1, nd}, {j, 1, nd}];
  ConjugateTranspose[ph].DiagonalMatrix[N[2 Pi I kk/L]].ph/nd];

(* grid-free logging.  OpenWrite TRUNCATES, so if a second kernel of the
   same script is alive (wolframscript retry / stale run) it wipes the
   first run's output and you get only the tail.  Hence a PER-RUN unique
   path supplied by the runner in $SPECF_OUT. *)
sfLog = If[StringQ[Environment["SPECF_OUT"]], Environment["SPECF_OUT"], FileNameJoin[{Directory[], "sf_run.log"}]];
sfStream = OpenWrite[sfLog];
sfSafe[e_] := Module[{s = t[e]}, If[StringLength[s] > 240, StringTake[s, 240] <> "..TRUNC", s]];
sf[args___] := (WriteString[sfStream, StringJoin[sfSafe /@ {args}] <> "\n"];
   Flush[sfStream]; Print[Row[{args}]]);
sfClose[] := (Close[sfStream]; Null);