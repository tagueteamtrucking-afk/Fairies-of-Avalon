# Crown of Clarity

The **Crown of Clarity** is a small Python tool for generating two JSON
files that power the Fairies‑of‑Avalon project:

* `memory/file-index.json` – an index of every file in your project so
  that interactive tools (like ChatGPT) can quickly browse the
  repository tree and reason about its structure.
* `memory/site-map.json` – a light‑weight site map describing which
  pages exist, which ones serve as entry points, and what other
  resources are available.  This file allows the dashboard apps in the
  Fairies project to discover new content without having to hard‑code
  every path.

The original Crown was implemented as a web crawler and attempted to
iterate over dynamic routes served by a dev server.  It ended up
hammering your CPU and produced empty JSON because it couldn’t reach
files that weren’t served over HTTP.  This version takes a simpler
approach: it reads your project directly from disk.  It’s fast,
deterministic and idempotent.

## Installation

1. Extract the `crown_of_clarity.zip` archive somewhere on your
   machine (e.g. inside your project root).
2. Ensure you have Python 3.8 or later installed (`python3 --version`).
3. (Optional) Create a virtual environment and activate it.

## Usage

Run the following command from the root of your project:

```sh
python3 crown_of_clarity.py --root .
```

This will scan the directory tree rooted at `.` (the current
directory), skip common ignored folders (such as `node_modules`,
`.git`, `.venv`, `dist` and `memory`), and then generate or update
`memory/file-index.json` and `memory/site-map.json`.  If the `memory`
directory does not exist, it will be created automatically.

For a dry run that only prints what would be written, use:

```sh
python3 crown_of_clarity.py --root . --dry-run
```

You can also specify a different root directory:

```sh
python3 crown_of_clarity.py --root path/to/project
```

## What gets indexed?

The script walks your project tree and records every file except
those residing inside ignored directories.  Binary files (images,
archives, etc.) are treated as assets and included only in
`site-map.json`.  HTML files are listed in both `file-index.json` and
`site-map.json`; the latter will attempt to extract the `<title>` text
to serve as a human‑readable name.

The resulting JSON has the following structure:

```json
{
  "generated": "2025-11-02T06:00:00Z",
  "files": [
    "README.md",
    "pages/index.html",
    "pages/apps/nina/overview.html"
  ]
}
```

```json
{
  "generated": "2025-11-02T06:00:00Z",
  "entrypoints": ["/index.html"],
  "pages": [
    {"path": "/pages/index.html", "title": "Fairies of Avalon"},
    {"path": "/pages/apps/nina/overview.html", "title": "Project Overview (Nina)"}
  ],
  "assets": ["/static/css/main.css", "/images/logo.png"],
  "importmap": null
}
```

These files can be read at runtime by your web components to show a
dynamic menu or a list of all available scenes.

## Troubleshooting

* **Empty JSON** – If the JSON files end up empty, ensure that the
  script is pointed at the correct project root and that there are
  actually files present.  The default ignore list may be too
  aggressive; you can adjust it by editing the `IGNORED_DIRS` list at
  the top of `crown_of_clarity.py`.
* **Performance** – Scanning very large repositories can take a
  noticeable amount of time.  This script processes files
  synchronously but only once per run.  If you want to integrate it
  into a CI pipeline, consider running it only when files change.

For further enhancements or bug fixes, feel free to edit the script.