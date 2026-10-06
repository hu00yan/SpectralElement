(* ::Package:: *)

(* PacletInfo.wl -- metadata for the "SpectralElement" paclet.

   ====================================================================
   READ-ONLY FILE, and the only thing it may be evaluated for.

   Format: PacletObject[<| ... |>], the modern (12.1+) form; the old
   Paclet["Name" -> ..., Root -> ...] is still parsed but discouraged.

   PacletInfo.wl files are READ, NOT EVALUATED: every field value must be
   a literal (string / number / list / rule), never something computed.
   Rules use STRING left-hand sides ("Name" -> ...) and arrow \[Rule].

   --------------------------------------------------------------------
   HOW THE FIELDS BELOW WERE CHOSEN

   Everything below was decided against evidence reachable OFFLINE on this
   machine, not from memory.  Three findings changed the file:

   1. WolframVersion IS FREE TEXT, not a structured version range.
      Every paclet Wolfram ships under
        ~/Library/Wolfram/Paclets/Repository
      writes a string, and the values in use are:
        "14.3.0"   "14.3"   "14.3+"   "14.2+"   "14.1+"
      So "13.0+" below is the correct SHAPE, not a placeholder to be
      restructured.  (A `{min, max}` list was tried and is not the form
      any shipped paclet uses.)
      Evidence: Tests/out/q16probe.*.txt, and the field census in
      build/README-packaging.md.

   2. PublisherID and Creator are real fields, and Creator may be a LIST
      of names.  Shipped examples:
        "PublisherID" -> "Wolfram"
        "Creator"     -> "Connor Gray, Theodore Gray, ..."
        "Creator"     -> { ... }
      Both are declared below.  "Creator" is filled with the git author
      identity on every commit in this repository.  "PublisherID" was
      removed: it identifies a group submitting on its behalf, and this is an
      individual repository -- see the submission-values block below.

   3. Category vs Categories is genuinely AMBIGUOUS and could not be
      settled offline.  No shipped paclet on this machine uses "Category",
      "Categories" or "Tags" at all, so there is no precedent to copy.
      The PacletInfo documentation page on this machine
      (/Library/Wolfram/Documentation/14.3/en-us/Documentation/English/
      Paclets/PacletInfo.wl) declares no category field either.
      A probe (Tests/out/q16probe.*.txt) established that the paclet
      reader keeps EVERY field verbatim -- it does not validate names --
      so BOTH spellings are carried below, with the same value.  That way
      whichever one the Paclet Repository reads, the metadata is present,
      and nothing is lost either way.  CONFIRM AT SUBMISSION TIME and
      delete whichever the Repository does not use.

   --------------------------------------------------------------------
   The "Kernel" extension below is the whole loading contract:

       {"Kernel", "Root" -> "Kernel", "Context" -> {"SpectralElement`"}}

   "Kernel" is NOT the default root of a Kernel extension (kept for
   backward compatibility), so "Root" -> "Kernel" is required when the
   .wl files live in a Kernel subdirectory.  With this declaration the
   context "SpectralElement`" resolves straight to
   Kernel/SpectralElement.wl, so

       PacletDirectoryLoad[dir]; Needs["SpectralElement`"]

   works with no $Path fiddling and no init.m trick.  See API.md.

   "License" is not one of the built-in paclet fields; it is a legal
   CUSTOM field (custom fields are explicitly allowed) and is read back
   with p["License"].  It is kept because a licence must travel with the
   package. *)

(* ====================================================================
   SUBMISSION VALUES.

   Creator and URL were filled from facts already established for this
   repository: Creator is the git author identity on both existing commits,
   and URL is the repository the code actually lives in.

   PublisherID was removed rather than filled.  It is the Wolfram publisher
   identifier used when submitting on behalf of a group; this is an
   individual repository, and a plausible-looking fake identifier is worse
   than none -- it can pass review and then reach users.

   No placeholder values remain in this file.
   ==================================================================== *)

PacletObject[<|
    "Name" -> "SpectralElement",
    "Version" -> "0.1.0",

    (* Free-text version range; see finding (1) in the header. *)
    "WolframVersion" -> "13.0+",

    (* The git author identity on every commit in this repository. *)
    "Creator" -> "Tenghu Zhang",

    (* No "PublisherID".  That field is for submitting on behalf of a group;
   this is an individual repository, and a plausible-looking fake identifier
   is worse than none -- it can pass review and then reach users. *)

    "Description" -> "Spectral multi-domain (spectral-element) solvers for PDEs on arbitrary curved 2D domains.",

    (* Both spellings carried on purpose; see finding (3) in the header.
       Confirm at submission time and delete the one that goes unused. *)
    "Category" -> {"Developer Tools", "Mathematics"},
    "Categories" -> {"Developer Tools", "Mathematics"},

    "Keywords" -> {"spectral element method", "spectral methods", "transfinite interpolation", "Coons patch", "PDE", "finite element", "multi-domain", "Chebyshev", "NDSolve"},

    "License" -> "MIT",

    (* The repository this code actually lives in. *)
    "URL" -> "https://github.com/hu00yan/SpectralElement",

    (* TWO extensions, and both are load-bearing.

       "Kernel" is NOT the default root of a Kernel extension (kept for
       backward compatibility), so "Root" -> "Kernel" is required when the
       .wl files live in a Kernel subdirectory.  With this declaration the
       context "SpectralElement`" resolves straight to
       Kernel/SpectralElement.wl, so

           PacletDirectoryLoad[dir]; Needs["SpectralElement`"]

       works with no $Path fiddling and no init.m trick.  See API.md.

       "Documentation" is what makes F1 work.  Without it the paclet
       loads and every symbol is usable, but pressing F1 -- or entering
       the symbol name at the Documentation Center -- finds nothing,
       because nothing declares that the paclet ships documentation.

       The three-field form below is the shape Wolfram's own shipped
       paclets use, verified on this machine against

           ~/Library/Wolfram/Paclets/Repository/TriangleLink-14.3.0/
             PacletInfo.m

       which declares

           Extensions -> {
               {"Application", Context -> "TriangleLink`"},
               {"Documentation", Language -> All,
                MainPage -> "Guides/TriangleLink"}}

       MainPage is a PACLET-RELATIVE path, not an absolute one, and it
       must name a file that exists under Documentation/<language>/:
       here Documentation/English/Guides/SpectralElement.nb.  A wrong
       path here is the failure that leaves the Documentation Center
       unable to reach the guide even though the reference pages are all
       present and individually reachable.

       Language -> All is what the official paclet uses; the alternative
       Language -> "English" is also valid.  "All" is kept so that the
       declaration does not have to change when another language is
       added, and so that a reader without an English localization is
       pointed at the pages rather than at nothing.

       Spelling note: the key is "Root", capital R -- Kernel's extension
       key is "Root" while the documentation one is "MainPage", and the
       two are not interchangeable. *)
    "Extensions" -> {
        {"Kernel", "Root" -> "Kernel", "Context" -> {"SpectralElement`"}},
        {"Documentation", Language -> All,
         MainPage -> "Guides/SpectralElement"}
    }
|>]