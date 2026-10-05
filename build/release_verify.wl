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

Quiet[Check[PacletUninstall[name], Print]];
Print["AFTER-UNINSTALL-FOUND ", Length[Quiet[Check[PacletFind[name], {}]]]];
If[StringQ[loc] && loc != "", If[DirectoryQ[loc], Run["rm -rf " <> loc]]];
Print["INSTALL-DIR-GONE ", ! DirectoryQ[loc]];
Quit[];