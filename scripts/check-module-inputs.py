#!/usr/bin/env python3
"""Verify the private output ledger before compiling a game module."""
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from module_build import check_generated

if __name__ == '__main__':
    try:
        check_generated(Path(sys.argv[1]))
    except (OSError, ValueError, IndexError) as error:
        sys.exit(str(error))
