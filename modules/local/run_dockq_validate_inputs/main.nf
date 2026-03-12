process VALIDATE_INPUTS {
    input:
    path model
    path native

    script:
    """
    python3 - <<EOF
    from Bio.PDB import PDBParser
    import sys

    parser = PDBParser(QUIET=True)

    model_struct  = parser.get_structure("model",  "${model}")
    native_struct = parser.get_structure("native", "${native}")

    model_chains  = [c.id for c in model_struct.get_chains()]
    native_chains = [c.id for c in native_struct.get_chains()]

    if sorted(model_chains) != sorted(native_chains):
        print("Validation Failed!")
        print(f"   Model chains:  {model_chains}")
        print(f"   Native chains: {native_chains}")
        print( "   Error: Proteins are incompatible - chains do not match.")
        print( "   Please provide a model and native structure of the SAME protein.")
        print( "   Exiting pipeline early.")
        sys.exit(1)
        
    EOF
    """
}