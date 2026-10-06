(* ::Package:: *)

(* =====================================================================
   build/release_verify.wl -- install the built archive and prove it works.

   Called by build/release.sh, which stages a clean copy of the package,
   archives it, and then runs this to install THAT archive.  Listing the
   archive entries shows what is inside; installing it shows that what is
   inside actually loads.  Without this step a release could contain a
   byte-perfect file list and still not work.

   The install is given the paclet's own name so the context resolves
   exactly as it will for a user, and it is uninstalled again before
   exiting, with the install directory removed too -- release.sh must
   leave nothing on this machine.

   Output is a flat list of KEY value lines, which release.sh greps.  Keys:

       INSTALL-FAILED / NEEDS-RAISED      failure markers
       FOUND n                            PacletFind count after install
       LOCATION path                      where it was installed
       NEEDS Null-OK                      load succeeded
       SYMBOLS n                          public symbols in SpectralElement`
       FINDFILE path                      the file the context resolved to
       PATCH-OK / DISC-OK True/False      the two layers actually ran
       UNKNOWN-COUNT n                    the assembled unknown count
       AFTER-UNINSTALL-FOUND n            0 expected
       INSTALL-DIR-GONE True/False        install directory removed
       DOC-INSTALLED-FILES n              documentation pages found
       DOC-INSTALLED-MISSING ...          convention paths that did NOT land
       DOC-PACLET-INFO-OK True/False      the installed PacletInfo declares
                                          the Documentation extension
   ===================================================================== *)
$HistoryLength = 0;

(* read by release.sh: the archive and the paclet name *)
arc = Environment["SPECTRAL_RELEASE_ARCHIVE"];
name = Environment["SPECTRAL_RELEASE_NAME"];
If[! StringQ[arc] || ! StringQ[name],
   Print["INSTALL-FAILED no archive path given"];
   Quit[1]];

If[! FileExistsQ[arc],
   Print["INSTALL-FAILED archive missing: ", arc];
   Quit[1]];

(* PRE-CLEAN.  PacletInstall refuses to replace an already-installed copy of
   the same version -- PacletInstall::samevers -- and then the code below
   goes on to measure the copy that was already there, which is the one
   built by the previous run and has no Documentation/ at all.  That is
   what produced, on the first run of this gate:
       INSTALL-FAILED
       DOC-INSTALLED-FILES 0
       DOC-INSTALLED-MISSING {all nine}
   against an archive whose listing ten lines earlier shows all nine.  So
   the machine is cleared first, and the clear is itself checked, or the
   measurement is still of the wrong tree.  Only SpectralElement is
   touched. *)
pre = Quiet[Check[PacletFind[name], {}]];
If[Length[pre] > 0,
  Module[{ploc},
    ploc = pre[[1, 1]]["Location"];
    Quiet[Check[PacletUninstall[name], Print]];
    If[StringQ[ploc] && ploc != "", If[DirectoryQ[ploc], Run["rm -rf " <> ploc]]]]];
Print["PRE-CLEAN-FOUND ", Length[Quiet[Check[PacletFind[name], {}]]]];

Quiet[Check[PacletInstall[arc], Print["INSTALL-FAILED"]]];

pf = Quiet[Check[PacletFind[name], {}]];
Print["FOUND ", Length[pf]];
loc = If[Length[pf] > 0, pf[[1, 1]]["Location"], ""];
Print["LOCATION ", loc];
Print["VERSION ", If[Length[pf] > 0, pf[[1, 1]]["Version"], "?"]];

nd = Quiet[Check[Needs["SpectralElement`"], "NEEDS-RAISED"]];
Print["NEEDS ", If[nd === Null, "Null-OK", nd]];
Print["SYMBOLS ", Length[Names["SpectralElement`*"]]];
Print["FINDFILE ", Quiet[Check[FindFile["SpectralElement`SpectralElement`"], "NOT-FOUND"]]];

(* Prove the shipped CODE runs, not just that the context appeared: a
   four-true-corner patch, then a discretization of it.  These are the
   same two calls Tests/installprobe.wl gates on. *)
edges = {Function[t, {2 t, -1}], Function[t, {2 t, 1}],
   Function[t, {-2, t}], Function[t, {2, t}]};
patch = Quiet[SpectralElement`CoonsPatch[edges]];
Print["PATCH-OK ", AssociationQ[patch]];
disc = Quiet[SpectralElement`SpectralDomain[{patch}, 8]];
Print["DISC-OK ", AssociationQ[disc]];
Print["UNKNOWN-COUNT ", Quiet[SpectralElement`SpectralDomainData[disc, "UnknownCount"]]];

(* THE DOCUMENTATION TREE, in the INSTALLED copy.  Listing the archive
   shows the pages were packed; this shows they were UNPACKED to the paths
   the Documentation Center resolves against.  Those two facts are
   separate, and only the second one is what F1 depends on.

   The nine paths are spelled out rather than counted, because the
   resolution is by convention:
       paclet:SpectralElement/ref/<Symbol>
         -> Documentation/English/ReferencePages/Symbols/<Symbol>.nb
       MainPage -> "Guides/SpectralElement"
         -> Documentation/English/Guides/SpectralElement.nb
   so a page present under the wrong name or one directory too deep
   counts as missing, and a bare count would have called that a pass. *)
docRel = {"Documentation/English/Guides/SpectralElement.nb",
  "Documentation/English/ReferencePages/Symbols/CoonsPatch.nb",
  "Documentation/English/ReferencePages/Symbols/CoonsPatchQ.nb",
  "Documentation/English/ReferencePages/Symbols/CoonsPatchMap.nb",
  "Documentation/English/ReferencePages/Symbols/SpectralDomain.nb",
  "Documentation/English/ReferencePages/Symbols/SpectralDomainQ.nb",
  "Documentation/English/ReferencePages/Symbols/SpectralDomainData.nb",
  "Documentation/English/ReferencePages/Symbols/SpectralNDSolve.nb",
  "Documentation/English/ReferencePages/Symbols/SpectralNDSolveValue.nb"};

docFound = Select[docRel, FileExistsQ[FileNameJoin[{loc, #}]] &];
docMissing = Complement[docRel, docFound];
Print["DOC-INSTALLED-FILES ", Length[docFound]];
Print["DOC-INSTALLED-MISSING ", If[docMissing === {}, "NONE", docMissing]];

(* and the installed metadata must actually declare the extension *)
exts = Quiet[Check[PacletObject[File[loc]]["Extensions"], {}]];
docExt = Select[exts, MatchQ[#, {"Documentation", __}] &];
Print["DOC-PACLET-INFO-OK ", Length[docExt] == 1];

(* and the kernel must resolve a symbol page to the installed file.  This
   is the F1 navigation path, exercised headless: ResolveLink is what the
   Documentation Center calls on the URI it builds from the symbol name. *)
resolved = Quiet[Check[Documentation`ResolveLink[
   "paclet:" <> name <> "/ref/SpectralNDSolve"], "UNRESOLVED"]];
Print["DOC-RESOLVE-SpectralNDSolve ", resolved];
Print["DOC-RESOLVE-MATCHES-INSTALLED ",
  StringQ[resolved] && StringStartsQ[resolved, loc]];

Quiet[Check[PacletUninstall[name], Print]];
Print["AFTER-UNINSTALL-FOUND ", Length[Quiet[Check[PacletFind[name], {}]]]];
If[StringQ[loc] && loc != "", If[DirectoryQ[loc], Run["rm -rf " <> loc]]];
Print["INSTALL-DIR-GONE ", ! DirectoryQ[loc]];
Quit[];