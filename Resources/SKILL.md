---
name: handoff
description: Deliver generated files (reports, HTML pages, markdown, CSV/JSON dumps, images) to the user through the Handoff tray app instead of printing a path. Use whenever you create a file the user is meant to read, paste, or share.
---

# Handoff

The user does not type paths and does not open Finder. When you produce a file for them, run:

```
handoff <file> [--title "Short human title"]
```

What it does, in one step:

- Registers the file in the Handoff menu bar panel, where the user can click to open it, drag it into Slack or a prompt, copy it, or copy its path.
- Copies it to the clipboard as one item with several representations: pasting into Slack or Finder gives the file, pasting into a terminal or Claude gives the path (or the image, for images).
- Opens it: markdown is rendered with grip and the HTML opened in the browser; HTML opens in the browser; other files open in their default app.

Variants:

- `handoff put <file>`: register and copy, do not open (for files the user will paste rather than read now).
- `handoff open <file>`: register and open, leave the clipboard alone.
- `handoff list`: print the index.

Rules:

- Call it once per finished artifact, when the file is complete. Do not call it for intermediate scratch files.
- Always pass `--title` with a short description (what it is, for what), not the filename.
- Do not also print the path or run `open` yourself; `handoff` replaces both.
- If `handoff` is not on PATH, tell the user to click "Install CLI" in Handoff's settings, then fall back to opening the file.
