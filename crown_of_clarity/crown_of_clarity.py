#!/usr/bin/env python3
"""
Generate index and site-map files for the Fairies‑of‑Avalon project.

This script scans a project directory tree, collects a list of files
relative to that root, and writes two JSON files into a `memory`
directory:

* `file-index.json` contains a flat list of all files for quick lookup.
* `site-map.json` contains structured metadata for pages and assets.

The original Crown of Clarity tool attempted to crawl the running
website, which was brittle and resource hungry.  By operating on the
filesystem instead, we avoid network errors and infinite loops.

Example usage:

    python3 crown_of_clarity.py --root .

This will create or update `memory/file-index.json` and
`memory/site-map.json` in the current directory.

You can run in dry‑run mode to see what would be written without
changing any files:

    python3 crown_of_clarity.py --root . --dry-run

The script uses UTF‑8 throughout and will normalise path separators to
forward slashes for portability.
"""

from __future__ import annotations

import argparse
import datetime as _dt
import html.parser
import json
import os
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple

IGNORED_DIRS = {".git", "node_modules", "dist", "build", "memory", ".venv", ".vscode"}
ASSET_EXTENSIONS = {".png", ".jpg", ".jpeg", ".gif", ".svg", ".webp", ".css", ".js", ".json", ".wasm", ".mp3", ".mp4", ".woff", ".woff2"}
HTML_EXTENSIONS = {".html", ".htm"}


class TitleExtractor(html.parser.HTMLParser):
    """Extract the first <title> tag from an HTML document."""

    def __init__(self) -> None:
        super().__init__()
        self.in_title = False
        self.title: Optional[str] = None

    def handle_starttag(self, tag: str, attrs: List[Tuple[str, Optional[str]]]) -> None:
        if tag.lower() == "title":
            self.in_title = True

    def handle_endtag(self, tag: str) -> None:
        if tag.lower() == "title":
            self.in_title = False

    def handle_data(self, data: str) -> None:
        if self.in_title and self.title is None:
            # Strip whitespace but leave any inner text as is.
            self.title = data.strip()


def scan_project(root: Path) -> Tuple[List[str], List[Dict[str, str]], List[str]]:
    """
    Walk `root` and return a tuple of (files, pages, assets).

    *files*: a list of relative paths (posix style) for all files.
    *pages*: a list of dicts with keys 'path' and 'title' for each HTML page.
    *assets*: a list of relative paths for non‑HTML, non‑ignored assets.

    Directories listed in `IGNORED_DIRS` are skipped entirely.
    """
    files: List[str] = []
    pages: List[Dict[str, str]] = []
    assets: List[str] = []

    for dirpath, dirnames, filenames in os.walk(root):
        # Modify dirnames in place to skip ignored directories.
        dirnames[:] = [d for d in dirnames if d not in IGNORED_DIRS and not d.startswith('.')]
        rel_dir = Path(dirpath).relative_to(root)
        for fname in filenames:
            # Skip hidden files
            if fname.startswith('.'):
                continue
            path = rel_dir / fname if rel_dir != Path('.') else Path(fname)
            # Normalise to posix style
            posix_path = str(path.as_posix())
            files.append(posix_path)

            ext = path.suffix.lower()
            if ext in HTML_EXTENSIONS:
                # Extract title from HTML file
                full_path = root / path
                try:
                    with open(full_path, 'r', encoding='utf-8', errors='ignore') as f:
                        contents = f.read(65536)  # read up to 64KiB
                except Exception:
                    contents = ''
                extractor = TitleExtractor()
                try:
                    extractor.feed(contents)
                except Exception:
                    pass
                title = extractor.title if extractor.title else path.stem
                pages.append({"path": f"/{posix_path}", "title": title})
            elif ext in ASSET_EXTENSIONS:
                assets.append(f"/{posix_path}")

    return files, pages, assets


def write_json(target: Path, data: Dict, dry_run: bool) -> None:
    """Write `data` as JSON to `target`, creating parent directories as needed."""
    if dry_run:
        print(f"[dry‑run] Would write {target} with data:\n{json.dumps(data, indent=2)}\n")
        return
    target.parent.mkdir(parents=True, exist_ok=True)
    with open(target, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2)
        f.write('\n')  # ensure newline at end


def generate_index_and_sitemap(root: Path, dry_run: bool = False) -> None:
    files, pages, assets = scan_project(root)
    timestamp = _dt.datetime.utcnow().replace(microsecond=0).isoformat() + 'Z'

    file_index = {
        "generated": timestamp,
        "files": files,
    }
    site_map = {
        "generated": timestamp,
        "entrypoints": ["/index.html"] if any(p["path"] == "/index.html" for p in pages) else [],
        "pages": pages,
        "assets": assets,
        "importmap": None,
    }

    memory_dir = root / "memory"
    write_json(memory_dir / "file-index.json", file_index, dry_run)
    write_json(memory_dir / "site-map.json", site_map, dry_run)


def parse_args(argv: Optional[List[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate file index and site map for Fairies‑of‑Avalon.")
    parser.add_argument("--root", type=str, default=".", help="Project root to scan (default: current directory)")
    parser.add_argument("--dry-run", action="store_true", help="Print output instead of writing files")
    return parser.parse_args(argv)


def main(argv: Optional[List[str]] = None) -> None:
    args = parse_args(argv)
    root = Path(args.root).resolve()
    if not root.exists() or not root.is_dir():
        print(f"Error: root directory {root} does not exist", file=sys.stderr)
        sys.exit(1)
    generate_index_and_sitemap(root, dry_run=args.dry_run)


if __name__ == '__main__':
    main()