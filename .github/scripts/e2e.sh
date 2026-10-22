#!/usr/bin/env bash
# Emulator end-to-end check for the Kizuki Android app. Runs inside
# reactivecircus/android-emulator-runner with mobile/ as the working directory.
#
#  1. Release smoke test: installs the exact release APK the build job produced, cold
#     starts it and captures the screen over the first 25 seconds (catches blank screens
#     and start-up crashes in the shipped build).
#  2. Flow test: runs integration_test/app_flow_test.dart in profile mode (AOT, like
#     release). Every `E2E_SHOT <name>` line the test logs makes this script capture the
#     real device screen, including the YouTube player.
#
# Output (screenshots, logcat, drive log) goes to $OUT and is uploaded as an artifact.
set -uo pipefail

PKG="com.kizukijapan.app"
APK="${APK:?path to the release APK}"
OUT="${OUT:-$PWD/e2e-out}"
mkdir -p "$OUT/release" "$OUT/flow"

adb wait-for-device
adb shell 'while [ -z "$(getprop sys.boot_completed)" ]; do sleep 1; done'
adb shell input keyevent 82 </dev/null || true
adb shell settings put global window_animation_scale 0 </dev/null || true
adb shell settings put global transition_animation_scale 0 </dev/null || true
adb shell settings put global animator_duration_scale 0 </dev/null || true
# No crash/ANR pop-ups from other apps (the launcher often ANRs on a cold CI emulator and its
# dialog covered every screenshot). Our own crashes/ANRs are still caught from logcat below.
adb shell settings put global hide_error_dialogs 1 </dev/null || true
DEVICE="$(adb devices | awk 'NR==2 {print $1}')"
echo "device: $DEVICE"
adb shell getprop ro.build.version.release </dev/null | sed 's/^/android: /'

shot() { adb exec-out screencap -p </dev/null > "$1" 2>/dev/null || true; }
grant() { adb shell pm grant "$PKG" android.permission.POST_NOTIFICATIONS </dev/null >/dev/null 2>&1 || true; }

# Background watcher for system dialogs that would cover the app on a slow CI emulator:
#  - runtime-permission dialogs → "Allow" (fallback for a race with grant)
#  - "<app> isn't responding" → close it when it is another app (the launcher often ANRs on
#    first boot); when it is Kizuki itself, record it in $OUT/anr.txt and keep waiting.
tap_id() { # $1 = resource-id suffix; prints "x y" of that view's centre, if present
  adb shell uiautomator dump /sdcard/ui.xml </dev/null >/dev/null 2>&1
  adb exec-out cat /sdcard/ui.xml </dev/null > /tmp/ui.xml 2>/dev/null
  ID="$1" python3 - <<'PY'
import os, re
xml = open('/tmp/ui.xml', encoding='utf-8', errors='ignore').read()
m = re.search(re.escape(os.environ['ID']) + r'"[^>]*?bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', xml)
if m:
    a, b, c, d = map(int, m.groups())
    print((a + c) // 2, (b + d) // 2)
PY
}
watch_dialogs() {
  while true; do
    focus=$(adb shell dumpsys window </dev/null 2>/dev/null | grep -m1 'mCurrentFocus' || true)
    if adb shell dumpsys window windows </dev/null 2>/dev/null | grep -q 'Application Not Responding'; then
      focus="$(adb shell dumpsys window windows </dev/null 2>/dev/null | grep -m1 'Application Not Responding') Not Responding"
    fi
    case "$focus" in
      *GrantPermissionsActivity*)
        xy=$(tap_id permission_allow_button)
        if [ -n "$xy" ]; then echo "allowing permission dialog at $xy"; adb shell input tap $xy </dev/null; fi
        ;;
      *"Not Responding"*)
        if printf '%s' "$focus" | grep -q "$PKG"; then
          echo "$(date -u +%T) $focus" >> "$OUT/anr.txt"
          xy=$(tap_id aerr_wait)
        else
          xy=$(tap_id aerr_close)
        fi
        if [ -n "$xy" ]; then echo "dismissing ANR dialog ($focus) at $xy"; adb shell input tap $xy </dev/null; fi
        ;;
    esac
    sleep 2
  done
}
watch_dialogs &
WATCH_PID=$!

# ---------------------------------------------------------------- 1. release smoke test
echo "== release smoke test: $APK"
adb install -r "$APK" </dev/null | tee "$OUT/release/install.txt"
grant
adb logcat -c </dev/null
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 </dev/null >/dev/null 2>&1
prev=0
for s in 2 5 10 25; do
  sleep $((s - prev)); prev=$s
  shot "$OUT/release/launch_${s}s.png"
done
# Tap "Get started" (bottom-centre button) and capture the first onboarding question.
size=$(adb shell wm size </dev/null | awk -F'[ x]' '/Physical/ {print $3" "$4}')
w=${size% *}; h=${size#* }
sleep 4 # lets the watcher clear any system dialog first
adb shell input tap $((w / 2)) $((h * 875 / 1000)) </dev/null
sleep 3
shot "$OUT/release/after_get_started.png"
# The tap must have moved the release build from the welcome screen into onboarding.
if cmp -s "$OUT/release/launch_25s.png" "$OUT/release/after_get_started.png"; then echo "unchanged" > "$OUT/release/navigation.txt"; else echo "moved on" > "$OUT/release/navigation.txt"; fi
if adb shell pidof "$PKG" </dev/null >/dev/null; then echo "running" > "$OUT/release/process.txt"; else echo "NOT RUNNING (crashed?)" > "$OUT/release/process.txt"; fi
adb logcat -d -v time </dev/null > "$OUT/release/logcat.txt"
grep -E "FATAL EXCEPTION|AndroidRuntime|E/flutter|KIZUKI_ERROR|Impeller|libc.*Fatal|ANR in $PKG" "$OUT/release/logcat.txt" > "$OUT/release/errors.txt" || true
echo "release process: $(cat "$OUT/release/process.txt")"
echo "release error lines: $(wc -l < "$OUT/release/errors.txt")"
if ! grep -q '^running$' "$OUT/release/process.txt" || grep -Eq "FATAL EXCEPTION|KIZUKI_ERROR|ANR in $PKG" "$OUT/release/logcat.txt"; then
  echo "Release crashed or stopped; refusing to pass this APK"
  exit 1
fi
adb uninstall "$PKG" </dev/null >/dev/null 2>&1 || true

# ---------------------------------------------------------------- 2. profile-mode flow test
echo "== flow test (profile mode)"
( for _ in $(seq 1 600); do
    if adb shell pm list packages "$PKG" </dev/null 2>/dev/null | grep -q "$PKG"; then grant; echo "granted notifications"; break; fi
    sleep 1
  done ) &
GRANT_PID=$!
adb logcat -c </dev/null
size=$(adb shell wm size </dev/null | awk -F'[ x]' '/Physical/ {print $3" "$4}')
W=${size% *}; H=${size#* }
echo "screen: ${W}x${H}"
( adb logcat -v raw -s flutter:I </dev/null | while IFS= read -r line; do
    case "$line" in
      *E2E_SHOT*)
        name=$(printf '%s' "${line##*E2E_SHOT }" | tr -cd 'A-Za-z0-9_-')
        shot "$OUT/flow/$name.png"
        echo "captured $name"
        ;;
      *E2E_SWIPE*)
        # A real finger on the subtitles (lower half), like a person: up/down = next/previous
        # clip, short = a small slow drag that must spring back, flick = short but fast.
        kind=$(printf '%s' "${line##*E2E_SWIPE }" | tr -cd 'a-z')
        x=$((W / 2))
        case "$kind" in
          up)    adb shell input swipe $x $((H * 80 / 100)) $x $((H * 45 / 100)) 260 </dev/null ;;
          down)  adb shell input swipe $x $((H * 50 / 100)) $x $((H * 85 / 100)) 260 </dev/null ;;
          short) adb shell input swipe $x $((H * 72 / 100)) $x $((H * 66 / 100)) 700 </dev/null ;;
          # 140ms supplies several velocity samples even on a busy software emulator;
          # 14% remains below the 18% distance threshold, so this still tests a flick.
          flick) adb shell input swipe $x $((H * 76 / 100)) $x $((H * 62 / 100)) 140 </dev/null ;;
        esac
        echo "swiped $kind"
        ;;
      *E2E_INFO*)
        echo "${line##*E2E_INFO }" >> "$OUT/flow/info.txt"
        ;;
      *KIZUKI_PLAYER*)
        echo "player ${line##*KIZUKI_PLAYER }" >> "$OUT/flow/info.txt"
        ;;
    esac
  done ) &
SHOT_PID=$!

flutter drive --profile --no-pub \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/app_flow_test.dart \
  -d "$DEVICE" 2>&1 | tee "$OUT/flow/drive.log"
RC=${PIPESTATUS[0]}

sleep 2
adb logcat -d -v time </dev/null > "$OUT/flow/logcat.txt"
grep -E "FATAL EXCEPTION|AndroidRuntime|E/flutter|KIZUKI_ERROR|ANR in $PKG" "$OUT/flow/logcat.txt" > "$OUT/flow/errors.txt" || true
kill "$GRANT_PID" "$WATCH_PID" "$SHOT_PID" 2>/dev/null || true
pkill -f "adb logcat" 2>/dev/null || true
echo "flow test exit code: $RC"
if grep -Eq "FATAL EXCEPTION|KIZUKI_ERROR|ANR in $PKG" "$OUT/flow/logcat.txt"; then
  echo "App crash/ANR recorded during flow"
  RC=1
fi
ls -1 "$OUT/flow" | sed 's/^/  /'
exit "$RC"
