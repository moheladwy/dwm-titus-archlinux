#!/usr/bin/python3
"""Run the real regional CLI with Arch identity confined to this test child."""

import runpy
import sys

provider = runpy.run_path(sys.argv[1], run_name="regional_cli_child_fixture")
provider["main"].__globals__["read_arch_identity"] = lambda: {"ID": "arch", "NAME": "Arch Linux"}
raise SystemExit(provider["main"](sys.argv[2:]))
