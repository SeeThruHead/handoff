# Handoff

Menu bar app for the files your agents produce. Reports, rendered HTML, markdown, CSV dumps, screenshots: they show up in a panel with a preview, and one click opens them, one drag puts them in Slack or a prompt, one button copies them. You never open Finder for them.

## Install

```bash
brew install seethruhead/tap/handoff
open /Applications/Handoff.app
```

Then in the panel's settings (gear icon): **Install CLI**, **Install skill**, **Open at login**. The app bootstraps its own integration; nothing else to install.

## How agents use it

```bash
handoff <file> [--title "Short human title"]
```

One call, three effects:

- The file is registered in the panel (newest first, grouped by day, thumbnail for images, HTML and rendered markdown).
- It is copied to the clipboard as a single item with several representations: paste into Slack or Finder and you get the file; paste into a terminal or Claude and you get the path (or the image, for images).
- It is opened: markdown is rendered with [grip](https://github.com/joeyespo/grip) and the HTML opened in the browser; HTML opens in the browser; anything else opens in its default app.

`handoff put <file>` registers and copies without opening. `handoff open <file>` registers and opens without touching the clipboard. `handoff list` prints the index.

The bundled skill (`~/.agents/skills/handoff/SKILL.md`) tells Claude Code, Pi, Codex and OpenCode to call `handoff` instead of printing a path.

## The panel

- Click a row to open it. Drag a row out to Slack, a prompt, or anywhere that takes files.
- **Copy** puts the file on the clipboard (all representations). **Path** copies just the path.
- `⋯` has Open, Reveal in Finder, Remove from list.
- Entries drop off after 30 days. The app never deletes files; the index lives in `~/Library/Application Support/Handoff/index.json`.

## Build from source

```bash
./build.sh            # build/Handoff.app with the CLI at Contents/Helpers/handoff
open build/Handoff.app
```

Requires Xcode command line tools. `grip` (`brew install grip`) is needed for markdown rendering.

## Debugging

`HANDOFF_SHOW_ON_LAUNCH=1` opens the panel on launch. `HANDOFF_SNAPSHOT=/path/out.png` also writes renderings of the panel and its settings view to that path and `…-settings.png`.
