///////////////////////////////////////////////////
//                                               //
//                Hecke Operators                //
//                                               //
///////////////////////////////////////////////////

///////////// ModFrmHilDElt: Hecke Operators ////////////////
intrinsic HeckeOperator(f::ModFrmHilDElt, mm::RngOrdIdl) -> ModFrmHilDElt
  {Returns T(mm)(f) for the character chi modulo the level of f}

  Mk := Parent(f);
  M := Parent(Mk);
  F := BaseField(M);
  Cl, mp := NarrowClassGroup(F);
  ZF := Integers(F);
  k := Weight(f);
  k0 := Max(k);
  chi := Character(Mk);
  K := CoefficientRing(f);

  R := GetHMFSerPuis(M, K);
  prec := Precision(f) div Norm(mm);
  Tmmf_bbs := AssociativeArray();

  for bb in NarrowClassGroupReps(M) do
    bbp := NarrowClassGroupRepsToIdealDual(M)[bb];
    bbpinv := bbp^(-1);

    Tmmf_bb_ser := RngSerPuisZero(R);
    for nu in FunDomainRepsUpToNorm(M, bb, prec) do //they come sorted
      nn := nu*bbpinv;  // already call nn the ideal for the Hecke operator
      c := 0;

      // loop over divisors
      // Formula 2.23 in Shimura - The Special Values
      // of the zeta functions associated with Hilbert Modular Forms
      for aa in Divisors(ZF!!(nn + mm)) do
        if nn eq 0*ZF then
          //takes care if the coefficients for the zero ideal are different
          c +:= StrongMultiply(K, [* chi(aa), Norm(aa)^(k0 - 1), Coefficients(f)[NarrowClassRepresentative(M, bb*mm/aa^2)][ZF!0] *]);
        else
          cf := Coefficient(f, ZF!!(aa^(-2) * nn * mm));
          c +:= StrongMultiply(K, [* chi(aa), Norm(aa)^(k0 - 1), cf *]);
        end if;
      end for;
      a_nu := IdlCoeffToEltCoeff(c, nu, k, CoefficientRing(Components(f)[bb])); 
      Tmmf_bb_ser +:= RngSerPuisMonomial(R, nu, a_nu);
    end for;
    Tmmf_bbs[bb] := Tmmf_bb_ser;
  end for;

  g := HMF(Mk, Tmmf_bbs : prec:=prec);

  // Attempting to increase precision using a basis
  if assigned Mk`Basis then
    g := IncreasePrecisionWithBasis(g, Mk`Basis);
  end if;
  
  return g;
end intrinsic;


///////////// Eigenbasis computation ////////////////

// This code computes an eigenbasis for a Hecke-stable space 
// of meromorphic ModFrmHilDElt objects by examining the action
// on the Fourier coefficients. 
//
// For most applications, the ModFrmHil/ or Trace.m code should be used. 

intrinsic Eigenbasis(M::ModFrmHilD, basis::SeqEnum[ModFrmHilDElt] : P := 60) -> SeqEnum[ModFrmHilDElt]
  {
    inputs:
      M: A space of forms on which the Hecke algebra acts by
           commuting self-adjoint operators.
      basis: A sequence of linearly independent ModFrmHilDElts
             whose span is preserved by all the Hecke operators.
      P: The largest norm of a prime ideal we check to establish a simultaneous eigenbasis
    returns:
      A sequence of HMFs which are an eigenbasis for the Hecke operators of primes
      up to P. The forms are normalized where possible.
  }
  
  MGRng := Parent(M);
  F := MGRng`BaseField;
  ZF := Integers(F);
  dd := Different(ZF);
  hecke_matrices := [];

  for pp in PrimesUpTo(P, F) do
    Append(~hecke_matrices, HeckeMatrix(basis, pp));
  end for;

  // B stores a matrix such that B * M * B^-1 is
  // diagonal for every Hecke matrix M. 
  // If e_i denotes the ith standard basis vector
  // and v_i denotes the ith eigenvector in the 
  // given basis, then this means that B^-1 e_i = v_i. 
  // Therefore, the ith column of B^-1 is v_i.
  _, B := Diagonalization(hecke_matrices);
  Binv := B^-1;

  eigs := [];

  // the columns of P should be the coefficients
  // of linear combinations of basis vectors giving
  // rise to eigenvectors
  // TODO is there really no way to get the columns of an AlgMatElt? 
  for v in Rows(Transpose(Binv)) do
    Append(~eigs, &+[v[i] * basis[i] : i in [1 .. #basis]]);
  end for;

  frob_traces := AssociativeArray();
  for eig in eigs do
    frob_traces[eig] := AssociativeArray(); 
    bb_1 := NarrowClassRepresentative(MGRng, dd);
    a_1 := Coefficients(eig)[bb_1][MGRng`IdealToRep[bb_1][ideal<ZF|1>]];

    for nn in IdealsUpTo(P, F) do
      bb := NarrowClassRepresentative(MGRng, nn^-1 * dd);
      frob_traces[eig][nn] := Coefficients(eig)[bb][MGRng`IdealToRep[bb][nn]] / a_1;
    end for;
  end for;
  return eigs, frob_traces;
end intrinsic;

intrinsic HeckeMatrix(basis::SeqEnum[ModFrmHilDElt], nn::RngOrdIdl) -> Mtrx
  {
    inputs:
      basis: A sequence of linearly independent ModFrmHilDElts
             whose span is preserved by all the Hecke operators.
      nn: An integral ideal indexing the Hecke operator
    returns:
      A matrix over corresponding to the action of the Hecke operator on
      this space. 
  }

  assert #LinearDependence(basis) eq 0;
  rows := [];

  for f in basis do
    g := HeckeOperator(f, nn);
    lindep := LinearDependence(basis cat [g]);
    require #lindep eq 1 : "Try increasing precision";
    lindep := lindep[1];
    // We will transpose at the end. 
    // For now, each row stores the
    // coefficients of the linear combination 
    // of basis vectors which give rise to g
    Append(~rows, [-1 * lindep[i] / lindep[#basis + 1] : i in [1 .. #basis]]);
  end for;

  return Transpose(Matrix(rows));
end intrinsic;

intrinsic HeckeMatrix(Mk::ModFrmHilD, nn::RngOrdIdl) -> Mtrx
  {
    inputs:
      Mk: A space of HMFs
      nn: An integral ideal indexing the Hecke operator
    returns:
      A matrix over corresponding to the action of the Hecke operator on
      this space. 
  }
  return HeckeMatrix(Basis(Mk));
end intrinsic;
