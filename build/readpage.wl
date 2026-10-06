(* readpage.wl -- can the kernel read every documentation page in this paclet?

   Usage:  cd <paclet root>
           DOC_LIST="Documentation/English/.../A.nb
                     Documentation/English/.../B.nb" \
               wolframscript -script build/readpage.wl

   Exits 0 when every listed page parses with no Syntax message at all; exits
   1 otherwise, printing each offending message.  build/release.sh uses the
   exit status; the messages are there so a human can see what broke.

   Why this exists: build/release.sh used to check only that each of the nine
   documentation pages was PRESENT.  All nine were present and none of them
   parsed -- their cell structures had stray closers, so the Documentation
   Center would have found nothing to show.  Existence is not readability.

   The page list arrives in the DOC_LIST environment variable, newline
   separated, for two reasons.  WolframScript hands script arguments inside
   $CommandLine after a "--" separator rather than in $Rest, and parsing that
   reliably turned out to be more trouble than it was worth.  And globbing
   the tree with FileNames is not dependable here: on this machine
   FileNames recursed exactly one level and returned {} for "*.nb", so the
   list the gate already knows is the one to use.

   Two measurement traps this deliberately avoids, both of which cost real
   time on the first nine pages:

     * Import[<file>, "Text"] returns "" for a .nb, so a SyntaxQ check over
       that "text" is really a check over the empty string;
     * ReadList[stream, String] reads TOKENS, not lines, so rejoining them
       silently drops every bracket and comma -- it reports malformed pages
       as clean.

   Get is the kernel's own reader, so it is the only one of these that tells
   the truth about what the Documentation Center will be able to open. *)

raw = Environment["DOC_LIST"];

If[StringQ[raw] === False || StringLength[raw] === 0,
  Print["readpage.wl: DOC_LIST is not set; give the pages to check, one per line,"];
  Print["readpage.wl: newline separated, relative to the paclet root."];
  Exit[2]
];

root = Directory[];
pages = Cases[StringSplit[raw, "\n"], s_String /; StringLength[s] > 0];

If[Length[pages] === 0,
  Print["readpage.wl: DOC_LIST listed no pages"];
  Exit[2]
];

Clear[readOne];
readOne[rel_] := Module[{page},
  page = FileNameJoin[{root, rel}];
  If[! FileExistsQ[page],
    Print["  MISSING   ", rel];
    Return[False]
    ];
  (* Check's second argument fires for ANY message the kernel raises while
     reading, and it catches the soft ones too: a stray comma produces
     Syntax::com, a warning, not Syntax::sntx, and a page with only warnings
     is still a page that does not render the way it was written.  The
     message text is deliberately NOT quieted -- it goes to stderr so a human
     can see exactly which line broke.

     Messages cannot be Cleared to reset a per-page count: the symbol is
     Protected.  Letting Check report is the reliable alternative, and it has
     the advantage that one page's messages cannot be blamed on the next. *)
  If[MatchQ[Check[Get[page], "UNREADABLE"], "UNREADABLE"],
    False,
    Print["  ok        ", rel];
    True
    ]
];

Print["readpage.wl: checking ", Length[pages], " documentation pages"];
res = Map[readOne, pages];

bad = Select[res, TrueQ[Not[#]] &];

Print[""];
If[Length[bad] === 0,
  Print["readpage.wl: OK -- all ", Length[pages], " pages read clean"],
  Print["readpage.wl: FAIL -- ", Length[bad], " of ", Length[pages],
        " pages the kernel cannot read"]
];
Exit[If[Length[bad] === 0, 0, 1]];