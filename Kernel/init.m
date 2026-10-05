(* ::Package:: *)

(* init.m -- FALLBACK loader for the context "SpectralElement`".

   With the Kernel extension declared in ../PacletInfo.wl

       {"Kernel", "Root" -> "Kernel", "Context" -> {"SpectralElement`"}}

   the context "SpectralElement`" resolves DIRECTLY to
   Kernel/SpectralElement.wl.  So

       PacletDirectoryLoad[dir]; Needs["SpectralElement`"]

   works and THIS FILE IS NEVER READ by the paclet system.  The "Paclets"
   tech note (section "init.m files") says such a file is unnecessary and
   strongly discouraged for a paclet with a proper Kernel extension; it
   exists only for old-style layouts where a directory on $Path has no
   matching Context.wl.

   It is kept because it costs nothing, it is a no-op once the package is
   loaded, and it makes Kernel/ usable as a plain $Path directory.  Do not
   put anything here that SpectralElement.wl needs: this file may never run.

   The "is it already loaded" test is MemberQ[$ContextPath, "SpectralElement`"],
   NOT ValueQ[...].  A symbol that carries only a ::usage message has no
   value, so ValueQ[SpectralElement`CoonsPatchQ] is False even in a fully
   loaded package, and a ValueQ guard silently re-Get's the package (and
   re-raises every message its subfiles raise). *)

If[! MemberQ[$ContextPath, "SpectralElement`"],
  Module[{here, main},
    here = If[StringQ[$InputFileName], DirectoryName[$InputFileName], ""];
    main = If[FileExistsQ[FileNameJoin[{here, "SpectralElement.wl"}]],
      FileNameJoin[{here, "SpectralElement.wl"}],
      "SpectralElement`SpectralElement`"];
    If[MatchQ[main, _String] && ! StringContainsQ[main, "`"], Get[main]]]]
