#!/usr/bin/env python3

# Written by Jose Espinosa-Carrasco, released under the MIT license
# See https://opensource.org/license/mit for details
# Created on January 29th 2026
# See https://github.com/nf-core/proteinfold/issues/417 for context
# Wrapper script to run Boltz with MIG patch for pynvml.nvmlDeviceGetNumGpuCores

import sys
import pynvml

# Cores per SM by architecture
CORES_PER_SM = {
    "Fermi": 32,
    "Kepler": 192,
    "Maxwell": 128,
    "Pascal": 64,
    "Volta": 64,
    "Ampere": 64,
    "Hopper": 128,
}


def get_cuda_cores(handle, profile_id):
    """Get CUDA cores for a MIG GPU instance profile."""
    profile_info = pynvml.nvmlDeviceGetGpuInstanceProfileInfo(handle, profile_id)
    sm_count = profile_info.multiprocessorCount
    name = pynvml.nvmlDeviceGetName(handle)

    if "H100" in name:
        arch = "Hopper"
    elif "A100" in name or "A30" in name or "A40" in name:
        arch = "Ampere"
    elif "V100" in name:
        arch = "Volta"
    elif "P100" in name:
        arch = "Pascal"
    else:
        raise RuntimeError(f"Unknown GPU architecture for device: {name}")

    return sm_count * CORES_PER_SM[arch]


def apply_mig_patch():
    """Monkey-patch pynvml.nvmlDeviceGetNumGpuCores for MIG mode."""
    pynvml.nvmlInit()
    handle = pynvml.nvmlDeviceGetHandleByIndex(0)
    profile_id = pynvml.NVML_GPU_INSTANCE_PROFILE_1_SLICE
    n_cores = get_cuda_cores(handle, profile_id)
    pynvml.nvmlDeviceGetNumGpuCores = lambda h: n_cores
    print(">>> MIG PATCH: Successfully mocked nvmlDeviceGetNumGpuCores", file=sys.stderr)


if __name__ == "__main__":
    apply_mig_patch()

    from boltz.main import cli
    sys.argv[0] = 'boltz'
    sys.exit(cli())
