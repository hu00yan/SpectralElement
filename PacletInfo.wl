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
      Both are declared below as TODO-USER placeholders because they need
      the submitting user.  THE PLACEHOLDERS MUST BE REPLACED BEFORE
      SUBMISSION -- see the TODO-USER block below.

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
   TODO-USER -- MUST BE FILLED BEFORE SUBMISSION.

   Three values below are deliberately the literal string "TODO-USER"
   rather than invented placeholders.  A plausible-looking fake name or
   URL is worse than an obvious TODO: it can pass review and reach users.
   Each needs an answer only the submitting user has.

     * Creator     -- the real, attributable author name(s).
     * PublisherID -- the Wolfram publisher identifier, needed to submit
                     on behalf of a group.  "Wolfram" is what shipped
                     first-party paclets use.
     * URL         -- the real repository URL.  The previous value pointed
                     at a GitHub organisation that does not exist.

   Search this file for TODO-USER to find them.
   ==================================================================== *)

PacletObject[<|
    "Name" -> "SpectralElement",
    "Version" -> "0.1.0",

    (* Free-text version range; see finding (1) in the header. *)
    "WolframVersion" -> "13.0+",

    (* TODO-USER: replace with the real author name(s).  May be a list. *)
    "Creator" -> "TODO-USER",

    (* TODO-USER: the submitting user's publisher identifier. *)
    "PublisherID" -> "TODO-USER",

    "Description" -> "Spectral multi-domain (spectral-element) solvers for PDEs on arbitrary curved 2D domains.",

    (* Both spellings carried on purpose; see finding (3) in the header.
       Confirm at submission time and delete the one that goes unused. *)
    "Category" -> {"Developer Tools", "Mathematics"},
    "Categories" -> {"Developer Tools", "Mathematics"},

    "Keywords" -> {"spectral element method", "spectral methods", "transfinite interpolation", "Coons patch", "PDE", "finite element", "multi-domain", "Chebyshev", "NDSolve"},

    "License" -> "MIT",

    (* TODO-USER: the real repository URL. *)
    "URL" -> "TODO-USER",

    "Extensions" -> {
        {"Kernel", "Root" -> "Kernel", "Context" -> {"SpectralElement`"}}
    }
|>]