
/////////////// ModFrmHilD: Trace Precomputation ////////////////


/*
This file contains the following routines used for the Trace.m code:
  - HMFTracePrecomputation: A procedure that does the precomputations for the trace code (stores class number, unit index, and discriminants of rings of integers)
  - PrecomputeTraceForm: Does precomputations the trace form t
  - PrecomputeTraceForm: Does precomputations for a series of trace forms T(a_1)t, ..., T(a_n)t specified by a list of ideals [a_1,...,a_n]
  - LocalSquare: Stores values of local squares - in order to ensure that we don't repeat computations. (This can be removed if we)
*/

import "../SaveAndLoad.m": default_dir;


function TriplesFilename(ZF)
  F := NumberField(ZF);
  F_label := Join([IntegerToString(a) : a in DefiningPolyCoeffs(F)], ".");
  return default_dir() cat F_label cat "_triples";
end function;

procedure SaveTriples(triples)
  ZF := Universe(triples);
  filename := TriplesFilename(ZF);
  WriteObject(Open(filename, "w"), [<Eltseq(k), v[1], v[2], Eltseq(v[3])> : k->v in triples]);
end procedure;

function LoadTriples(ZF)
  filename := TriplesFilename(ZF);
  b, loadfile := OpenTest(filename, "r");
  B := AssociativeArray();
  if b then
    for elt in ReadObject(loadfile) do
      B[ZF!elt[1]] := <elt[2], elt[3], ideal<ZF|[ZF!x : x in elt[4]]>>;
    end for;
  end if;
  return B;
end function;


///////////////////////////////////////////////////
//                                               //
//      Precomputation: Class Number h,          //
//      Unit Indices w, and Discriminant DD.     //
//                                               //
///////////////////////////////////////////////////


/*
The function below computes and stores the items for the trace formula. Given a CM-extension K / F we store:
  - h = ClassNumber of K
  - w = Unit Indices of K/F. Remark: Since K/F is a CM-extension then by Dirichlets unit theorem the rank of ZK^* and ZF^* are the same.
        Hence it makes to consider the quantity [ ZK^* : ZF^* ] which can be explained by
  - DD = the discriminant of ZK
This proceedure is done in the following steps:
  Given the discriminant of an order D in CM-extension K = F( sqrt(D) ) over F, we do the following:

    - Pass 1: Given an ideal aa, we compute list of elements representing all of the orders O whose class number we need
              To compute Tr T(aa). These orders are represented by a single totally negative element D such that O = ZF[ sqrt(D) ].

    - Pass 2: We run a discriminant hash which computes a unique representative d for each discriminant D up to:
              (a) the squareclass of D in F* / F*^2
              (b) the action of automorphisms s : F -> F on D.

      This gives a ** minimal ** set of discriminants for which we need to compute the class numbers and unit indices

    - Pass 3: We compute h, w, DD as above for the minimal set of discriminants. These are stored to M`ClassNumbersPrecomputation with d0 -> [h, w, DD]
    - Pass 4: We remove bad discriminants D which don't satisfy a condition on their conductor (only for Cl(F) > 1). The rest are stored to M`PrecomputationforTrace as aa -> [ [D, d0], ... ]

  Once this is complete, we can the access all of the information for a discriminant D using the hash key d0 in the associative array ClassNumbersPrecomputation
*/

// FIXME: HMFTracePrecomputation - Pass tracebasis to IdealCMextensions instead of computing each time
intrinsic HMFTracePrecomputation(M::ModFrmHilDGRng, L::SeqEnum[RngOrdIdl] : SaveAndLoad:=true)
  {Precomputes class number and unit indices for a list of ideals L}

  // Do nothing if L is empty
  if #L eq 0 then
    return;
  end if;

  // initialize
  F := BaseField(M); // Base Field
  ZF := Integers(F); // Ring of Integers
  _<x> := PolynomialRing(F); // Polynomial ring over F
  UF := UnitGroup(M); // Unit Group of F
  mUF := UnitGroupMap(M); // Unit Group of F map
  C,mC := ClassGroup(F); // class group
  Creps := [ mC(i) : i in C ]; // class group representatives
  NCreps := NarrowClassGroupReps(M); // narrow class group representatives
  SetClassGroupBounds("GRH"); // Bounds

  // Assign automorphism to GradedRing (used in DiscriminantHash)
  if not assigned M`Automorphisms then
    M`Automorphisms := Automorphisms(F);
  end if;

  /////////// Hash function //////////
  // For each discriminant d, this hash function associates a unique element w in F representing the field F(x)/(x^2-d) up to isomorphism over QQ. It runs in two phases:
  //
  // *  Phase 1: Pick a unique representative for the square class of [d] in F*/F*2. Write the discriminant as d * ZF = mm * aa^2 with mm squarefree. Fix a set of representatives for the class group,
  //             and let [ bb ] = [ aa ] be the ideal representing the class of aa in CL(F). Then [aa * bb^(-1)] = (x) for some x in ZF so d * ZF = mm * bb^2 * (x)^2. Let d0 := d / x^2.
  //             Thus a unique representative for the square class of d can be picked as the "reduced fundamental domain rep generator" for -d0 with respect the square of the fundamental unit.
  //
  // *  Phase 2: Pick a unique representative for the square class of [d] up to Aut(F). If s : F -> F is a nontrivial automorphism, then fields F[x]/(x^2 - d) and F/(x^2 - s(d)) are isomorphic over QQ.
  //             We pick a unique representative d' among the conjugates of d by sorting the conjugates lexicographically according to their embeddings at a fixed set of real places. For this step,
  //             we store the automorphism group of F to the GradedRingofHMFS and then record the index c such that the automorphism f = Aut[c] satifies f(d') = d.
  //
  ///////////////////////////////////

  // This needs to be updated for general fields
  function DiscriminantHash(D)
    // Phase 1
    mm := D * ZF;
    aa := &*( [1*ZF] cat [ pp[1] ^ (pp[2] div 2) : pp in Factorization(mm)] ); // Note pp[2] div 2 = Floor(pp[2]/2)
    for bb in Creps do
      boo, x := IsPrincipal( aa * bb^(-1) );
      if boo then
        elt := FunDomainRep(M, -D / x^2 : Squares := true);
        d := ZF ! -elt;
        break;
      end if;
    end for;
    // assert IsSquare(D/d); // can be dropped

    // Phase 2
    // Sort conjugates lexicographically by size of embedding
    A := [ i : i in M`Automorphisms ];
    embs := [ RealEmbeddings(f(d)) : f in A ];
    ParallelSort(~embs, ~A);

    // select unique conjugate + index c such that f = M'Aut[c] satisfies f(d0) = d
    f  := A[1];
    d0 := ZF ! f(d);
    c  := Index( M`Automorphisms, f^(-1) );

    // return
    return d0, c;
  end function;


  // Precomputations
  A := TracePrecomputation(M);
  B := ClassNumbersPrecomputation(M);

  if SaveAndLoad then
    for k->v in LoadTriples(ZF) do
      B[k] := v;
    end for;
  end if;

  // First pass. A[mm][aa] := List of [b,a,D]
  vprintf HilbertModularForms, 1 : "start %o. \n", Cputime();

  Discs := {};
  ideals := Set(L) diff Keys(A); // ideals to precompute
  for mm in ideals do
    A[mm] := AssociativeArray();
    for aa in Creps do
      A[mm][aa] := [];
      if IsNarrowlyPrincipal(mm * aa^2) then
        Points := IndexOfSummation(M, mm, aa : precomp := true);
        for i in Points do
          b := i[1]; // Trace
          a := i[2]; // Norm
          D := b^2-4*a; // Discriminant
          A[mm][aa] cat:= [[b,a,D]];
          Include(~Discs, D);
        end for;
      end if;
    end for;
  end for;


  // Second pass. Compute a hash with unique discriminants up to squares.
  vprintf HilbertModularForms, 1 : "Pass 1 finished at %o. Now computing reduced discriminants for %o orders. \n", Cputime(), #Discs;

  Hash := AssociativeArray();
  RDiscs := {};
  for D in Discs do
    d, c := DiscriminantHash(D);
    Include(~RDiscs, d);
    Hash[D] := [d, c];
  end for;




  // Third pass. Compute ring of integers, class numbers, and unit index for new keys
  NK := RDiscs diff Keys(B);
  vprintf HilbertModularForms, 1 : "Pass 2 finished at %o. Now computing class numbers and unit indices for %o fields. \n", Cputime(), #NK;

  hplus := NarrowClassNumber(M); // Narrow class number
  for d in NK do
    h, w, DD := ClassNumberandUnitIndex(ZF, d, hplus); // Class group of K and Hasse Unit index
    // K = F(sqrt(-d))
    // h = h(K)
    // DD = disc(K)
    B[d] := <h, w, DD>;
  end for;

  if SaveAndLoad then
    SaveTriples(B);
  end if;


  // Fourth Pass. Removing pairs where ff/aa is not integral
  vprintf HilbertModularForms, 1 : "Pass 3 finished at %o. Now removing pairs where ff/aa is not integral. \n", Cputime();

  for mm in ideals do
    for aa in Creps do
      L := [];
      for i in A[mm][aa] do
        D := i[3];
        d, c := Explode( Hash[D] );
        f := M`Automorphisms[ Integers()!c ];
        DD := ZF !! f( B[d][3] ); // Discriminant
        ff := ideal < ZF | D*ZF * DD^(-1) >; // Conductor (squared)
        // remove pairs where ff/aa is not integral
        if ff subset aa^2 then
          L cat:= [ [i[1], i[2], d, c] ];
        end if;
      end for;
      A[mm][aa] := L;
    end for;
  end for;

  // verbose printing
  vprintf HilbertModularForms, 1 : "Pass 4 finished at %o. \n", Cputime();

  // Assign
  M`PrecomputationforTrace := A;
  M`ClassNumbersPrecomputation := B;

end intrinsic;


intrinsic PrecomputeTraceForm(M::ModFrmHilDGRng)
  { Precomputes values to generate traceforms tr }
  HMFTracePrecomputation(M, Ideals(M));
end intrinsic;


intrinsic PrecomputeTraceForms(M::ModFrmHilDGRng, L::SeqEnum[RngOrdIdl])
  {Given a list of ideals L = [aa,bb, ...], precomputes values to generate traceforms t_aa, t_bb, ... }
  A := SetToSequence({ ii * aa : ii in Ideals(M), aa in L }); // Set of ideals
  HMFTracePrecomputation(M,A);
end intrinsic;


/* Caching Local Squares
// Computing Artin symbols is the 3rd most expensive computation for the trace code (after class numbers and unit indices).
To compute the Artin symbol (K/pp) for the extension K = F[x] / (x^2 - D) and a prime pp, we need to
  (1) Compute the ring of integers ZK and check if pp | disc(ZK) => return 0
  (2) Check if D is a local square in the completion F_pp => return 1, else -1
Since the local square computation is performed many times, we store the results to M to avoid repeating computations */
intrinsic LocalSquare(M::ModFrmHilDGRng, d::RngOrdElt, pp::RngOrdIdl) -> RngIntElt
  {Checks if D is a local square in the completion F_pp}

  // initialize - LocalSquares[pp]
  if not IsDefined(M`LocalSquares,pp) then
    M`LocalSquares[pp] := AssociativeArray();
  end if;

  // initialize - LocalSquares[pp][d]
  if not IsDefined(M`LocalSquares[pp],d) then
    M`LocalSquares[pp][d] := IsLocalSquare(d,pp) select 1 else -1;
  end if;

  return M`LocalSquares[pp][d];
end intrinsic;
