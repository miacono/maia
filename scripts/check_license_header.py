#!/usr/bin/env python3
"""Pre-commit hook: ensure every Python source file carries the AGPL-3 license header.

Adds the header automatically when missing; exits with code 1 so the commit is
blocked and the user can re-stage the modified files.
"""
import sys
from pathlib import Path

HEADER = """\
# MAIA - Mission Aware Incident Authority
# Copyright (C) 2025  MAIA Contributors
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.
"""

_MARKER = "# MAIA - Mission Aware Incident Authority"


def _insert_header(path: Path) -> bool:
    """Return True if the header was added, False if it was already present."""
    text = path.read_text(encoding="utf-8")
    if _MARKER in text[:512]:
        return False
    # Preserve a shebang line at the top
    if text.startswith("#!"):
        shebang, rest = text.split("\n", 1)
        text = shebang + "\n" + HEADER + rest
    else:
        text = HEADER + text
    path.write_text(text, encoding="utf-8")
    print(f"[license-header] Added header to {path}")
    return True


def main() -> int:
    modified = [f for f in sys.argv[1:] if _insert_header(Path(f))]
    if modified:
        print(
            "\n[license-header] License header was missing in the files listed above.\n"
            "The header has been added — please re-stage those files and commit again."
        )
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
