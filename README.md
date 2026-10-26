# learning-pipeline

Handwritten essay on an iPad → markdown draft on my website, automatically.

```
 iPad · Apple Notes          iCloud Drive                 Mac · launchd + claude -p             ewpalmer0707.github.io
┌──────────────────┐       ┌───────────────────┐       ┌─────────────────────────────┐       ┌────────────────────────┐
│ write by hand    │ Send  │ Learning/inbox/    │ Watch │ transcribe.sh               │ Write │ src/content/essays/    │
│ ⋯ → Send a Copy  ├──────▶│   essay.pdf        ├──────▶│  Claude reads the scan,      ├──────▶│   2026-10-26-slug.md   │
│   → Save to Files│       │ Learning/processed/│ Paths │  writes frontmatter + body   │       │   status: draft        │
└──────────────────┘       └───────────────────┘       └─────────────────────────────┘       └────────────────────────┘
                                                                                                       │ edit in Obsidian,
                                                                                                       │ status: published,
                                                                                                       ▼ git push → live
```

## Why

Explaining something in my own words, by hand, is how I find out whether I understand it. Typing invites copy-paste; a pen doesn't. But handwriting is a dead end unless it becomes text I can edit, publish, and point an employer at. This closes that gap with the same pattern as my other jobs (`lecture-capture`, BYU mail triage): a watched folder, a launchd job, and a headless Claude Code run with a tight tool allowlist.

## The loop

1. **Write** in Apple Notes on the iPad with the Pencil. One note per essay. Put a title on the first line.
2. **Export.** In the note: `⋯` → **Send a Copy** → **Save to Files** → iCloud Drive → `Learning/inbox`. (If the note is long and the PDF comes out truncated, use `⋯` → Send a Copy → **Print**, pinch the preview open, then share → Save to Files. Screenshots work too: the job accepts pdf, png, jpg, heic.)
3. **Transcribe.** launchd sees the new file and runs `transcribe.sh`. Claude reads every page, transcribes faithfully (spelling fixed, nothing added, unreadable words marked `[?]`), and writes `src/content/essays/YYYY-MM-DD-<slug>.md` with `status: draft`. The scan moves to `Learning/processed/`. A macOS notification tells me it's ready.
4. **Edit** in Obsidian (vault = the site's `src/content/` folder). Fix `[?]`s, tighten, set `project:` to the slug of the project it should pair with, flip `status: published`.
5. **Publish.** `git push` in the site repo. GitHub Actions builds and deploys.
6. **Prove it.** Build the project under `~/Developer/personal/projects/<slug>/`, write `src/content/projects/<slug>.md` with `essay: <essay-slug>`, and the two pages link each other.

## Install / operate

```bash
# install (once) or reload after editing the plist
cp com.elijah.learning-transcribe.plist ~/Library/LaunchAgents/ && launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.elijah.learning-transcribe.plist
# run now (also runs on every file change in inbox, and every 30 min as a fallback)
launchctl kickstart gui/$(id -u)/com.elijah.learning-transcribe
# stop
launchctl bootout gui/$(id -u)/com.elijah.learning-transcribe
# manual run
./transcribe.sh
```

Logs: `logs/transcribe.log` (Claude's output per file), `logs/transcribe.err`, `logs/launchd.*`.
**Requires Full Disk Access for `/bin/zsh`.** Without it the launchd-spawned shell gets `Operation not permitted` on iCloud Drive and silently processes nothing (the `scan:` line in `logs/transcribe.log` shows 0 files and `transcribe.err` has the error). Grant it in System Settings → Privacy & Security → Full Disk Access (open `/bin` in Finder and drag `zsh` onto the list), then **bootout + bootstrap the job** — the grant did not apply to the already-loaded agent (verified 2026-10-26).

## Files

- `transcribe.sh` — the job. Edit the prompt here to change what a draft looks like.
- `com.elijah.learning-transcribe.plist` — launchd definition (WatchPaths on the inbox + 30-min StartInterval + RunAtLoad).
