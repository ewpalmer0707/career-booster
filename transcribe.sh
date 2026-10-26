#!/bin/zsh
# Handwriting → essay draft. Run by launchd (com.elijah.learning-transcribe) whenever a file lands in the
# iCloud inbox, or manually:  ~/Developer/personal/learning-pipeline/transcribe.sh
#
#   iPad Apple Notes ──Send a Copy → Save to Files──▶ iCloud Drive/Learning/inbox/*.pdf|png|jpg|heic
#   launchd WatchPaths ──▶ this script ──▶ headless `claude -p` reads the scan, writes
#   ewpalmer0707.github.io/src/content/essays/YYYY-MM-DD-<slug>.md (status: draft) ──▶ scan moved to processed/
#
# Same pattern as lecture-capture/scripts/make_notes.sh and BYU/tools/mail_check.sh: tight tool allowlist,
# no git push (publishing is a deliberate step: edit in Obsidian, flip status to published, push).
setopt null_glob
export PATH="/Users/elijah/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
ICLOUD="/Users/elijah/Library/Mobile Documents/com~apple~CloudDocs/Learning"
INBOX="$ICLOUD/inbox"; DONE="$ICLOUD/processed"
SITE=/Users/elijah/Developer/personal/ewpalmer0707.github.io
ESSAYS=$SITE/src/content/essays
HERE=/Users/elijah/Developer/personal/learning-pipeline
LOG=$HERE/logs; WORK=$HERE/work; mkdir -p "$LOG" "$WORK" "$DONE" "$ESSAYS"
STAMP=$(date "+%Y-%m-%d %H:%M"); TODAY=$(date +%Y-%m-%d)
LOCK=$HERE/.lock
if ! mkdir "$LOCK" 2>/dev/null; then echo "$STAMP  already running" >> "$LOG/transcribe.log"; exit 0; fi
trap 'rmdir "$LOCK"' EXIT
sleep 20   # let iCloud finish downloading the file before we touch it

notify() { osascript -e "display notification \"$1\" with title \"Learning\" subtitle \"$2\" sound name \"Glass\"" 2>>"$LOG/transcribe.err"; }

for f in "$INBOX"/*.(pdf|PDF|png|PNG|jpg|JPG|jpeg|JPEG|heic|HEIC); do
  name=$(basename "$f"); stem=${name%.*}; ext=${name##*.}; ext=${ext:l}
  # skip files iCloud hasn't fully downloaded yet (placeholder .icloud files are hidden; size 0 = in flight)
  [[ ! -s "$f" ]] && continue
  src="$f"
  if [[ "$ext" == "heic" ]]; then   # Claude can't read HEIC; convert
    src="$WORK/$stem.png"; sips -s format png "$f" --out "$src" >/dev/null 2>>"$LOG/transcribe.err" || { echo "$STAMP  heic convert failed: $name" >> "$LOG/transcribe.log"; continue; }
  fi
  rel="src/content/essays"
  read -r -d '' PROMPT <<P
You are Elijah's handwriting transcriber (unattended, no user present). Read the handwritten scan at "$src" (every page) and turn it into a markdown essay draft.

Rules:
- Transcribe faithfully. Fix obvious spelling, but keep Elijah's sentences, voice, and order. Never add ideas, examples, or facts that are not on the page.
- If a word is unreadable, write it as [?] so he can fix it. If the handwriting cuts off, end with "> [scan ends here]".
- Turn visual structure into markdown: headings he wrote become ##, lists become lists, boxed/starred items become **bold**.
- Pick a short title (his heading if he wrote one) and a slug (lowercase, hyphens, max 6 words).

Write ONE file at $SITE/$rel/$TODAY-<slug>.md with exactly this frontmatter, then the essay body:
---
title: "<title>"
date: $TODAY
status: draft
topic: "<2-4 word topic, e.g. Apex Triggers, Database Normalization>"
summary: "<one sentence, in Elijah's voice, what the essay argues>"
project:
source: "$name"
---

Do not create or edit any other file. Your FINAL message must be exactly one line: DONE: <path you wrote> | <title>
P
  OUT=$(printf '%s\n' "$PROMPT" | claude -p --model sonnet --max-turns 12 --permission-mode acceptEdits \
        --allowedTools "Read" "Write" "Glob" --output-format text 2>>"$LOG/transcribe.err")
  { echo "===== $STAMP  $name"; echo "$OUT"; echo; } >> "$LOG/transcribe.log"
  FIRST=$(printf '%s' "$OUT" | grep -m1 -E '^DONE:')
  if [[ -n "$FIRST" ]]; then
    mv "$f" "$DONE/$name"; [[ "$src" != "$f" ]] && rm -f "$src"
    TITLE=${FIRST##*| }
    notify "$TITLE" "Draft written to src/content/essays — open Obsidian to review"
  else
    notify "Transcription failed for $name" "See learning-pipeline/logs/transcribe.err"
  fi
done
exit 0
