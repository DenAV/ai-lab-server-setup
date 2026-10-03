#!/usr/bin/env python3
"""Validate relative links in repository Markdown files."""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import unquote


ROOT = Path(__file__).resolve().parents[1]
LINK = re.compile(r"\[[^]]*\]\(([^)]+)\)")


def tracked_markdown() -> list[Path]:
    result = subprocess.run(
        ["git", "ls-files", "*.md"],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    paths = {ROOT / line for line in result.stdout.splitlines() if line}
    paths.update(ROOT.glob("docs/**/*.md"))
    return sorted(path for path in paths if path.is_file())


def main() -> int:
    errors: list[str] = []
    files = tracked_markdown()
    checked = 0
    for document in files:
        text = document.read_text(encoding="utf-8")
        for match in LINK.finditer(text):
            target = match.group(1).split()[0].strip("<>")
            if target.startswith(("#", "http://", "https://", "mailto:")):
                continue
            path_text = unquote(target.split("#", 1)[0])
            if not path_text:
                continue
            checked += 1
            resolved = (document.parent / path_text).resolve()
            if not resolved.exists():
                relative_document = document.relative_to(ROOT)
                errors.append(f"{relative_document}: missing link target {target}")

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print(f"Documentation links valid: {len(files)} files, {checked} relative links")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
