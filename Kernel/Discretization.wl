(* TRAP: the right-hand side of this definition once named the PATTERN
   status_List instead of the pattern VARIABLE status.  That is a
   RuleDelayed::rhs error and Mathematica then drops the whole SetDelayed
   with no message, so seAssemble silently did not exist.  Always use the
   bare variable on the right-hand side. *)
seAssembleCore[patches_List, ops_List, ifs_List, status_List, nN_Integer, pred_] := Module[
   {np, nn, nn2, nif, nmi, cls, fd, dropList, p, q, m, j, ix, iy, ndA, ndB, dq,
    badN, nInt, offP, offI, loc, sel, lf, bnd, bEdges, pde, flux, blocks,
    slices, order, r0, mats, nTot, nRow, nPde, nFlux, intf, rr, sysMat},
   np = Length[ops];
   nif = Length[ifs];
   nmi = nN - 1;
   offP = {};
   offI = {};
   slices = {};
   order = {};
   r0 = 0;
   nn = ops[[1]]["Nodes"];
   nn2 = nn^2;
   cls = Table[seClassifyPatch[nN, status[[p]]], {p, 1, np}];
   (* the destructuring Set must never be able to abort the whole Module
      body: if seForceDirichlet does not match, dropList simply stays {} *)
   fd = seForceDirichlet[cls, ops, pred];
   If[TrueQ[MatchQ[fd, {_List, _List}]], {cls, dropList} = fd, dropList = {}];
   nInt = Table[Count[Flatten[cls[[p]]], "Interior"], {p, 1, np}];
   (* TRAP: a Table assigns its OWN result only after the whole body has
      run, so offP[[p - 1]] inside the body still saw the empty initial
      value {} and produced {}[[1]] -- patch 2's interior offsets were
      garbage.  (Total[nInt[[q]], {q, 1, p - 1}] does not work either: Part
      of a literal list with a symbolic index does not evaluate under Total.)
      Accumulate is the right tool. *)
   offP = Accumulate[Prepend[nInt, 0]];
   (* The shared blocks sit AFTER every patch's interior block, so block m
      starts at Total[nInt] + (m-1) nmi.  The old Sum[nInt[[q]], {q, 1, p}]
      started the first shared block at nInt[[1]] = 225, which is exactly
      offP[[2]] = 225 -- the shared block and patch 2's interior block
      ALIASED each other from column 226 on, so patch 2 and the interface
      read and wrote the same unknowns. *)
   offI = Table[Total[nInt] + (p - 1) nmi, {p, 1, nif}];
   (* loc[[p]] must be a FLAT length-nn^2 vector of global column numbers,
      because that is how every reader indexes it:
        seFlatIndex[ix, iy, nn] = 1 + (ix-1) + nn (iy-1)   (xi fast)
      A stray extra {k, 1, nn2} iterator in front made it nn^2 x nn x nn,
      so loc[[p]][[k]] was a whole node MATRIX.  Positive[<matrix>] is not
      True, so the selection matrices came out empty and every column index
      below was silently wrong.  Invert seFlatIndex inside the Table. *)
   loc = Table[Block[{c}, c = 0;
       Table[If[cls[[p]][[Mod[k - 1, nn] + 1, Quotient[k - 1, nn] + 1]] === "Interior",
           offP[[p]] + (c++; c), 0], {k, 1, nn2}]], {p, 1, np}];
   Do[
     ndA = seEdgeNodes[ifs[[m]]["EdgeA"], nN];
     ndB = seEdgeNodes[ifs[[m]]["EdgeB"], nN];
     dq = If[TrueQ[ifs[[m]]["Orientation"] === "Reversed"], Reverse[Range[nmi]], Range[nmi]];
     Do[
       loc[[ifs[[m]]["PatchA"]]][[seFlatIndex[ndA[[j, 1]], ndA[[j, 2]], nn]]] = offI[[m]] + j;
       loc[[ifs[[m]]["PatchB"]]][[seFlatIndex[ndB[[dq[[j]]]][[1]], ndB[[dq[[j]]]][[2]], nn]]] = offI[[m]] + j,
       {j, 1, nmi}],
     {m, 1, nif}];
   (* TRAP: Sum takes at least an ITERATOR, so the one-argument Sum[nInt]
      silently stayed unevaluated (Sum::argmu) and poisoned nTot, nPde and
      every count derived from them.  Use Total for a list of counts. *)
   nTot = Total[nInt] + nif nmi;
   (* TRAP: Cases[list, pattern -> rhs] REPLACES every match with rhs, so
      Cases[..., {_, j_?Positive} -> _] collected Blank[] objects instead of
      rules and SparseArray rejected them: every selection matrix came out
      EMPTY, so no patch ever read its own unknowns and the whole assembled
      system was meaningless (silently -- the PDE and flux blocks still had
      the right SHAPE).  Filter the {node, column} pairs first, then turn the
      survivors into rules. *)
   sel = Table[Block[{rr},
       rr = ({#[[1]], #[[2]]} -> 1.) & /@
         Select[Table[{k, loc[[p]][[k]]}, {k, 1, nn2}], Positive[#[[2]]] &];
       SparseArray[rr, {nn2, nTot}]], {p, 1, np}];
   lf = Table[Table[0., {nn2}], {p, 1, np}];
   (* PDE blocks *)
   pde = Table[Block[{rows, Ls},
       dq = Flatten[Map[If[Lookup[#, "Patch"] === p, {Lookup[#, "Flat"]}, {}] &, dropList]];
       rows = If[dq === {}, ops[[p]]["InteriorRows"], Complement[ops[[p]]["InteriorRows"], dq]];
       Ls = ops[[p]]["Lop"][[rows]];
       <|"Patch" -> p, "Rows" -> rows, "RowCount" -> Length[rows],
         "Lop" -> Ls, "Selection" -> sel[[p]], "Matrix" -> (-Ls).sel[[p]]|>],
     {p, 1, np}];
   (* TRAP: `intf` is the Module local that carries the interface record of
      the pair being assembled; it MUST be bound to ifs[[m]] inside the loop.
      Leaving it unbound turned every intf["PatchA"] into a bare Part on a
      symbol (Part::pkspec1), seFluxSide was fed unevaluated arguments and
      every stored flux row (Sigma, FaceRowsA/B, NDopA/B, Matrix) was
      garbage -- yet the loop completed silently, so nothing ever raised. *)
   flux = Table[Block[{fs},
       intf = ifs[[m]];
       fs = seFluxSide[ops[[intf["PatchA"]]], ops[[intf["PatchB"]]], intf];
       <|"Pair" -> m, "PatchA" -> intf["PatchA"], "EdgeA" -> intf["EdgeA"],
         "PatchB" -> intf["PatchB"], "EdgeB" -> intf["EdgeB"],
         "Orientation" -> intf["Orientation"], "Sigma" -> fs["Sigma"],
         "NormalAgreement" -> fs["NormalAgreement"],
         "Coefficients" -> fs["Coefficients"], "FaceRowsA" -> fs["FaceRowsA"],
         "FaceRowsB" -> fs["FaceRowsB"], "Offset" -> offI[[m]],
         "RowCount" -> nmi, "NDopA" -> fs["NDopA"], "NDopB" -> fs["NDopB"],
         "Matrix" -> fs["NDopA"].sel[[intf["PatchA"]]]
           + fs["Coefficients"][[2]] fs["NDopB"].sel[[intf["PatchB"]]]|>],
     {m, 1, nif}];
   (* boundary records *)
   bnd = Table[Flatten[Table[
       If[cls[[p]][[ix, iy]] === "Dirichlet",
         <|"Patch" -> p, "Flat" -> seFlatIndex[ix, iy, nn],
           "Index" -> {ix - 1, iy - 1}, "X" -> N[ops[[p]]["Xs"][[ix, iy]]],
           "Y" -> N[ops[[p]]["Ys"][[ix, iy]]],
           "Edges" -> seEdgesAtNode[{ix, iy}, nN]|>, {}],
       {iy, 1, nn}, {ix, 1, nn}]], {p, 1, np}];
   bEdges = Table[Flatten[Table[
       If[status[[p, ei]] === "Boundary",
         <|"Patch" -> p, "Edge" -> seEdgesAll[[ei]], "Nodes" -> nn,
           "InteriorNodes" -> nmi,
           "Param" -> (seEdgeParam[seEdgesAll[[ei]], #, ops[[p]]["Nodes1D"]] &)
             /@ seEdgeNodesAll[seEdgesAll[[ei]], nN]|>, {}], {ei, 1, 4}]], {p, 1, np}];
   (* stacked row blocks *)
   blocks = Join[Table[<|"Kind" -> "PDE", "Index" -> p, "Rows" -> pde[[p]]["RowCount"]|>,
       {p, 1, np}], Table[<|"Kind" -> "Flux", "Index" -> m, "Rows" -> nmi|>, {m, 1, nif}]];
   mats = Join[Table[pde[[p]]["Matrix"], {p, 1, np}],
     Table[flux[[m]]["Matrix"], {m, 1, nif}]];
   slices = {}; r0 = 0; order = {};
   Do[slices = Join[slices, {<|"Kind" -> bl["Kind"], "Index" -> bl["Index"], "First" -> r0 + 1, "Last" -> r0 + bl["Rows"], "Count" -> bl["Rows"]|>}];

      order = Join[order, {bl["Kind"]}]; r0 = r0 + bl["Rows"], {bl, blocks}];
   nPde = Total[nInt]; nFlux = nif nmi; nRow = r0;
   (* API.md 4.4 SpectralDomain::iface: matched but the two traces are not
      tangent to each other, i.e. the pairing is geometrically inconsistent *)
   badN = Count[flux[[All, "NormalAgreement"]], _?(Abs[#] < 0.5 &)];
   If[badN > 0,
     Message[SpectralElement`SpectralDomain::iface, badN,
       "the matched traces are not mutually tangent (normal agreement < 0.5): the pairing is inconsistent"]];
   (* Stack the block matrices ROW-wise.  SparseArray's 2-argument form does
      NOT accept a list of SparseArrays, so the previous
      SparseArray[Flatten[ArrayPad[...]], {nRow, nTot}] silently produced a
      degenerate 1-D object (measured: Dimensions = {1}).

      TRAP (measured, three messages in a row, Kernel/Solve.wl L61-66
      documented the symptom without the cause): ArrayPad's padding
      specification must have ONE ENTRY PER DIMENSION OF THE ARRAY.  Every
      block here is RANK 2 (rows x UnknownCount), so the flat four-element
      spec {0, 0, 0, ...} is one entry too many and ArrayPad returns
      UNEVALUATED:

        ArrayPad::depth: Padding amount {0, 0, 0, 0} should specify padding in
          no more than the number of dimensions in array SparseArray[..,{49,49}].
        ArrayFlatten::depth: The ArrayDepth ... must be at least equal to the
          specified rank 2.
        SparseArray::list: List expected at position 1 in
          SparseArray[ArrayFlatten[{ArrayPad[..,{0,0,0,0}]}], {49, 49}].

      Because SparseArray[...] was handed an unevaluated head, it built an
      object of Dimensions {2} -- a 1 x nRow x nTot box -- and stored THAT as
      System["Matrix"], the public "Matrix" key.  It stayed SILENT to every
      consumer that does not look at it, which is why the only symptoms were
      the three message tags and D's Dimensions[Matrix] == {2} measurement.

      The fix has two parts, both required:
        * the rank-2 spec {{0,0},{0,pad}} (rank 1 would be {0, 0});
        * ArrayFlatten[list, 1], NOT the default rank 2.  With exactly ONE
          block the outer list is itself a level, so rank 2 asks for two
          levels and fails; level 1 merges everything below level 0, which is
          the vertical concatenation of the row blocks for ANY number of
          blocks including one. *)
   sysMat = SparseArray[ArrayFlatten[
       ArrayPad[#, {{0, 0}, {0, Max[0, nTot - Last[Dimensions[#]]]}}] & /@ mats,
       1], {nRow, nTot}];
   <|"Type" -> "SpectralSystem", "UnknownCount" -> nTot, "RowCount" -> nRow,
     "PDERowCount" -> nPde, "FluxRowCount" -> nFlux,
     "Class" -> cls, "Loc" -> loc, "Selections" -> sel, "Lift" -> lf,
     "PDE" -> pde, "Flux" -> flux, "Blocks" -> blocks, "RowOrder" -> order,
     "RowSlices" -> slices, "InteriorOffsets" -> offP, "SharedOffsets" -> offI,
     "InteriorCounts" -> nInt, "BoundaryNodes" -> bnd, "BoundaryEdges" -> bEdges,
     "ForcedDirichlet" -> dropList, "FluxCount" -> nif,
     "Matrix" -> sysMat,
     "BlockMatrices" -> mats|>];

(* =====================================================================
   Kernel/Discretization.wl -- SpectralElement` , DISCRETIZATION LAYER
   ---------------------------------------------------------------------
   Owner: geometry/discretization wave (Wave 1).  Loaded by
   Kernel/SpectralElement.wl from INSIDE Begin["SpectralElement`Private`"].

   CONTRACT RULES OBSERVED HERE
     * NO BeginPackage / Begin / End.  Bare symbols (all prefixed `se`)
       land in SpectralElement`Private`; public symbols are FULLY
       QUALIFIED (SpectralElement`SpectralDomain, ...Data, ...Q).

   WHAT THIS FILE DOES
     1. sePatchOps       one patch -> grid, metric fields, Jacobian,
                         J (+Delta convention) Laplacian, FD-Jacobian
                         check, interior row list.   (p11 `mkOps` verbatim)
     2. interface        every patch edge is sampled at the 1-D CGL nodes
                         (endpoints + interior); two edges of two patches
                         are the SAME geometric edge iff the samples agree
                         within InterfaceTolerance, either in the same or
                         in reversed order.  Matched pairs share ONE
                         unknown per physical node (point pairing, no
                         cross-grid interpolation) and get one
                         normal-flux continuity row per shared node.
                         Unmatched edges are the domain boundary.
     3. seAssemble       the global system: per-patch selection matrices
                         M_p (nn^2 x nTot), the interior Laplace row
                         blocks -Lop_sub . M_p, the flux row blocks
                         (n_A . M_A + c_B . n_B), the boundary (Dirichlet)
                         node records, and the stacked sparse Matrix.
                         Dirichlet nodes are ELIMINATED by lifting (p11's
                         verified arrangement), so the system stays square:
                             rows = unknowns = sum (n-1)^2 + k(n-1).
     4. gates            seMinJ, seNonPositiveJ, seFDJ, seFlatDegeneracy,
                         seFluxJump, sePdeResidual, seExactGlobal,
                         seExactResiduals.

   SIGN CONVENTION (p11-pinned, do not change)
     Lop = +Lap.  A PDE row is built as  -Lop . u + <nonlinear> = f.
     nodeVec: xi is the FAST index; KroneckerProduct's SECOND argument
     acts on the fast index (Kron[Id, D2m] multiplies u_xixi).
   ===================================================================== *)

(* ---------------------------------------------------------------------
   1.  Node / row bookkeeping
   --------------------------------------------------------------------- *)

(* flat (xi-fast) index of the node with 1-BASED reference indices *)
seFlatIndex[ix_, iy_, nn_] := 1 + (ix - 1) + nn (iy - 1);

seEdgesAll = {"Bottom", "Top", "Left", "Right"};
seEdgeCoord[edge_String] := If[MemberQ[{"Bottom", "Top"}, edge], "Eta", "Xi"];
seEdgeFn[edges_List, edge_String] :=
  edges[[Switch[edge, "Bottom", 1, "Top", 2, "Left", 3, "Right", 4]]];

(* ALL nn nodes of one edge, in edge-parameter order, 1-based {ix, iy} *)
seEdgeNodesAll[edge_String, nN_Integer] := Module[{nn = nN + 1},
  Switch[edge,
    "Bottom", Table[{ix, 1}, {ix, nn}],
    "Top",    Table[{ix, nn}, {ix, nn}],
    "Left",   Table[{1, iy}, {iy, nn}],
    "Right",  Table[{nn, iy}, {iy, nn}]]];

(* INTERIOR nodes of an edge: the two patch vertices removed.
   TRAP: Drop[l, {1, -1}] does NOT mean "first and last" -- a Part/Level
   specification {n1, n2} is a RANGE, and -1 counts from the end, so it
   dropped positions 1 .. Last and returned {} for every edge.  Every
   shared-node loop therefore iterated over an empty list and silently
   marked nothing, which is why no node ever came out as "Shared" and no
   shared unknown ever got a global column.  Use an explicit Part range. *)
seEdgeNodes[edge_String, nN_Integer] := seEdgeNodesAll[edge, nN][[2 ;; -2]];

seEdgeParam[edge_String, {ix_, iy_}, xg_List] :=
  If[MemberQ[{"Bottom", "Top"}, edge], xg[[ix]], xg[[iy]]];

(* the edge curve sampled at every 1-D CGL node, in edge-parameter order *)
seEdgeSamples[patch_, edge_String, xg_List] := Module[
   {f = seEdgeFn[sePatchEdges[patch], edge],
    nd = seEdgeNodesAll[edge, Length[xg] - 1]},
   f /@ (seEdgeParam[edge, #, xg] & /@ nd)];

(* Same curve?  "Same" = node k of A is node k of B; "Reversed" = node k of
   A is node nn+1-k of B (the pair is still EXACT pointwise). *)
seEdgeMatch[sa_List, sb_List, tol_] := Module[
   {d1 = Max[Flatten[Abs[sa - sb]]], d2 = Max[Flatten[Abs[Reverse[sa] - sb]]]},
   Which[d1 <= tol, {"Same", d1}, d2 <= tol, {"Reversed", d2},
         True, {"None", Min[d1, d2]}]];

(* ---------------------------------------------------------------------
   2.  Per-patch operator table  (p11 mkOps, +Delta convention)
   --------------------------------------------------------------------- *)
sePatchOps[patch_Association, nN_Integer] := Module[
   {nn = nN + 1, xg, sm, Xs, Ys, Dm, D2m, xxi, xe, yxi, ye, Jm, al, be, ga, de,
    AA, BB, CCc, d10, d01, Lop, intRows, i0, j0, x0, y0, h, xip, xet, yip, yet,
    jfd, fdrel, Id, AB, SQE, SQX},
   sm = patch["Map"];
   xg = seCGL[-1., 1., nn];
   {Xs, Ys} = sePatchGrid[sm, xg];
   Dm = seChebD1[xg]; D2m = Dm.Dm;
   xxi = Dm.Xs; xe = Xs.Transpose[Dm]; yxi = Dm.Ys; ye = Ys.Transpose[Dm];
   Jm = xxi*ye - xe*yxi;
   al = ye/Jm; be = -yxi/Jm; ga = -xe/Jm; de = xxi/Jm;
   AA = al^2 + ga^2; BB = 2 (al be + ga de); CCc = be^2 + de^2;
   d10 = al*(Dm.al) + be*(al.Transpose[Dm]) + ga*(Dm.ga) + de*(ga.Transpose[Dm]);
   d01 = al*(Dm.be) + be*(be.Transpose[Dm]) + ga*(Dm.de) + de*(de.Transpose[Dm]);
   vv[v_] := SparseArray[Band[{1, 1}] -> seNodeVec[v]];
   Id = SparseArray[IdentityMatrix[nn]];
   Lop = vv[AA].KroneckerProduct[Id, SparseArray[D2m]]
       + vv[BB].KroneckerProduct[SparseArray[Dm], SparseArray[Dm]]
       + vv[CCc].KroneckerProduct[SparseArray[D2m], Id]
       + vv[d10].KroneckerProduct[Id, SparseArray[Dm]]
       + vv[d01].KroneckerProduct[SparseArray[Dm], Id];
   intRows = Flatten[Table[seFlatIndex[ix + 1, iy + 1, nn], {iy, 1, nN - 1}, {ix, 1, nN - 1}]];
   i0 = Floor[nn/2]; j0 = i0; x0 = xg[[i0]]; y0 = xg[[j0]]; h = 1.*^-6;
   xip = (sm[x0 + h, y0][[1]] - sm[x0 - h, y0][[1]])/(2 h);
   xet = (sm[x0, y0 + h][[1]] - sm[x0, y0 - h][[1]])/(2 h);
   yip = (sm[x0 + h, y0][[2]] - sm[x0 - h, y0][[2]])/(2 h);
   yet = (sm[x0, y0 + h][[2]] - sm[x0, y0 - h][[2]])/(2 h);
   jfd = xip*yet - xet*yip;
   fdrel = Abs[jfd - Jm[[i0, j0]]]/Abs[Jm[[i0, j0]]];
   AB = al be + ga de; SQE = Sqrt[be^2 + de^2]; SQX = Sqrt[al^2 + ga^2];
   <|"Type" -> "SpectralPatchOps", "Patch" -> patch, "Order" -> nN,
     "Nodes" -> nn, "Nodes1D" -> xg, "Xs" -> Xs, "Ys" -> Ys,
     "Dm" -> Dm, "D2m" -> D2m, "J" -> Jm,
     "MinJ" -> N[Min[Flatten[Jm]]],
     "NonPositiveJ" -> Count[Flatten[Jm], _?(# <= 0 &)],
     "CornerJ" -> N /@ {Jm[[1, 1]], Jm[[nn, 1]], Jm[[1, nn]], Jm[[nn, nn]]},
     "al" -> al, "be" -> be, "ga" -> ga, "de" -> de,
     "AA" -> AA, "AB" -> AB, "BB" -> BB, "CC" -> CCc,
     "SQ" -> SQE, "SQXi" -> SQX,
     "Lop" -> Lop, "InteriorRows" -> intRows, "FDJ" -> N[fdrel]|>];

sePatchOpsQ[ops_] := TrueQ[AssociationQ[ops] && Lookup[ops, "Type"] === "SpectralPatchOps"];

(* the physical vector field normal to a reference coordinate line:
     grad eta = (be, de),  grad xi = (al, ga)        (Kron-consistent) *)
seNormalField[ops_, coord_String] :=
  Which[coord === "Eta", {ops["be"], ops["de"]},
        coord === "Xi",  {ops["al"], ops["ga"]}, True, $Failed];

(* Normal derivative along that unit normal.  This is p11's NDop:
     d/dn_eta = (AB/SQ) d/dxi + SQ d/deta ,  SQ = |grad eta| = Sqrt[be^2+de^2]
     (on p11's annular patches AB = 0 identically, so NDop = d/dn = d/dr,
      which is why the half-annulus flux row is NDopA - NDopB.)
   The xi analogue is given for completeness (needed when two patches share
   a xi = const edge). *)
seNormalOp[ops_, coord_String] := Module[
   {nn = ops["Nodes"], Dm = ops["Dm"], Id, Dxi, Deta, vv, S},
   (* TRAP: a Module initializer does NOT see the value of an EARLIER
      initializer in the same list (measured: Module[{nn = i, Id =
      SparseArray[IdentityMatrix[nn]]}, ..] raises SparseArray::list with nn
      still a symbol).  Every dependent initializer therefore has to be
      assigned in the BODY, after the ones it reads. *)
   Id = SparseArray[IdentityMatrix[nn]];
   vv[v_] := SparseArray[Band[{1, 1}] -> seNodeVec[v]];
   Dxi = KroneckerProduct[Id, SparseArray[Dm]];
   Deta = KroneckerProduct[SparseArray[Dm], Id];
   S = If[coord === "Eta", ops["SQ"], ops["SQXi"]];
   Which[coord === "Eta", vv[ops["AB"]/S].Dxi + vv[S].Deta,
         coord === "Xi",  vv[S].Dxi + vv[ops["AB"]/S].Deta, True, $Failed]];

(* ---------------------------------------------------------------------
   3.  Interface detection and node classification
   --------------------------------------------------------------------- *)

seFindInterfaces[ops_List, tol_] := Module[{np = Length[ops], used = {}, ifs = {},
     i, j, e1, e2, sa, sb, st, dev},
   Do[
     Do[
       (* i != j: only an edge of patch i and an edge of a DIFFERENT patch j
          can form an interface.  Without this guard every edge matches
          ITSELF (trivially, deviation 0), so a one-patch domain reports four
          bogus interfaces, every patch pair is then flagged as a duplicate
          match, and multi-patch vertices appear where there are none.
          Pinned by G-B5 (exactly 1 interface) and G-B7 (0 and 2). *)
       If[i != j && ! MemberQ[used, {i, e1}] && ! MemberQ[used, {j, e2}],
         sa = seEdgeSamples[ops[[i]]["Patch"], e1, ops[[i]]["Nodes1D"]];
         sb = seEdgeSamples[ops[[j]]["Patch"], e2, ops[[j]]["Nodes1D"]];
         {st, dev} = seEdgeMatch[sa, sb, tol];
         If[st =!= "None",
           AppendTo[ifs, <|"PatchA" -> i, "EdgeA" -> e1, "PatchB" -> j,
             "EdgeB" -> e2, "Orientation" -> st, "Deviation" -> dev,
             "Nodes" -> Length[sa], "SharedNodes" -> Length[sa] - 2|>];
           used = Join[used, {{i, e1}, {j, e2}}]]],
       {j, 1, np}, {e2, seEdgesAll}],
     {i, 1, np}, {e1, seEdgesAll}];
   ifs];

seEdgeUsed[ifs_List, patch_Integer, edge_String] := Module[{hit = False},
   Do[If[(Lookup[ifs[[k]], "PatchA", -1] === patch && Lookup[ifs[[k]], "EdgeA", ""] === edge) ||
         (Lookup[ifs[[k]], "PatchB", -1] === patch && Lookup[ifs[[k]], "EdgeB", ""] === edge),
      hit = True], {k, 1, Length[ifs]}];
   hit];

seEdgeStatuses[np_Integer, ifs_List] := Table[
   Table[If[seEdgeUsed[ifs, p, seEdgesAll[[ei]]], "Interface", "Boundary"], {ei, 1, 4}],
   {p, 1, np}];

seEdgesAtNode[{ix_, iy_}, nN_Integer] :=
   Select[seEdgesAll, MemberQ[seEdgeNodesAll[#, nN], {ix, iy}] &];

(* node classes: "Interior" (own unknown) | "Shared" (one unknown per
   physical node, shared by two patches) | "Dirichlet" (lifted, known) *)
seClassifyPatch[nN_Integer, status_List] := Module[{nn = nN + 1, cls, ei, nd, k},
   cls = Table["Interior", {nn}, {nn}];
   Do[nd = seEdgeNodesAll[seEdgesAll[[ei]], nN];
      Do[cls[[nd[[k, 1]], nd[[k, 2]]]] = "Dirichlet", {k, 1, Length[nd]}], {ei, 1, 4}];
   Do[If[status[[ei]] === "Interface",
        nd = seEdgeNodes[seEdgesAll[[ei]], nN];
        Do[cls[[nd[[k, 1]], nd[[k, 2]]]] = "Shared", {k, 1, Length[nd]}]], {ei, 1, 4}];
   cls];

(* a node touching two or more interface edges is a multi-patch vertex *)
seJunctionCount[nN_Integer, status_List] := Module[{nn = nN + 1, cnt, ei, nd, k},
   cnt = Table[0, {nn}, {nn}];
   Do[If[status[[ei]] === "Interface", nd = seEdgeNodesAll[seEdgesAll[[ei]], nN];
        Do[cnt[[nd[[k, 1]], nd[[k, 2]]]]++, {k, 1, Length[nd]}]], {ei, 1, 4}];
   Length[Position[cnt, _?(# >= 2 &)]]];

(* Optional extra Dirichlet nodes from a BoundaryPredicate.  Only patch
   INTERIOR nodes may be forced: dropping a shared unknown would silently
   change the coupling, so those are refused with a message.  A forced
   interior node loses its unknown AND its PDE row, which keeps the
   system square. *)
seForceDirichlet[cls_List, ops_List, pred_] := Module[{np = Length[cls],
   out = cls, drop = {}, refused = 0, p, nn, ix, iy, c, x, y},
   If[pred === Automatic, Return[{out, drop}]];
   Do[
     nn = ops[[p]]["Nodes"];
     Do[
       c = out[[p]][[ix, iy]];
       If[c =!= "Dirichlet",
         x = N[ops[[p]]["Xs"][[ix, iy]]]; y = N[ops[[p]]["Ys"][[ix, iy]]];
         If[TrueQ[pred[{x, y}]],
           Which[c === "Interior",
                 (out[[p]][[ix, iy]] = "Dirichlet";
                  AppendTo[drop, <|"Patch" -> p, "Flat" -> seFlatIndex[ix, iy, nn],
                     "Index" -> {ix - 1, iy - 1}, "X" -> x, "Y" -> y|>]),
                 c === "Shared", refused++,
                 True, Null]]],
       {iy, 1, nn}, {ix, 1, nn}],
     {p, 1, np}];
   If[refused > 0, Message[SpectralElement`SpectralDomain::bpred, refused]];
   {out, drop}];

(* ---------------------------------------------------------------------
   4.  The interface flux row
   ---------------------------------------------------------------------
   The two normal operators are built from the SAME metric fields as the
   Laplacian:  n_eta = (be, de)/|grad eta|,  n_xi = (al, ga)/|grad xi|.
   Sigma = sign of n_A . n_B at the paired nodes:
     Sigma = +1  ->  the row is  NDopA.u_A - NDopB.u_B  (p11 E2, verbatim)
     Sigma = -1  ->  the row is  NDopA.u_A + NDopB.u_B
   B's face rows are PERMUTED into A's order when the two edges are
   traversed in opposite directions, so every row pairs one exact
   physical node with its twin. *)
seFluxSide[opsA_, opsB_, intf_] := Module[
   {nN = opsA["Order"], nn = opsA["Nodes"], coordA, coordB, revQ, ndA, ndB, rowsA,
    rowsB, ord, nfA, nfB, unA, unB, pa, pb, dp, sig},
   coordA = seEdgeCoord[intf["EdgeA"]]; coordB = seEdgeCoord[intf["EdgeB"]];
   revQ = TrueQ[intf["Orientation"] === "Reversed"];
   ndA = seEdgeNodes[intf["EdgeA"], nN]; ndB = seEdgeNodes[intf["EdgeB"], nN];
   rowsA = (seFlatIndex[#[[1]], #[[2]], nn] &) /@ ndA;
   ord = If[revQ, Reverse[Range[nN - 1]], Range[nN - 1]];
   rowsB = (seFlatIndex[ndB[[#]][[1]], ndB[[#]][[2]], nn] &) /@ ord;
   (* TRAP: seNormalField returns the PAIR of PHYSICAL components of the
      gradient as a two-element list {c1, c2} of node matrices -- it is NOT a
      scalar field.  Part[..., i, j] on that list is a Part on a depth-2
      object, so for i, j > 1 it stayed unevaluated, Normalize passed it
      through unchanged, and the agreement dot product was formed from
      garbage -- which is where Sigma = -1 came from.  Take the two
      components explicitly. *)
   nfA = seNormalField[opsA, coordA]; nfB = seNormalField[opsB, coordB];
   (* Build the node lists straight in the FLAT layout
      k = 1 + (ix-1) + nn (iy-1) (xi fast).  Going through seNodeVec =
      Flatten[Transpose[..]] on a table of PAIRS would transpose the pair
      axis as well and produce 2 nn^2 scalars, so unA[[rowsA]] handed back
      bare components instead of unit vectors. *)
   unA = Table[N[Normalize[{nfA[[1]][[Mod[k - 1, nn] + 1, Quotient[k - 1, nn] + 1]],
      nfA[[2]][[Mod[k - 1, nn] + 1, Quotient[k - 1, nn] + 1]]}]], {k, 1, nn^2}];
   unB = Table[N[Normalize[{nfB[[1]][[Mod[k - 1, nn] + 1, Quotient[k - 1, nn] + 1]],
      nfB[[2]][[Mod[k - 1, nn] + 1, Quotient[k - 1, nn] + 1]]}]], {k, 1, nn^2}];
   pa = unA[[rowsA]]; pb = unB[[rowsB]];
   dp = N[Mean[Flatten[Table[pa[[k]][[1]] pb[[k]][[1]] + pa[[k]][[2]] pb[[k]][[2]], {k, 1, Length[pa]}]]]];
   sig = If[TrueQ[dp > 0], 1, -1];
   <|"CoordA" -> coordA, "CoordB" -> coordB, "FaceRowsA" -> rowsA,
     "FaceRowsB" -> rowsB, "NormalAgreement" -> dp, "Sigma" -> sig,
     "NDopA" -> seNormalOp[opsA, coordA][[rowsA]],
     "NDopB" -> seNormalOp[opsB, coordB][[rowsB]],
     "Coefficients" -> {1, -sig}|>];

(* ---------------------------------------------------------------------
   5.  Global assembly
   ---------------------------------------------------------------------
   Unknown layout (0-based offsets, 1-based column numbers):
     block 1..np   : the patch interior unknowns, patch order, ascending
                      flat node index inside the patch
     block np+1..   : one shared block per interface pair, in the node
                      order of side A ( = physical node order )
   Row layout: PDE rows of patch 1, of patch 2, ... then one flux row per
   interface pair.  Dirichlet nodes produce NO row (they are lifted), so
   rows = unknowns = sum_p (n-1)^2 + #(interfaces) (n-1). *)

(* The gates hand these in as NAMED down-values (uex[x_, y_] := ...), not as
   pure Function objects, so the patterns must NOT require _Function: the bare
   symbol uex does not match g_Function and every call stayed unevaluated.
   They only have to be callable as f[x, y]. *)
(* ---------------------------------------------------------------------
   6.  Dirichlet lift and exact-solution helpers  (used by the gates and,
       unchanged, by the Newton layer)
   --------------------------------------------------------------------- *)

(* TRAP -- MEASURED, and it was the WHOLE no-DirichletCondition hang
   (Tests/out/installprobe.104951_54302.txt, 900 s guard; the numbers below are
   from Tests/out/d2_r3diag.*.txt).  With no DirichletCondition in the equation
   the caller hands this routine the bare NUMBER 0 -- the homogeneous-Dirichlet
   default of API.md 4.3, seDirLiftFn[{}, _, _] := 0 -- and 0 is not callable.
   g[qx, qy] on it is the PRECISION-TAGGED zero 0.[qx, qy]: its head is 0., its
   magnitude is zero, but NumericQ is False, N[] passes it through untouched
   (InputForm[N[0[-1., -1.]]] is 0.[-1., -1.], NumericQ of it is False, and
   0.[-1., -1.] === 0. is False), which is why N[] here did not help.
   Writing that into the lift is not cosmetic.  On a one-patch degree-8 domain
   ALL 32 Dirichlet entries became tagged zeros while the 49 interior entries
   stayed clean 0., so seLiftConst came back with 49 of 49 entries
   NON-NUMERIC -- sums such as 131.14408626202*0.[-1., -0.9238...] -- rhs - c0
   stayed symbolic, and LinearSolve on a perfectly numeric 49 x 49 matrix never
   returned.  The SAME matrix against a plain numeric right-hand side returned a
   49-vector in 0.000415 s with max|A0.z| = 0 exactly.

   The node value is therefore taken HERE, at the routine whose output contract
   is a numeric vector: a NUMBER g is the constant it stands for -- which is
   precisely what the no-DC case passes -- and anything else is called as
   f[qx, qy] and N[]-ed, exactly as before.  Nothing is substituted, clamped or
   discarded, and no Quiet is involved: a lift that is still non-numeric is
   REFUSED by the caller (SpectralNDSolve::nlift), never assembled. *)
seLiftNode[g_, qx_, qy_] := N[If[TrueQ[NumericQ[g]], g, g[qx, qy]]];

(* per patch: an nn^2 vector holding g at the Dirichlet nodes, 0 elsewhere *)
seLiftFrom[disc_, g_] := Module[{o = disc["PatchOps"], cl = disc["Class"],
   nn = disc["NodeCount"]},
   Table[seNodeVec[Table[If[TrueQ[cl[[p]][[ix, iy]] === "Dirichlet"],
       seLiftNode[g, o[[p]]["Xs"][[ix, iy]], o[[p]]["Ys"][[ix, iy]]], 0.],
     {ix, 1, nn}, {iy, 1, nn}]], {p, Length[o]}]];

(* which (interface, position) does a Shared node of patch p belong to? *)
seSharedSlot[disc_, p_, ix_, iy_] := Module[{nn = disc["NodeCount"],
     k, g, off, m},
   (* k depends on nn: see the Module-initializer trap noted in seNormalOp *)
   k = seFlatIndex[ix, iy, nn];
   g = disc["System"]["Loc"][[p]][[k]];
   off = disc["System"]["SharedOffsets"];
   m = SelectFirst[Range[Length[off]], (g > off[[#]] && g <= off[[#]] + nn - 2) &];
   {m, g - off[[m]]}];

(* the exact global vector of g: interior nodes from their own patch,
   shared nodes averaged over the (identical) incident physical points *)
seExactGlobal[disc_, g_] := Module[{o = disc["PatchOps"],
     cl = disc["Class"], loc = disc["System"]["Loc"],
     off = disc["System"]["SharedOffsets"], nn = disc["NodeCount"],
     nTot = disc["System"]["UnknownCount"],
     np, nmi, acc, cnt, U, p, ix, iy, k, c, v, sj, m},
   (* np, nmi, acc, cnt and U all read o / nn / off / nTot, which are other
      initializers -- see the Module-initializer trap noted in seNormalOp *)
   np = Length[o]; nmi = nn - 2;
   acc = ConstantArray[0., {Length[off], nmi}];
   cnt = ConstantArray[0, {Length[off], nmi}];
   U = Table[0., {nTot}];
   Do[
     k = seFlatIndex[ix, iy, nn]; c = cl[[p]][[ix, iy]];
     If[c =!= "Dirichlet",
       v = N[g[o[[p]]["Xs"][[ix, iy]], o[[p]]["Ys"][[ix, iy]]]];
       If[c === "Interior", U[[loc[[p]][[k]]]] = v,
         sj = seSharedSlot[disc, p, ix, iy];
         acc[[sj[[1]], sj[[2]]]] += v; cnt[[sj[[1]], sj[[2]]]] += 1]],
     {iy, 1, nn}, {ix, 1, nn},
   {p, 1, np}];
   Do[If[cnt[[m, j]] > 0, U[[off[[m]] + j]] = acc[[m, j]]/cnt[[m, j]]],
  {m, Length[off]}, {j, 1, nmi}];
   U];

(* right-hand side sampled on the PDE rows, in InteriorRows order *)
seFvec[disc_, p_Integer, f_] := Module[{o = disc["PatchOps"][[p]],
   nn = disc["NodeCount"]},
   Flatten[Table[N[f[o["Xs"][[ix + 1, iy + 1]], o["Ys"][[ix + 1, iy + 1]]]],
     {iy, 1, nn - 2}, {ix, 1, nn - 2}]]];

(* G7: the interface flux row applied to the EXACT grid functions of g,
   one per patch, on the exact shared physical nodes (p11's g7). *)
seFluxJump[disc_, m_Integer, g_] := Module[{o = disc["PatchOps"],
     f = disc["System"]["Flux"][[m]], nn = disc["NodeCount"], uA, uB, dA, dB},
   dA = o[[f["PatchA"]]]; dB = o[[f["PatchB"]]];
   uA = seNodeVec[Table[N[g[dA["Xs"][[ix, iy]], dA["Ys"][[ix, iy]]]], {ix, 1, nn}, {iy, 1, nn}]];
   uB = seNodeVec[Table[N[g[dB["Xs"][[ix, iy]], dB["Ys"][[ix, iy]]]], {ix, 1, nn}, {iy, 1, nn}]];
   N[seEmx[f["Coefficients"][[1]] f["NDopA"].uA
      + f["Coefficients"][[2]] f["NDopB"].uB]]];

(* G6: the assembled blocks evaluated on the exact solution.  PDE blocks
   go through the ASSEMBLED sparse Matrix (so the matrix itself is under
   test) plus the lift, then + nonlinear(g) - f. *)
seExactResiduals[disc_, g_, f_, nl_] := Module[
   {z = seExactGlobal[disc, g], lf = seLiftFrom[disc, g], s = disc["System"],
    o = disc["PatchOps"], pde, flux},
   pde = Table[Module[{Up, rows, res},
       rows = o[[p]]["InteriorRows"];
       Up = s["Selections"][[p]].z + lf[[p]];
       res = s["PDE"][[p]]["Matrix"].z - s["PDE"][[p]]["Lop"].lf[[p]]
         + (nl /@ Up[[rows]]) - seFvec[disc, p, f];
       seEmx[res]], {p, Length[o]}];
   flux = Table[Module[{f, A, B},
       f = s["Flux"][[m]]; A = f["PatchA"]; B = f["PatchB"];
       seEmx[f["Matrix"].z + f["Coefficients"][[1]] f["NDopA"].lf[[A]]
         + f["Coefficients"][[2]] f["NDopB"].lf[[B]]]], {m, s["FluxCount"]}];
   <|"PDE" -> pde, "Flux" -> flux|>];

(* ---------------------------------------------------------------------
   7.  Public: SpectralDomain / SpectralDomainQ / SpectralDomainData
   --------------------------------------------------------------------- *)

Options[SpectralElement`SpectralDomain] =
  {Method -> "Analytic", InterfaceTolerance -> 1.*^-10, "InterfaceTolerance" -> 1.*^-10,
   BoundaryPredicate -> Automatic, "BoundaryPredicate" -> Automatic,
   CornerTolerance -> 1.*^-12};

seResolveDomainOpts[opts : OptionsPattern[SpectralElement`SpectralDomain]] := Module[
   {a = OptionValue[InterfaceTolerance], b = OptionValue["InterfaceTolerance"],
    c = OptionValue[BoundaryPredicate], d = OptionValue["BoundaryPredicate"]},
   <|"Method" -> OptionValue[Method],
     "InterfaceTolerance" -> Which[! TrueQ[AutomaticQ[b]], b, ! TrueQ[AutomaticQ[a]], a, True, 1.*^-10],
     "BoundaryPredicate" -> Which[! TrueQ[AutomaticQ[d]], d, ! TrueQ[AutomaticQ[c]], c, True, Automatic],
     "CornerTolerance" -> OptionValue[CornerTolerance]|>];

SpectralElement`SpectralDomain::nrange = "SpectralDomain: the degree must be an integer >= 2, got `1`.";
SpectralElement`SpectralDomain::patches = "SpectralDomain: the first argument must be a list of CoonsPatch objects (all at the same degree).  Offending element: `1`.";
SpectralElement`SpectralDomain::nreg = "SpectralDomain: the region `1` is not supported: `2`";
SpectralElement`SpectralDomain::iface = "SpectralDomain::iface -- `1`; edges matched within InterfaceTolerance but `2`.";
SpectralElement`SpectralDomain::span = "SpectralDomain: the annular angular span `1` exceeds 2 Pi.";
SpectralElement`SpectralDomain::degen = "SpectralDomain: patch `1` has a non-positive Jacobian (min J = `2`); the transfinite map is degenerate or flipped.";
SpectralElement`SpectralDomain::junc = "SpectralDomain: `1` node(s) touch two or more interface edges.  Multi-patch VERTICES are not supported in this wave: those vertices are treated as boundary (Dirichlet) nodes.";
SpectralElement`SpectralDomain::bpred = "SpectralDomain: BoundaryPredicate marked `1` node(s) that lie on a SHARED interface edge; those are refused (a shared unknown cannot simply be dropped).";
SpectralElement`SpectralDomain::key = "SpectralDomainData: `1` is not a key of a SpectralDiscretization.  Known keys: `2`.";
SpectralElement`SpectralDomain::form = "SpectralDomainData: `1` is not a SpectralDiscretization object.";

seDataKeys = {"PatchCount", "Degree", "Nodes", "NodeCount", "NodesPerPatch",
  "UnknownCount", "RowCount", "Patches", "PatchMap", "Coordinates", "X", "Y",
  "Jacobian", "MinJacobian", "NonPositiveJacobianCount", "CornerJacobian",
  "FDJacobian", "Laplacian", "InteriorRows", "InteriorRowCounts",
  "NormalOperator", "InterfacePairs", "InterfaceCount", "EdgeStatus",
  "BoundaryEdges", "BoundaryRows", "FluxRows", "Class", "Selections", "Matrix", "PatchOps",
  "RowOrder", "RowSlices", "Lift", "System", "Method", "InterfaceTolerance",
  "CornerTolerance", "Junctions"};

seBuildDomain[patches_List, nN_Integer, o_Association] := Module[
   {ops, ifs, status, sys, disc, jc, bad, seen, dup, pp, q},
   If[! And @@ (SpectralElement`CoonsPatchQ /@ patches),
     Message[SpectralElement`SpectralDomain::patches, seTrunc[patches]]; Return[$Failed]];
   ops = sePatchOps[#, nN] & /@ patches;
   bad = Table[If[TrueQ[ops[[p]]["MinJ"] <= 0], p, Nothing], {p, Length[ops]}];
   (* J <= 0 at a patch VERTEX is reported already by CoonsPatch::tangent;
      J <= 0 anywhere else is a flipped or self-overlapping patch. *)
   If[bad = {}, Null,
     Message[SpectralElement`SpectralDomain::degen, seTrunc[bad],
       seTrunc[Table[ops[[p]]["MinJ"], {p, bad}]]]];
   ifs = seFindInterfaces[ops, o["InterfaceTolerance"]];
   (* API.md 4.4: an interface matched twice is an error, not a silent union *)
   seen = {}; dup = 0;
   Do[pp = Sort[{ifs[[q]]["PatchA"], ifs[[q]]["PatchB"]}];
      If[MemberQ[seen, pp], dup++, seen = Join[seen, {pp}]], {q, Length[ifs]}];
   If[dup > 0,
     Message[SpectralElement`SpectralDomain::iface, dup,
       "the same pair of patches was matched along two different edges"]];
   status = seEdgeStatuses[Length[ops], ifs];
   sys = seAssemble[patches, ops, ifs, status, nN, o["BoundaryPredicate"]];
   jc = Total[Table[seJunctionCount[nN, status[[p]]], {p, Length[ops]}]];
   If[jc > 0, Message[SpectralElement`SpectralDomain::junc, jc]];
   disc = <|"Type" -> "SpectralDiscretization", "Domain" -> "SpectralElement`",
     "Degree" -> nN, "NodeCount" -> Length[ops[[1]]["Nodes1D"]],
     "Nodes" -> ops[[1]]["Nodes1D"], "PatchCount" -> Length[ops],
     "Patches" -> patches, "PatchMap" -> (Lookup[#, "Map"] &) /@ patches,
     "PatchOps" -> ops, "Interfaces" -> ifs, "InterfacePairs" -> Length[ifs],
     "EdgeStatus" -> status, "Class" -> sys["Class"], "System" -> sys,
     "Junctions" -> jc, "Method" -> o["Method"],
     "InterfaceTolerance" -> o["InterfaceTolerance"],
     "CornerTolerance" -> o["CornerTolerance"],
     "BoundaryPredicate" -> o["BoundaryPredicate"]|>];

SpectralElement`SpectralDomain[patches_List, n_Integer, opts : OptionsPattern[]] :=
   Module[{o = seResolveDomainOpts[], bad},
     If[n < 2, Message[SpectralElement`SpectralDomain::nrange, n]; Return[$Failed]];
     bad = Select[patches, ! TrueQ[SpectralElement`CoonsPatchQ[#]] &];
     If[bad =!= {},
       Message[SpectralElement`SpectralDomain::patches, seTrunc[First[bad]]];
       Return[$Failed]];
     seBuildDomain[patches, n, o]];

(* ---- region shorthands ------------------------------------------------ *)
SpectralElement`SpectralDomain[region_, n_Integer, opts : OptionsPattern[]] := Module[
   {o = seResolveDomainOpts[], pl, bad},
   pl = Which[
     MatchQ[region, Rectangle[_, _]],
       (If[region[[2]][[1]] <= region[[1]][[1]] || region[[2]][[2]] <= region[[1]][[2]],
          Message[SpectralElement`SpectralDomain::nreg, seTrunc[region], "need x2 > x1 and y2 > y1"];
          Return[$Failed]];
       {SpectralElement`CoonsPatch[seRectEdges[region[[1]], region[[2]]],
          Method -> o["Method"], CornerTolerance -> o["CornerTolerance"]]}),
     MatchQ[region, Annulus[_, _]],
       (If[region[[1, 1]] <= 0 || region[[1, 2]] <= region[[1, 1]],
          Message[SpectralElement`SpectralDomain::nreg, seTrunc[region], "need 0 < r1 < r2 (r1 = 0 gives J = 0)"];
          Return[$Failed]];
        seAnnulusPatches[region[[1]], region[[2]], o]),
     MatchQ[region, Disk[_, _]],
       (Message[SpectralElement`SpectralDomain::nreg, seTrunc[region],
          "a disk has r = 0 where the polar/transfinite map is singular (J = 0); use a patch with true corners or wait for the AAA mesh"];
        $Failed),
     True, (Message[SpectralElement`SpectralDomain::nreg, seTrunc[region],
        "only a CoonsPatch list, Rectangle or Annulus are supported"];
       $Failed)];
   If[! ListQ[pl], Return[$Failed]];
   bad = Select[pl, ! TrueQ[SpectralElement`CoonsPatchQ[#]] &];
   If[bad =!= {},
     Message[SpectralElement`SpectralDomain::patches, seTrunc[First[bad]]];
     Return[$Failed]];
   seBuildDomain[pl, n, o]];

(* angular sectors: one polar patch per sector of at most Pi *)
seAnnulusPatches[{r1_, r2_}, {t1_, t2_}, o_Association] := Module[
   {span = t2 - t1, t2c, ns, pl},
   If[span <= 0, t2c = t1 + span + 2 Pi; span = span + 2 Pi, t2c = t2];
   If[span > 2 Pi + 1.*^-12,
     Message[SpectralElement`SpectralDomain::span, N[span]]; Return[$Failed]];
   ns = Max[1, Ceiling[span/Pi]];
   pl = Table[SpectralElement`CoonsPatch[seAnnulusEdges[{r1, r2},
       {t1 + (j - 1) span/ns, t1 + j span/ns}],
     Method -> o["Method"], CornerTolerance -> o["CornerTolerance"]], {j, 1, ns}];
   pl];

SpectralElement`SpectralDomainQ[disc_] := TrueQ[AssociationQ[disc]
   && Lookup[disc, "Type"] === "SpectralDiscretization"
   && AssociationQ[Lookup[disc, "System", {}]]
   && Length[Lookup[disc, "PatchOps", {}]] >= 1];

SpectralElement`SpectralDomainData[disc_] := disc;

SpectralElement`SpectralDomainData[disc_, key_String] /;
   TrueQ[SpectralElement`SpectralDomainQ[disc]] := Module[{o = disc["PatchOps"],
     s = disc["System"], nn = disc["NodeCount"]},
   Switch[key,
    "PatchCount", disc["PatchCount"],
    "Degree", disc["Degree"],
    "Nodes", disc["Nodes"],
    "NodeCount", nn,
    "NodesPerPatch", nn^2,
    "UnknownCount", s["UnknownCount"],
    "RowCount", s["RowCount"],
    "Patches", disc["Patches"],
    "PatchMap", disc["PatchMap"],
    (* TRAP -- MEASURED (Tests/out/e_probe5.115628_60497.txt: KEY
       "Coordinates" head=Symbol nmsgs=12, every other key clean).  This
       branch was `(Table[{N[o[[p]]["Xs"][[ix, iy]]], ...}, {ix, 1, nn},
       {iy, 1, nn}] &) /@ Range[disc["PatchCount"]]` -- a pure function with
       NO parameter, so the mapped value was thrown away and `p` stayed
       unbound: o[[p]] was symbolic, the fetch returned $Failed after 12
       messages, and the key that exists to hand back the node coordinates
       handed back nothing.  Mapped over `o` with `#`, like the eleven
       branches below it.  PatchCount IS Length[ops] (the association is built
       with "PatchCount" -> Length[ops]), so the outer length is unchanged. *)
    "Coordinates", (Table[{N[#]["Xs"][[ix, iy]], N[#]["Ys"][[ix, iy]]},
        {ix, 1, nn}, {iy, 1, nn}] &) /@ o,
    "X", (Lookup[#, "Xs"] &) /@ o,
    "Y", (Lookup[#, "Ys"] &) /@ o,
    "Jacobian", (Lookup[#, "J"] &) /@ o,
    "MinJacobian", (Lookup[#, "MinJ"] &) /@ o,
    "NonPositiveJacobianCount", (Lookup[#, "NonPositiveJ"] &) /@ o,
    "CornerJacobian", (Lookup[#, "CornerJ"] &) /@ o,
    "FDJacobian", (Lookup[#, "FDJ"] &) /@ o,
    "Laplacian", (Lookup[#, "Lop"] &) /@ o,
    "InteriorRows", (Lookup[#, "InteriorRows"] &) /@ o,
    "InteriorRowCounts", (Length[Lookup[#, "InteriorRows"]] &) /@ o,
    "NormalOperator", (seNormalOp[#, "Eta"] &) /@ o,
    "InterfacePairs", disc["Interfaces"],
    "InterfaceCount", disc["InterfacePairs"],
    "EdgeStatus", disc["EdgeStatus"],
    "BoundaryEdges", s["BoundaryEdges"],
    "BoundaryRows", s["BoundaryNodes"],
    "FluxRows", s["Flux"],
    "Class", s["Class"],
    "Selections", s["Selections"],
    "PatchOps", disc["PatchOps"],
    "Matrix", s["Matrix"],
    "RowOrder", s["RowOrder"],
    "RowSlices", s["RowSlices"],
    "Lift", s["Lift"],
    "System", s,
    "Method", disc["Method"],
    "InterfaceTolerance", disc["InterfaceTolerance"],
    "CornerTolerance", disc["CornerTolerance"],
    "Junctions", disc["Junctions"],
    _, Message[SpectralElement`SpectralDomain::key, key, seTrunc[seDataKeys]];
      $Failed]];

(* NB the message must name the ARGUMENT that is wrong, not $Input: inside a
   Message issued from a Get-ed file, $Input is the name of the file being
   read, which told the reader nothing at all about the offending object.
   Pinned by G-B5 / G-B8. *)
SpectralElement`SpectralDomainData[args___] :=
   (Message[SpectralElement`SpectralDomain::form, seTrunc[{args}]]; $Failed);

(* ---------------------------------------------------------------------
   9.  Gates that live here for convenience of Tests/geoprobe.wl
   --------------------------------------------------------------------- *)

(* the domain shorthands build their patches through this wrapper, so the
   probe can check "the Rectangle shorthand is the identity transfinite
   map" without touching the option plumbing *)
seRegionPatch[region_, o_Association] := Which[
   MatchQ[region, Rectangle[_, _]],
     SpectralElement`CoonsPatch[seRectEdges[region[[1]], region[[2]]],
       Method -> o["Method"], CornerTolerance -> o["CornerTolerance"]],
   MatchQ[region, Annulus[_, _]],
     seAnnulusPatches[region[[1]], region[[2]], o],
   True, $Failed];

(* Public entry point of the assembler.  Kept as a one-line wrapper around
   seAssembleCore so that a load-time failure of the (very long) core body
   cannot leave the call site silently undefined -- which is exactly what
   happened once (Tests/out/b2ctx.*.txt). *)
seAssemble[patches_List, ops_List, ifs_List, status_List, nN_Integer, pred_] :=
  seAssembleCore[patches, ops, ifs, status, nN, pred];
