process VALIDATE_INPUTS {
    input:
    path model
    path reference

    script:
    """
    python3 - <<EOF
    from Bio.PDB import PDBParser
    import sys

    parser = PDBParser(QUIET=True)

    model_struct  = parser.get_structure("model",  "${model}")
    reference_struct = parser.get_structure("reference", "${reference}")

    model_chains  = [c.id for c in model_struct.get_chains()]
    reference_chains = [c.id for c in reference_struct.get_chains()]

    if sorted(model_chains) != sorted(reference_chains):
        print("Validation Failed!")
        print(f"   Model chains:  {model_chains}")
        print(f"   reference chains: {reference_chains}")
        print( "   Error: Proteins are incompatible - chains do not match.")
        print( "   Please provide a model and reference structure of the SAME protein.")
        print( "   Exiting pipeline early.")
        sys.exit(1)
        
    EOF
    """
}