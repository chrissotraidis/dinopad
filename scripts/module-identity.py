#!/usr/bin/env python3
"""Print the shared empty-app/private-module source contract."""
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from module_build import identity

if __name__ == '__main__':
    print(identity())
