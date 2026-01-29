#!/usr/bin/env python3

import sys
import boltz_mig_patch
boltz_mig_patch.main()

from boltz.main import cli 
sys.argv[0] = 'boltz'
sys.exit(cli())
