#!/usr/bin/env bash
# Full content pipeline. Each step is cached/resumable, so re-running only does new work.
#   1. find_clips.py  — AI watches each picked YouTube video, returns clip windows + lines
#   2. build.ts       — tokenise, dictionary, write shared data for both clients
#   3. proof.py       — AI proofreads transcripts (orthography only)
#   4. build.ts       — apply corrections
#   5. explain.py     — AI word-in-context notes
#   6. build.ts       — copy notes into both clients
set -euo pipefail
cd "$(dirname "$0")/../.."
bash scripts/content/fetch_dict.sh >/dev/null
python3 scripts/content/find_clips.py --workers 10
bun scripts/content/build.ts
python3 scripts/content/proof.py --workers 8
bun scripts/content/build.ts
python3 scripts/content/explain.py --workers 8
bun scripts/content/build.ts
echo PIPELINE_DONE
