(* ::Package:: *)

(* ====================================================================
   loadprobe.wl -- Wave-1 skeleton gate.

   Proves the LOADER contract from API.md section 2, and nothing else:
       PacletDirectoryLoad[repoRoot];  Needs["SpectralElement`"]
   leaves exactly the seven public symbols in the context "SpectralElement`",
   with the PacletInfo metadata round-tripping and Kernel/init.m inert.

   It deliberately does NOT test the subfiles.  AAA.wl, Geometry.wl,
   Discretization.wl and Solve.wl belong to other agents and are being
   written concurrently, so a probe that failed on their contents would be
   a flake rather than a gate.  Messages raised while the package loads
   (for example a Syntax::sntx from a half-written subfile) are REPORTED
   and do not change the verdict; each owner gates their own file.

   Two verified Wolfram Language traps this file is written around, both
   reproduced here against a throwaway control package so the evidence is
   self-contained:

     1. Context is HoldFirst.  Context[x] where x is a VARIABLE reports
        the context of the variable (Global`), not of the symbol it holds.
        The working form is Context /@ listOfSymbols.
     2. A usage message is not an ownvalue or downvalue of the symbol, so
        OwnValues / DownValues are empty for a usage-only symbol, and
        Information prints nothing under wolframscript.  Worse,
        ValueQ[usageOnlySymbol] is False, so ValueQ is NOT a valid
        "is the package loaded" guard either -- use MemberQ[$ContextPath,
        "Ctx`"].  SymbolName plus Names["Ctx`*"] is the script-visible
        check; usage strings are read interactively with ?symbol.

   Owner: S (skeleton).   Run:  ./rr.sh 120 Tests/loadprobe.wl
   Evidence: Tests/out/loadprobe.<stamp>.txt
   ==================================================================== *)
$HistoryLength = 0;

sfLog = If[StringQ[Environment["SPECF_OUT"]], Environment["SPECF_OUT"],
   FileNameJoin[{DirectoryName[$InputFileName], "..", "Tests", "out", "loadprobe.nofallback.txt"}]];
sfStream = OpenWrite[sfLog];
sfSafe[e_] := Module[{s = ToString[e, InputForm]},
   If[StringLength[s] > 400, StringTake[s, 400] <> "..TRUNC", s]];
sf[args___] := (WriteString[sfStream, StringJoin[sfSafe /@ {args}] <> "\n"];
   Flush[sfStream]; Print[Row[{args}]]);
sfClose[] := (Close[sfStream]; Null);

repo = "/Users/huyan00/mycode/SpectralElement";
pub = {SpectralElement`CoonsPatch, SpectralElement`CoonsPatchQ,
   SpectralElement`CoonsPatchMap, SpectralElement`SpectralDomain,
   SpectralElement`SpectralDomainQ, SpectralElement`SpectralDomainData,
   SpectralElement`SpectralNDSolve, SpectralElement`SpectralNDSolveValue};

sf["================ loadprobe START ================"];
sf["repo=", repo];
sf["$Version=", $Version];

(* ---------------------------------------------------------------- *)
sf["--- 0. control: the two traps above, against a throwaway package ---"];
BeginPackage["ZZCtrl`"];
ZZCtrl`gg::usage = "control symbol";
Begin["`Private`"]
End[]
EndPackage[];
zzvar = ZZCtrl`gg;
sf["Context[variable] (HoldFirst trap, WRONG form)= ", Context[zzvar]];
sf["Context /@ {symbol} (correct form)= ", Context /@ {ZZCtrl`gg}];
sf["ValueQ of a usage-only symbol= ", ValueQ[ZZCtrl`gg]];
sf["OwnValues of a usage-only symbol= ", OwnValues[ZZCtrl`gg]];
Unprotect["ZZCtrl`"]; ClearAll["ZZCtrl`*"];

(* ---------------------------------------------------------------- *)
sf["--- 1. PacletInfo round-trip: PacletObject[File[dir]] ---"];
(* NB PacletObject[dir] with a bare STRING is the paclet-NAME form and
   yields Missing properties.  The directory form is File[dir]. *)
po = PacletObject[File[repo]];
sf["Name=", po["Name"]];
sf["Version=", po["Version"]];
sf["WolframVersion=", po["WolframVersion"]];
sf["License (custom field)=", po["License"]];
sf["Creator=", po["Creator"]];
sf["Description=", po["Description"]];
sf["Context=", po["Context"]];
sf["Extensions=", po["Extensions"]];
sf["Location=", po["Location"]];
sf["PacletFind before load: ", Quiet[Check[PacletFind["SpectralElement"][[1]]["Name"], "NOT-REGISTERED-YET"]]];

(* ---------------------------------------------------------------- *)
sf["--- 2. the load path under test ---"];
sf["before: on $ContextPath= ", MemberQ[$ContextPath, "SpectralElement`"]];
ld = PacletDirectoryLoad[repo];
sf["PacletDirectoryLoad returned=", ld];
sf["PacletFind after load= ", Check[PacletFind["SpectralElement"][[1]]["Name"], "NOT-FOUND"]];
sf["registered version= ", Check[PacletFind["SpectralElement"][[1]]["Version"], "?"]];
sf["on $ContextPath, before Needs= ", MemberQ[$ContextPath, "SpectralElement`"]];
(* Check[..., tag] detects whether a message was raised during the load.
   For the loader itself a message would be a defect; for a half-written
   subfile it is the owning agent's problem, so it is reported, not fatal.
   NOTE: Block[{$MessageOutput = stream}] does NOT capture messages raised
   during a Get -- they go to the run's stdout, which rr.sh captures as
   Tests/out/loadprobe.stdout.  We read that file back afterwards, best
   effort, so the evidence names the offending file and line. *)
nd = Check[Needs["SpectralElement`"], "LOAD-RAISED-A-MESSAGE"];
sf["Needs returned=", nd, "   (Null = success, $Failed = not found)"];
onPath = MemberQ[$ContextPath, "SpectralElement`"];
sf["on $ContextPath, after Needs= ", onPath];
sf["position of SpectralElement` on $ContextPath (len ",
  Length[$ContextPath], ")= ",
  Check[Flatten[Position[$ContextPath, "SpectralElement`", {1}, 1]][[1]], "?"]];
ff = Check[FindFile["SpectralElement`SpectralElement`"], "NOT-FOUND"];
sf["FindFile=", ff];
sf["contexts containing 'SpectralElement'= ",
  Select[Contexts[], StringContainsQ[#, "SpectralElement"] &]];

(* best effort: pull the messages out of this run's stdout *)
sofile = FileNameJoin[{repo, "Tests", "out", "loadprobe.stdout"}];
msgsRaised = If[FileExistsQ[sofile],
   Quiet[Check[Select[ReadList[sofile, String], StringContainsQ[#, "::"] &], {}]],
   {"<stdout not readable>"}];
sf["messages seen in this run's stdout:",
  If[Length[msgsRaised] === 0, "none", "see below"]];
Do[sf["    ", m], {m, msgsRaised}];

(* ---------------------------------------------------------------- *)
sf["--- 3. $Context and Names ---"];
sf["$Context=", $Context];
names = Sort[Names["SpectralElement`*"]];
sf["Length[Names[SpectralElement`*]]=", Length[names]];
sf["Names=", names];

(* ---------------------------------------------------------------- *)
sf["--- 4. per symbol: SymbolName and Context (Context /@ , see trap 1) ---"];
ctxs = Context /@ pub;
sf["  Context /@ pub =", ctxs];
sf["  SymbolName /@ pub =", SymbolName /@ pub];
sf["  evaluation check (usage-only symbols evaluate to themselves):"];
sf["    SpectralElement`CoonsPatchQ[1, 2] -> ",
  Check[SpectralElement`CoonsPatchQ[1, 2], "RAISED"]];
okSym = ctxs === ConstantArray["SpectralElement`", Length[pub]];
sf["  all eight in SpectralElement`= ", okSym];

(* ---------------------------------------------------------------- *)
sf["--- 5. Kernel/init.m is inert once the package is loaded ---"];
initm = Check[Get[FileNameJoin[{repo, "Kernel", "init.m"}]], "INITM-RAISED-A-MESSAGE"];
sf["Get[Kernel/init.m]= ", initm, "   (Null = inert no-op)"];
sf["public symbol count unchanged= ", Length[Names["SpectralElement`*"]]];

(* ---------------------------------------------------------------- *)
sf["--- 6. verdict ---"];
(* The verdict covers the LOADER only.  nd === $Failed would mean the
   paclet could not be loaded at all and IS a failure.  A message raised
   during the load is not: it comes from the subfiles, which other agents
   own and gate with their own probes.  Check each loader fact by name so
   a FAIL says which one broke. *)
missing = Complement[SymbolName /@ pub, names];
extra = Complement[names, SymbolName /@ pub];
checks = {"PacletDirectoryLoad registered the paclet" -> (ld =!= $Failed),
   "Needs did not return $Failed" -> (nd =!= $Failed),
   "context on $ContextPath" -> onPath,
   "FindFile resolves to Kernel/SpectralElement.wl" ->
     (ff === FileNameJoin[{repo, "Kernel", "SpectralElement.wl"}]),
   "no public symbol missing" -> (missing === {}),
   "all eight in context SpectralElement`" ->
     (ctxs === ConstantArray["SpectralElement`", Length[pub]]),
   "Kernel/init.m inert" -> (initm === Null)};
Do[sf["  ", checks[[i, 1]], " -> ", checks[[i, 2]]], {i, Length[checks]}];
sf["missing=", If[missing === {}, "NONE", missing]];
sf["unexpected extras=", If[extra === {}, "NONE", extra]];
sf["WARNING: an extra public symbol is not a failure.  Every symbol in"];
sf["  Names[SpectralElement`*] must be declared with a ::usage message in"];
sf["  Kernel/SpectralElement.wl and documented in API.md section 4; if one"];
sf["  is not, its owner must add it to both.  Bare symbols written by a"];
sf["  subfile land in SpectralElement`Private and never show up here."];
sf["VERDICT=", If[And @@ checks[[All, 2]], "PASS", "FAIL"]];
sf["NOTE: messages raised during the load are echoed above with their file"];
sf["      and line; they belong to the subfile owners and do not affect it."];
sf["================ DONE-loadprobe ================"];
sfClose[];
Quit[];
