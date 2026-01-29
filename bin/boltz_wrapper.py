#!/usr/bin/env python3

# Written by Jose Espinosa-Carrasco, released under the MIT license
# See https://opensource.org/license/mit for details

# Created on January 29th 2026
# Script to wrap boltz CLI after applying the MIG patch to pynvml
# Created on January 29th 2026 
# See https://github.com/nf-core/proteinfold/issues/417 for context

import sys
import boltz_mig_patch
boltz_mig_patch.main()

from boltz.main import cli 
sys.argv[0] = 'boltz'
sys.exit(cli())
