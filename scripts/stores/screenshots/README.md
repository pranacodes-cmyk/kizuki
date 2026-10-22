# Store screenshots

Re-render after a UI change (dev server on :8080):

1. `python3 seed.py` — writes a realistic sample learner to /tmp/browser/shots/seed.json
2. `python3 raw_shots.py && python3 raw_more.py` — captures app screens at 430×932 @3x into /tmp/browser/shots/raw
3. `python3 compose.py` — adds captions + device frame → `store/screenshots/{ios,play}/NN.png` and `store/play/feature-graphic.png`
4. `python3 ../push_listing.py` — uploads text + images to App Store Connect and Google Play
