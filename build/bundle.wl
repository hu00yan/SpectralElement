(* ::Package:: *)

(* =====================================================================
   build/bundle.wl -- SINGLE-FILE BUNDLER for the Function Repository
   ---------------------------------------------------------------------
   Reads the paclet's loader  Kernel/SpectralElement.wl  and replaces
   each

       Get[FileNameJoin[{DirectoryName[$InputFileName], "AAA.wl"}]]

   (and Geometry / Discretization / Solve) with the VERBATIM text of the
   file it names, wrapped in a one-line marker comment.  Result:

       wfr/SpectralNDSolve.wl     -- one self-contained package

   Properties this script guarantees, and how:

     * DETERMINISTIC / IDEMPOTENT.  No DateString, no FileDateTime, no
       dictionary-order dependence.  The only provenance in the header is
       the SHA-256 of each source file, which is a function of the source
       bytes.  Running the bundler twice on unchanged sources produces a
       byte-identical bundle.

     * PATH-FREE AT LOAD TIME.  After inlining there is no $InputFileName,
       no Get and no FileNameJoin left in the bundle; section 4 ASSERTS
       that and fails the run if any appears.

     * WRITTEN AND VERIFIED.  The bundle is written with Export (Put
       returns Null and writes NOTHING under wolframscript on this
       machine -- Tests/out/w9probe.*.txt) and then READ BACK and
       compared to the intended text.  A write that silently does nothing
       is the worst possible failure mode for a build step.

     * A BROKEN SOURCE IS NAMED, NOT SWALLOWED.  The four inlined blocks
       come from the same files the paclet loads, so if one of them is
       half-written the bundle is unparseable too.  Section 5 syntax-checks
       (a) each inlined block SEPARATELY, (b) the loader skeleton on its
       own, and (c) the whole bundle, and prints WHICH one is broken.

   WL traps this script is written around -- each reproduced in
   Tests/out/, cited at the point where it matters:

     1. `If[cond, a; b]` is a Syntax::sntx.  A `;` at the top level of a
        function's ARGUMENT list terminates the enclosing expression.
        (Tests/out/w6probe.*.txt, candidates m1-m5.)  Every multi-
        statement body here is therefore a named function.
     2. `=/=` is NOT a Wolfram Language operator; the NotEqual spellings
        are `!=` and `=!=`.  (Tests/out/w7probe.021303_56473.txt, o1-o8.)
     3. `AppendTo[list, sublist]` NESTS; it does not splice.  The first
        attempt used it and produced a bundle whose text was one nested
        list, which then failed SyntaxQ for reasons that had nothing to do
        with the sources.  (Tests/out/w9probe.*.txt section 4.)  `Join` is
        used instead, and "every element is a string" is asserted.
     4. `FileHash` returns an Integer; it must be `ToString`ed before it
        can be concatenated into a comment.
     5. In a Wolfram string PATTERN a bare "$" is the end-of-string
        anchor, so "$InputFileName" matches nothing.  Use "\\$...".
     6. A `)` where a `]` belongs is the single most common bracket slip
        and SyntaxQ names it only by the expression that follows it.
     7. `StringJoin[list, "\\n"]` does NOT insert a separator: it appends
        "\\n" to the concatenation, so a 1400-element list comes out as
        ONE line and the file is garbage.  `StringJoin` takes strings to
        concatenate, not a list plus a delimiter.  The function for
        "join a list WITH a separator" is `StringRiffle`.
        (Tests/out/w10probe.025359_70047.txt section 1: three strings
        joined to "onetwothree<NL>", two newlines lost.)

   Run:      ./rr.sh 180 build/bundle.wl          (from the repo root)
             or ./build/bundle.sh
   Evidence: Tests/out/bundle.<stamp>.txt  (path also in
             Tests/out/bundle.lastout as OUT=...)

   Does NOT edit anything under Kernel/ -- it only reads it.
   ===================================================================== *)
$HistoryLength = 0;

sfLog = If[StringQ[Environment["SPECF_OUT"]], Environment["SPECF_OUT"], FileNameJoin[{DirectoryName[$InputFileName], "bundle.nofallback.txt"}]];
sfStream = OpenWrite[sfLog];
sfSafe[e_] := Module[{s = ToString[e, InputForm]}, If[StringLength[s] > 300, StringTake[s, 300] <> "..TRUNC", s]];
sf[args___] := (WriteString[sfStream, StringJoin[sfSafe /@ {args}] <> "\n"]; Flush[sfStream]; Print[Row[{args}]]);
sfClose[] := (Close[sfStream]; Null);
fatal[a___] := (WriteString[sfStream, StringJoin[sfSafe /@ Join[{"FATAL: "}, {a}]] <> "\n"];
   Flush[sfStream]; Print[Row[{a}]]; Close[sfStream]; Quit[9]);

(* repo root = parent of build/ *)
root = DirectoryName[DirectoryName[$InputFileName]];
loaderPath = FileNameJoin[{root, "Kernel", "SpectralElement.wl"}];
outPath = FileNameJoin[{root, "wfr", "SpectralNDSolve.wl"}];

(* Regex only answers YES/NO here (StringMatchQ).  The file name is taken
   out by plain string surgery and then validated: StringCases with a
   RegularExpression that HAS a capture group does not return the group
   where you would expect it. *)
getRe = RegularExpression["^\\s*Get\\[FileNameJoin\\[\\{DirectoryName\\[\\$InputFileName\\],\\s*\"[A-Za-z0-9_]+\\.wl\"\\}\\]\\]\\s*$"];
isGetLine[ln_] := StringMatchQ[ln, getRe];
getName[ln_] := Module[{parts = StringSplit[ln, "\""], f},
  f = If[Length[parts] >= 3, parts[[2]], ""];
  If[StringMatchQ[f, "*.wl"], f, ""]];

sq[txt_] := Quiet[Check[SyntaxQ[txt], "ERR"]];

sf["================ bundle START ================"];
sf["root=", root];
sf["loader=", loaderPath, "  exists=", FileExistsQ[loaderPath]];
sf["$Version=", $Version];

(* ---------------------------------------------------------------- *)
sf["--- 1. read the loader and find the Get statements ---"];
If[! FileExistsQ[loaderPath], sf["loader missing"]; fatal["loader missing"]];
loaderTxt = Import[loaderPath, "Text"];
loaderLines = StringSplit[loaderTxt, "\n"];
sf["loader lines=", Length[loaderLines], "  chars=", StringLength[loaderTxt]];
sf["SyntaxQ[loader as imported]=", sq[loaderTxt]];

hits = {};   (* {lineIndex, fileName} *)
badGet = {};
noteGet[i_] := Module[{fn},
  fn = getName[loaderLines[[i]]];
  If[isGetLine[loaderLines[[i]]],
     If[fn =!= "", AppendTo[hits, {i, fn}], AppendTo[badGet, i]]]];
Do[noteGet[i], {i, Length[loaderLines]}];
sf["Get statements found=", Length[hits]];
Do[sf["  line ", hits[[k, 1]], " -> Kernel/", hits[[k, 2]], "  exists=", FileExistsQ[FileNameJoin[{root, "Kernel", hits[[k, 2]]}]]], {k, Length[hits]}];
If[Length[badGet] > 0,
   fatal["a Get statement matched the loader pattern at line(s) ", badGet,
          " but its file name could not be read"]];
If[Length[hits] =!= 4,
   fatal["expected exactly 4 Get statements, found ", Length[hits],
          ".  The loader contract changed; update build/bundle.wl"]];
sf["order=", hits[[All, 2]]];

(* ---------------------------------------------------------------- *)
sf["--- 2. read each source verbatim ---"];
srcTxt = Table[Import[FileNameJoin[{root, "Kernel", hits[[k, 2]]}], "Text"], {k, 4}];
srcLines = Table[StringSplit[srcTxt[[k]], "\n"], {k, 4}];
srcSha = Table[Quiet[Check[FileHash[FileNameJoin[{root, "Kernel", hits[[k, 2]]}], "SHA256"], "ERR"]], {k, 4}];
(* Two renderings of one value, for two different consumers.
   srcShaStr (decimal Integer) goes INTO the marker comment, so changing
   it would change the bundle's bytes and therefore its own hash -- it is
   frozen to keep the bundle reproducible against the hash recorded in
   wfr/SpectralNDSolve.md.  It is a true SHA-256, just not in a form a
   standard tool prints.
   srcShaHex is what the EVIDENCE prints: hex, so it can be pasted
   straight into `shasum -a 256 Kernel/<file>` and compared.  Both are
   the same 256-bit digest.  (Cross-checked: the decimal value converts
   to hex exactly to shasum -a 256's output for all four sources.) *)
srcShaStr = Table[ToString[srcSha[[k]]], {k, 4}];
srcShaHex = Table[Quiet[Check[FileHash[FileNameJoin[{root, "Kernel", hits[[k, 2]]}], "SHA256", "HexString"], "ERR"]], {k, 4}];
Do[sf["  Kernel/", hits[[k, 2]], "  lines=", Length[srcLines[[k]]], "  chars=", StringLength[srcTxt[[k]]], "  sha256hex=", srcShaHex[[k]], "  sha256dec=", srcShaStr[[k]]], {k, 4}];

(* ---------------------------------------------------------------- *)
sf["--- 3. assemble the bundle ---"];
markerOpen[k_] := StringJoin["(* " <> StringRepeat["=", 66],
   "\n   >>> INLINED VERBATIM FROM Kernel/" <> hits[[k, 2]],
   " (" <> ToString[Length[srcLines[[k]]] - 1] <> " source lines,",
   " SHA-256 " <> srcShaStr[[k]] <> ")",
   "\n   " <> StringRepeat["=", 66] <> " *)"];
markerClose[k_] := "(* <<< END OF INLINED Kernel/" <> hits[[k, 2]] <> " *)";
blockOf[k_] := Join[{markerOpen[k]}, srcLines[[k]], {markerClose[k]}];

outLines = {};
Do[outLines = Join[outLines, If[MemberQ[hits[[All, 1]], i],
       blockOf[First[Flatten[Position[hits[[All, 1]], i]]]],
       {loaderLines[[i]]}]],
   {i, Length[loaderLines]}];
sf["bundle body lines=", Length[outLines]];
allStringsQ = And @@ (StringQ /@ outLines);
sf["every body line is a string=", allStringsQ];
If[! allStringsQ, fatal["body assembly produced a nested list; AppendTo/Join mistake"]];

header = {
  "(* ::Package:: *)",
  "",
  "(* " <> StringRepeat["=", 68],
  "   GENERATED FILE -- DO NOT EDIT.",
  "   ",
  "   This is the single-file build of the SpectralElement paclet, produced",
  "   for the Wolfram Function Repository by build/bundle.wl.  It was NOT",
  "   written by hand: every block between the INLINED VERBATIM markers",
  "   below is a byte-for-byte copy of a file under Kernel/ in the source",
  "   repository, spliced in where the paclet loader would have Get-ed it.",
  "   ",
  "   Source repository:  https://github.com/spectralelement/SpectralElement",
  "   Source files:       Kernel/SpectralElement.wl (this header's skeleton)",
  "                      Kernel/AAA.wl, Kernel/Geometry.wl,",
  "                      Kernel/Discretization.wl, Kernel/Solve.wl",
  "   Regenerate with:    ./build/bundle.sh     (or: ./rr.sh 180 build/bundle.wl)",
  "   ",
  "   The build is deterministic: it contains no timestamp, so an unchanged",
  "   source tree always produces a byte-identical bundle.  Provenance is",
  "   carried by the SHA-256 of each inlined source, printed in its marker.",
  "   ",
  "   Load-time dependencies: NONE.  There is deliberately no $InputFileName,",
  "   no Get and no FileNameJoin anywhere in this file -- the whole point of",
  "   the build.  Kernel/init.m is NOT inlined: it is the paclet's fallback",
  "   loader for a hand-placed Kernel/ directory on $Path and has no role",
  "   here.",
  "   " <> StringRepeat["=", 68] <> " *)",
  ""};

outText = StringRiffle[Join[header, outLines], "\n"];
If[! StringEndsQ[outText, "\n"], outText = outText <> "\n"];
sf["bundle chars=", StringLength[outText]];

(* ---------------------------------------------------------------- *)
sf["--- 3b. write with Export and READ BACK (Put writes nothing here) ---"];
If[! DirectoryQ[FileNameJoin[{root, "wfr"}]], CreateDirectory[FileNameJoin[{root, "wfr"}]]];
If[FileExistsQ[outPath], DeleteFile[outPath]];
(* ENCODING.  Every read of a source or of the output uses
   Import[..., "Text"], NOT Import[..., "String"].  "String" decodes the
   bytes as Latin-1, so one em dash (3 UTF-8 bytes) becomes THREE
   characters; exporting those back as UTF-8 double-encodes them and the
   file grows by 3 bytes, which is exactly what the first three attempts
   hit.  "Text" decodes UTF-8 and round-trips.  Pinned by
   Tests/out/w11probe.032958_73931.txt: Solve.wl reads as 63 chars with
   "String" and 60 with "Text".  CharacterEncoding -> "UTF8" on Export
   is then redundant but harmless, and is kept explicit. *)
Export[outPath, outText, "Text", CharacterEncoding -> "UTF8"];
wroteQ = FileExistsQ[outPath];
sf["wrote=", outPath, "  exists=", wroteQ];
If[! wroteQ, fatal["Export did not produce ", outPath]];
backTxt = Import[outPath, "Text"];
sf["intended chars=", StringLength[outText], "  read-back chars=", StringLength[backTxt]];
(* Read-back verification.  Export/Import must reproduce the built text
   exactly; a build step that silently writes the wrong thing is the worst
   failure mode there is.  StringLength is reported for BOTH so a
   character-count difference cannot hide, and the first differing
   character position is reported when they are not equal. *)
(* outText is built by StringRiffle (no trailing newline) and then given
   exactly one; Import[..., "Text"] strips that final newline again.  So the
   read-back must equal outText with its LAST character dropped, and
   StringLength is reported for both so a larger discrepancy cannot hide.
   NB StringReplace[t, "\n$" -> ""] does NOT do this: the "$" anchor in a
   Wolfram string pattern did not match the trailing newline in testing
   (Tests/out/bundle.034148_75594.txt reported 80505 vs 80506 after it),
   and StringTrimRight[..., "\n"] came back unevaluated.  StringDrop is
   explicit and was verified. *)
canonBack = backTxt;
canonWant = StringDrop[outText, -1];
roundTripQ = (canonBack === canonWant);
sf["  lengths: read-back=", StringLength[canonBack], "  intended=", StringLength[canonWant]];
firstDiff = If[roundTripQ, "N/A (identical)", Quiet[Check[First[Flatten[Position[Characters[canonBack], Characters[canonWant]]]], "NO-DIFF-POS"]]];
sf["read-back matches the intended text (modulo trailing newline)=", roundTripQ];
sf["  first differing character position=", firstDiff];
sf["file bytes=", Check[FileSize[outPath], "ERR"]];
(* The algorithm and the form are BOTH spelled out.  `FileHash[file]`
   with no algorithm silently means "MD5", so a bare call would have
   printed an MD5 while the label below said sha256 -- a false claim in
   the evidence.  And an Integer hash printed by ToString is decimal,
   which no standard tool prints, so it cannot be checked against
   `shasum -a 256`.  "SHA256" + "HexString" makes every hash here
   directly comparable.  (Tests/out/hashprobe.stdout measured both
   traps: default=md5dec=221278209058438152535733536768935391788,
   sha256hex=733af4ac06369673f869ec6708bdb43af4286917e9fdf09ed29f8d93b5114f37.)
   NB this only changes what the EVIDENCE prints; the bundle's bytes,
   and therefore the hash it computes, are unaffected. *)
bundleSha = Check[Quiet[FileHash[outPath, "SHA256", "HexString"]], "ERR"];
sf["bundle sha256hex=", bundleSha];
If[! roundTripQ,
   fatal["read-back mismatch: the file on disk is not what was built"]];

(* ---------------------------------------------------------------- *)
sf["--- 4. load-time independence assertions ---"];
resGet = Length[Select[outLines, StringMatchQ[#, getRe] &]];
nInputName = Length[StringCases[backTxt, "\\$InputFileName"]];
nFileNameJoin = Length[StringCases[backTxt, "FileNameJoin["]];
nGetBracket = Length[StringCases[backTxt, "\\bGet\\["]];
pathFreeQ = (nInputName === 0 && resGet === 0 && nFileNameJoin === 0 && nGetBracket === 0);
sf["  loader Get-pattern lines surviving=", resGet];
sf["  literal $InputFileName occurrences=", nInputName];
sf["  FileNameJoin[ occurrences=", nFileNameJoin];
sf["  Get[ occurrences=", nGetBracket];
sf["  path-free=", pathFreeQ];

(* ---------------------------------------------------------------- *)
sf["--- 5. parse check: whole bundle, each block, and the skeleton ---"];
bundleOk = sq[backTxt];
sf["  SyntaxQ[whole bundle as written]=", bundleOk];
blockOk = Table[sq[srcTxt[[k]]], {k, 4}];
Do[sf["  SyntaxQ[inlined Kernel/", hits[[k, 2]], "]=", blockOk[[k]]], {k, 4}];
(* the loader skeleton alone: the loader with its four Get statements
   replaced by Null, which isolates "is the problem in the loader
   wrapper" from "is the problem in one of the inlined blocks". *)
skelLines = loaderLines;
skelLines[[hits[[All, 1]]]] = ConstantArray["Null", Length[hits]];
skelTxt = StringRiffle[skelLines, "\n"];
Do[sf["  skeleton line ", hits[[k, 1]], " now reads: ", skelLines[[hits[[k, 1]]]]], {k, 4}];
skelOk = sq[skelTxt];
sf["  SyntaxQ[loader skeleton, Gets blanked]=", skelOk];
broken = Table[If[TrueQ[blockOk[[k]]] === False, hits[[k, 2]], Nothing], {k, 4}];
sf["  BROKEN SOURCE BLOCKS=", If[Length[broken] === 0, "NONE", broken]];
sf["  READING THIS TABLE: a FALSE under 'SyntaxQ[inlined Kernel/X.wl]' is a",
   "  defect in that source file and belongs to its owning agent -- it is",
   "  NOT fixed here.  If all four are True but the whole bundle is False,",
   "  the fault is in the loader skeleton or in this bundler."];

(* ---------------------------------------------------------------- *)
sf["--- 6. verdict ---"];
ok = (bundleOk === True && pathFreeQ && roundTripQ && skelOk === True
      && Length[broken] === 0);
sf["VERDICT=", If[ok, "BUNDLE-OK", "BUNDLE-BROKEN"]];
If[! ok,
   sf["  ACTION: see the table above for which layer failed, then re-run",
      "  ./build/bundle.sh -- the bundler is idempotent, so re-running is",
      "  always safe."]];
sf["================ DONE-bundle ================"];
sfClose[];
Quit[];