/*
 * Functions for converting between ideal coefficients a_nn and 
 * Fourier coefficients a_nu.
 */

intrinsic IdlCoeffToEltCoeff(a_nn::FldElt, nu::FldElt, k::SeqEnum[RngIntElt], K::Fld) -> FldElt
  {
    inputs:
      a_nn: An element of a number field (usually the splitting field of 
              the base field of the HMF if GaloisDescent has been performed)
              representing the "Frobenius trace" at nn. 
              // TODO abhijitm phrase better, not exactly true
      nu: A totally positive element of a number field (the base field of the HMF)
      k: A weight
      K: The field in which the output should live. Usually this will be
        the coefficient field. 
    returns:
      The Fourier coefficient at nu of the HMF, the coefficient field.

      The coefficients of an HMF are naturally indexed by totally positive elements
      nu. However, after ExtendsMultiplicatively and GaloisDescent, we have coefficients
      indexed by ideals nn. Fix a set of narrow class representatives. Based on the 
      narrow class of nn, there is a narrow class representative bbp such that 
      nn * bbp is a principal ideal. (In our code we
      call this the ideal dual of a narrow class group representative but this distinction
      isn't important here). 

      However, the choice of generator nu such that bbp * nn = (nu) 
      is not canonical, and by the modular transformation law,
      two candidate generators nu and eps * nu -- for some totally positive unit eps -- 
      should have Fourier coefficients related by 

      a_(nu) = \prod_i eps_i^(k_i) a_(eps*nu),

      where eps_i is the image of eps under the ith real embedding. 
      When the weight is parallel (k_1 = ... = k_n) then we have
      a_nu = a_(eps*nu) but in general this is not the case.

      Shimura (Duke 78 Vol 45 No. 3) then writes

      a_(nu) := a_(nn) * N(bbp)^(k_0/2) * nu^((k-k_0)/2)

      where k_0 is the largest entry of k and nu_i is the image of nu under the ith
      real embedding. This definition is compatible with the earlier transformation law.

      This definition is canonical once we fix the normalization of each
      Hecke operator, since we want the a_nn to be eigenvalues. In our case, the normalization
      comes fixed because it comes from the Hecke code in ModFrmHil.

      To reduce the degree of the number fields we need to work with, we use
      the *technically incorrect* formula

      a_(nu) := a_(nn) * nu^((k-k_0)/2)

      Thus, each component will be off by a factor of N(bbp)^(k_0/2). 
      // TODO abhijitm I think this is actually broken... but I also
      // think the existing code should be broken and it doesn't seem
      // to be so idk. 
    }

  if nu eq 0 then
    return StrongCoerce(K, a_nn);
  end if;

  // TODO abhijitm there's some chance that this is wrong
  // the narrow class number is bigger than 1, but I think
  // it's alright... although it might cause problems in 
  // the nonparitious case as written

  return StrongMultiply(K, [* a_nn, EltToShiftedHalfWeight(nu, k)^(-1) *]);
end intrinsic;

intrinsic EltCoeffToIdlCoeff(a_nu::FldElt, nu::FldElt, k::SeqEnum[RngIntElt], K::Fld) -> FldElt
  {
    inputs:
      a_nu: An element of a number field (usually the splitting field 
              of the base field of the HMF if GaloisDescent has been performed)
              representing the Fourier coefficient at nu.
      nu: A totally positive element of a number field (the base field of the HMF)
      k: A weight
      K: The field in which the output should live. Usually this will be
        the coefficient field. 
    returns:
      The "Frobenius trace" at nn of the HMF, the coefficient field.

      Reversing the formula in IdlCoeffToEltCoeff (explanation provided
      in that function), we compute

      a_(nn) := a_(nu) * N(nu)^((k_0-k_i)/2)
  }

  if nu eq 0 then
    return StrongCoerce(K, a_nu);
  end if;

  return StrongMultiply(K, [* a_nu, K!EltToShiftedHalfWeight(nu, k) *]);
end intrinsic;

intrinsic EltCoeffToIdlCoeff(a_nu::FldElt, nu::FldElt, f::ModFrmHilDElt) -> FldElt
  {
    inputs:
      a_nu: An element of a number field (usually the splitting field 
              of the base field of the HMF if GaloisDescent has been performed)
              representing the Fourier coefficient at nu.
      nu: A totally positive element of a number field (the base field of the HMF)
      f: An element of an HMF Space.
    returns:
      The "Frobenius trace" a_nn at the ideal nn corresponding to nu. 
      See the called function for details.
  }
  return EltCoeffToIdlCoeff(a_nu, nu, Weight(Parent(f)), CoefficientRing(f));
end intrinsic;

intrinsic IdlCoeffToEltCoeff(a_nn::FldElt, nu::FldElt, f::ModFrmHilDElt) -> FldElt
  {
    inputs:
      a_nn: An element of a number field (usually the splitting field of 
              the base field of the HMF if GaloisDescent has been performed)
              representing the "Frobenius trace" at nn. 
              // TODO abhijitm phrase better, not exactly true
      nu: A totally positive element of a number field (the base field of the HMF),
        which we expect to be (but do not check) a generator for nn * bbp for some bb.
      f: An element of an HMF Space.
    returns:
      The Fourier coefficient at the totally positive element nu

      See the called function for details.
  }

  return IdlCoeffToEltCoeff(a_nn, nu, Weight(Parent(f)), CoefficientRing(f));
end intrinsic;

