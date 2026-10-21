#!/usr/bin/env bash
# Downloads the open dictionary data build.ts needs into scripts/content/.dict/ (git-ignored):
#   - JMdict (English, with Tatoeba examples) from scriptin/jmdict-simplified, pinned release
#   - JLPT vocabulary lists n1..n5.csv (jmdict_seq first column) from stephenmk/yomitan-jlpt-vocab
# Re-running is a no-op when the files are already there.
set -euo pipefail
cd "$(dirname "$0")"
DIR=.dict
TAG="3.6.2+20261019180022"
mkdir -p "$DIR"
if [ ! -f "$DIR/jmdict-examples-eng-3.6.2.json" ]; then
  url="https://github.com/scriptin/jmdict-simplified/releases/download/${TAG//+/%2B}/jmdict-examples-eng-${TAG//+/%2B}.json.zip"
  curl -sSL -o "$DIR/jmdict.zip" "$url"
  python3 - "$DIR" <<'PY'
import sys, zipfile, os
d = sys.argv[1]
with zipfile.ZipFile(os.path.join(d, "jmdict.zip")) as z:
    name = [n for n in z.namelist() if n.endswith(".json")][0]
    with z.open(name) as src, open(os.path.join(d, "jmdict-examples-eng-3.6.2.json"), "wb") as out:
        out.write(src.read())
os.remove(os.path.join(d, "jmdict.zip"))
PY
fi
for n in 1 2 3 4 5; do
  [ -f "$DIR/n$n.csv" ] || curl -sSL -o "$DIR/n$n.csv" "https://raw.githubusercontent.com/stephenmk/yomitan-jlpt-vocab/main/original_data/n$n.csv"
done
ls -la "$DIR"
