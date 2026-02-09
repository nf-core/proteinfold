#!/usr/bin/env python3

# Written by Jose Espinosa-Carrasco, released under the MIT license
# See https://opensource.org/license/mit for details
# Created on January 29th 2026
# See https://github.com/nf-core/proteinfold/issues/417 for context
# Wrapper script to run Boltz with MIG patch for pynvml.nvmlDeviceGetNumGpuCores

import sys
import pynvml
import os

# Cores per SM by architecture
CORES_PER_SM = {
    "Fermi": 32,
    "Kepler": 192,
    "Maxwell": 128,
    "Pascal": 64,
    "Volta": 64,
    "Ampere": 64,
    "Hopper": 128,
    "Blackwell": 128,
}

# Get number of CUDA cores for a MIG GPU instance
def get_cuda_cores(sm_count):
    """Get CUDA cores for a MIG GPU instance profile."""

    pynvml.nvmlInit()
    handle = pynvml.nvmlDeviceGetHandleByIndex(0)
    name = pynvml.nvmlDeviceGetName(handle)

    if "B100" in name or "B200" in name:
        arch = "Blackwell"
    elif "H100" in name or "H200" in name:
        arch = "Hopper"
    elif "A100" in name or "A30" in name or "A40" in name:
        arch = "Ampere"
    elif "V100" in name:
        arch = "Volta"
    elif "P100" in name:
        arch = "Pascal"
    else:
        raise RuntimeError(f"Unknown GPU architecture for device: {name}")

    n_cores = sm_count * CORES_PER_SM[arch]
    print(f">>> Detected GPU: {name}, Architecture: {arch}, SM Count: {sm_count},  Total CUDA Cores: {n_cores}")

    return sm_count * CORES_PER_SM[arch]

# Apply the monkey patch to "nvmlDeviceGetNumGpuCores" pynvml function
def apply_mig_patch():
    """Monkey-patch pynvml.nvmlDeviceGetNumGpuCores for MIG mode."""
    sm_count = int(os.environ["SM_COUNT"])
    n_cores = get_cuda_cores(sm_count)
    pynvml.nvmlDeviceGetNumGpuCores = lambda h: n_cores
    print(">>> MIG PATCH: Successfully mocked nvmlDeviceGetNumGpuCores", file=sys.stderr)

# Main execution
if __name__ == "__main__":
    apply_mig_patch()

    from boltz.main import cli
    sys.argv[0] = 'boltz'
    sys.exit(cli())
