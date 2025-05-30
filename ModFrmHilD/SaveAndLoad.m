///////////////////////////////////////////////////
//                                               //
//    Saving and loading sequences of elements   //
//                                               //
///////////////////////////////////////////////////


function default_dir()
  path_to_this_filename := Split(Split([l : l in Split(Sprint(LoadBasis, "Maximal")) | "Defined" in l][1],":")[2],",")[1];
  package_dir := "/" cat Join(s[2..#s-2], "/") where s := Split(path_to_this_filename, "/");
  return package_dir cat "/Precomputations/";
end function;

intrinsic SaveFilePrefix(Mk::ModFrmHilD) -> MonStgElt
  {
    Builds a prefix encoding the field, level, weight, and character
  }

  // We label number fields by their degree and discriminant
  //
  // TODO abhijitm this is really bad, but it works for me
  // for now.
  F := BaseField(Mk);
  F_label := HackyFieldLabel(F);

  // Use the LMFDB label for N
  N := Level(Mk);
  N_label := LMFDBLabel(N);

  k := Weight(Mk);
  // the weight label for [a, b, c, ...] is a.b.c_...
  k_label := Join([IntegerToString(k_i) : k_i in k], ".");

  chi := Character(Mk);
  chi_label := HeckeCharLabel(chi : full_label:=false);

  return Join([F_label, N_label, k_label, chi_label], "=");
end intrinsic;

intrinsic MkFromSavefile(savefile_path::MonStgElt, saved_prec::RngIntElt) -> ModFrmHilD
  {
    Builds an Mk from a filename beginning with a prefix 
    constructed by SaveFilePrefix.
  }
  split_savefile_path := Split(savefile_path, "/");
  savefile_name := split_savefile_path[#split_savefile_path];
  prefix := Split(savefile_name, "_")[1];

  F_label, N_label, k_label, chi_label := Explode(Split(prefix, "="));

  F := FieldFromHackyLabel(F_label);
  
  N := LMFDBIdeal(F, N_label);
  k := [StringToInteger(x) : x in Split(k_label, ".")];
  chi := ChiLabelToHeckeChar(chi_label, N);

  M := GradedRingOfHMFs(F, saved_prec);

  return HMFSpace(M, N, k, chi);
end intrinsic;

intrinsic SaveBasis(savefile_path::MonStgElt, B::SeqEnum[ModFrmHilDElt])
  {
    input:
      savefile_path: The file to which we will write
      B: A sequence [f_1, ..., f_n] of ModFrmHilDElts
      savedir:

    We store the sequence B into the file at savefile_path

    Writing f_i^1, ..., f_i^(h+) for the components of f_i,
    each f_i^bb is an ModFrmHilDEltComp.

    What we actually store is the
    SeqEnum[SeqEnum[Tup[RngMPolElt, Fld]]]

    [[<f_i^bb`Series, K_i^bb>]_(bb in Cl+)]_(1 <= i <= n),

    where K_i^bb is the coefficient ring of f_i^bb.

    Note that this will OVERWRITE the contents of savedir/savefile_path.
  }
  savefile := Open(savefile_path, "w+");

  if #B eq 0 then
    // some absurdly large value;
    save_prec := 10000;
  else
    save_prec := Min([Precision(f) : f in B]);
    assert &and[save_prec eq Precision(f) : f in B];
  end if;
  WriteObject(savefile, save_prec);

  saveobj := [ElementToCoeffLists(f) : f in B];
  WriteObject(savefile, saveobj);
  // reassigning the variable closes the file
  savefile := 0;
end intrinsic;

intrinsic LoadBasis(savefile_path::MonStgElt : Mk:=false) -> BoolElt, SeqEnum[ModFrmHilDElt]
  {
    We recover a basis from a file written to by SaveBasis.
  }
  savefile := Open(savefile_path, "r");
  saved_prec := ReadObject(savefile);

  if Mk cmpeq false then
    Mk := MkFromSavefile(savefile_path, saved_prec);
    target_prec := saved_prec;
  else
    target_prec := Precision(Parent(Mk));
  end if;

  if saved_prec ge target_prec then
    A := ReadObject(savefile);
    return true, [CoeffListsToElement(Mk, f_coeff_lists) : f_coeff_lists in A];
  else
    return false, _;
  end if;
end intrinsic;

intrinsic ElementToCoeffLists(f::ModFrmHilDElt) -> Tup
  {}
  M := Parent(Parent(f));
  F := BaseField(M);

  coeff_ring_and_prec := <CoefficientRing(f), Precision(f)>;

  // coefficients at the infinity cusps are stored
  // as a list of pairs <bb, coefficient of bb cmp at oo>
  coeffs_at_infty := [];
  for bb in NarrowClassGroupReps(M) do
    // these are always integral ideals I think
    bb_label := LMFDBLabel(bb);
    a_bb_0 := Coefficient(f, bb, F!0);
    Append(~coeffs_at_infty, <bb_label, a_bb_0>);
  end for;

  // then we iterate through nonzero ideals nn of norm up to Precision(f)
  // and store the sequence of <nn, a_nn>
  coeffs_by_idl := [];
  for nn in IdealsUpTo(Precision(f), F) do
    nn_label := LMFDBLabel(nn);
    Append(~coeffs_by_idl, <nn_label, Coefficient(f, nn)>);
  end for;

  return <coeff_ring_and_prec, coeffs_at_infty, coeffs_by_idl>;
end intrinsic;

intrinsic CoeffListsToElement(Mk::ModFrmHilD, coeff_lists::Tup) -> ModFrmHilDElt
  {}
  M := Parent(Mk);
  F := BaseField(M);
  coeff_ring_and_prec, coeffs_at_infty, coeffs_by_idl := Explode(coeff_lists);
  K, prec := Explode(coeff_ring_and_prec);
  require prec ge Precision(M) : "The loaded coeff_lists have insufficient\
      precision for this space of HMFs";

  // create a power series for each component
  coeffs := AssociativeArray();
  for i->bb in NarrowClassGroupReps(M) do
    bb_label, a_bb_0 := Explode(coeffs_at_infty[i]);
    assert LMFDBLabel(bb) eq bb_label;
    a_bb_0 := StrongCoerce(K, a_bb_0);
    coeffs[bb] := AssociativeArray();
    coeffs[bb][F!0] := a_bb_0;
  end for;

  // iterate through ideals and add monomials
  // to the appropriate component
  //
  // we populate a dictionary first because
  // IdealsUpTo seems to be nondeterministic when
  // ordering ideals of the same norm
  coeffs_by_idl_dict := AssociativeArray();
  nonzero_ideals := Exclude(Ideals(M), 0*Integers(F));
  for i in [1 .. #nonzero_ideals] do
    nn_label, a_nn := Explode(coeffs_by_idl[i]);
    coeffs_by_idl_dict[nn_label] := a_nn;
  end for;

  for nn in nonzero_ideals do
    a_nn := coeffs_by_idl_dict[LMFDBLabel(nn)];
    bb := IdealToNarrowClassRep(M, nn);
    a_nn := StrongCoerce(K, a_nn);
    nu := IdealToRep(M, nn);
    a_nu := IdlCoeffToEltCoeff(a_nn, nu, Weight(Mk), K);
    coeffs[bb][nu] := a_nu;
  end for;

  return HMF(Mk, coeffs : prec := Precision(M), coeff_ring := K);
end intrinsic;

intrinsic LoadOrBuildAndSave(
    Mk::ModFrmHilD,
    builder::Intrinsic,
    suffix::MonStgElt :
    save_dir := false,
    prefix := SaveFilePrefix(Mk)
    ) -> SeqEnum[ModFrmHilDElt]
  {
    inputs:
      Mk - space of HMFs
      builder - intrinsic which is used to build
        the basis if it is not saved.
        suffix - string suffix where this basis should
        be saved/loaded from
      save_dir - directory where precomputed results
        are saved
      prefix - prefix string to be used for this load/save
    returns:
  }
  if save_dir cmpeq false then
    save_dir := default_dir();
  end if;
  loadfile_name := save_dir cat prefix cat suffix;
  is_saved, loadfile := OpenTest(loadfile_name, "r");
  loaded := false;
  if is_saved then
    try
      loaded, basis := LoadBasis(loadfile_name : Mk:=Mk);
    catch e
      Write("/dev/stderr", Sprintf("Failed to load %o:\n%o", loadfile_name, e));
      loaded := false;
    end try;
  end if;
  // loaded is false if the file was not saved or if
  // the precision of the stored basis wasn't high enough
  if not loaded then
    if builder eq HeckeStabilityCuspBasis then
      basis := HeckeStabilityCuspBasis(Mk : SaveAndLoad:=true);
    else
      basis := builder(Mk);
    end if;
    SaveBasis(loadfile_name, basis);
  end if;
  return basis;
end intrinsic;


