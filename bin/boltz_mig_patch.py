#!/usr/bin/env python3

# Written by Jose Espinosa-Carrasco, released under the MIT license
# See https://opensource.org/license/mit for details

# Created on January 29th 2026 see #  See https://github.com/nf-core/proteinfold/issues/417 for context
# Script to get the number of CUDA cores in a GPU instance profile, as pynvml.nvmlDeviceGetNumGpuCores fails in MIG mode
# Inspired by https://github.com/Australian-Protein-Design-Initiative/nf-binder-design/blob/9e7fb3001722899715aa01ab130d0572edbd0915/modules/boltzgen/boltzgen_design.nf#L54

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

# Function to get the number of CUDA cores in a GPU instance profile
def get_cuda_cores(handle, profile_id):
    profile_info = pynvml.nvmlDeviceGetGpuInstanceProfileInfo(handle, profile_id)
    sm_count = profile_info.multiprocessorCount
    name = pynvml.nvmlDeviceGetName(handle)

    # Simple architecture inference from name
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

def main() -> None:

    pynvml.nvmlInit()
    h=pynvml.nvmlDeviceGetHandleByIndex(0)
    profile_id = pynvml.NVML_GPU_INSTANCE_PROFILE_1_SLICE
    n_cores = get_cuda_cores(h, profile_id)

    pynvml.nvmlDeviceGetNumGpuCores = lambda handle: n_cores

    try:
        pynvml.nvmlDeviceGetNumGpuCores = lambda handle: n_cores
        print(">>> MIG PATCH: Successfully mocked nvmlDeviceGetNumGpuCores", file=sys.stderr)
    except Exception as e:
        print(f">>> MIG PATCH: Failed to mock pynvml: {e}", file=sys.stderr)

if __name__ == "__main__":
    main()