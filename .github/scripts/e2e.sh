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

PKG="com.kizuki.app"
APK="${APK:?path to the release APK}"
OUT="${OUT:-$PWD/e2e-out}"
mkdir -p "$OUT/release" "$OUT/flow"

adb wait-for-device
adb shell 'while [ -z "$(getprop sys.boot_completed)" ]; do sleep 1; done'
adb shell input keyevent 82 </dev/null || true
adb shell settings put global window_animation_scale 0 </dev/null || true
adb shell settings put global transition_animation_scale 0 </dev/null || true
adb shell settings put global animator_duration_scale 0 </dev/null || true
DEVICE="$(adb devices | awk 'NR==2 {print $1}')"
echo "device: $DEVICE"
adb shell getprop ro.build.version.release </dev/null | sed 's/^/android: /'

shot() { adb exec-out screencap -p </dev/null > "$1" 2>/dev/null || true; }
grant() { adb shell pm grant "$PKG" android.permission.POST_NOTIFICATIONS </dev/null >/dev/null 2>&1 || true; }

# Tap "Allow" on a runtime-permission dialog if one ever shows (fallback for a race with grant).
allow_dialogs() {
  while true; do
    if adb shell dumpsys window </dev/null 2>/dev/null | grep -q 'mCurrentFocus.*GrantPermissionsActivity'; then
      adb shell uiautomator dump /sdcard/ui.xml </dev/null >/dev/null 2>&1
      adb exec-out cat /sdcard/ui.xml </dev/null > /tmp/ui.xml 2>/dev/null
      xy=$(python3 - <<'PY'
import re
xml = open('/tmp/ui.xml', encoding='utf-8', errors='ignore').read()
m = re.search(r'permission_allow_button"[^>]*?bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', xml)
if m:
    a, b, c, d = map(int, m.groups())
    print((a + c) // 2, (b + d) // 2)
PY
)
      if [ -n "$xy" ]; then echo "allowing permission dialog at $xy"; adb shell input tap $xy </dev/null; fi
    fi
    sleep 2
  done
}

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
adb shell input tap $((w / 2)) $((h * 84 / 100)) </dev/null
sleep 3
shot "$OUT/release/after_get_started.png"
if adb shell pidof "$PKG" </dev/null >/dev/null; then echo "running" > "$OUT/release/process.txt"; else echo "NOT RUNNING (crashed?)" > "$OUT/release/process.txt"; fi
adb logcat -d -v time </dev/null > "$OUT/release/logcat.txt"
grep -E "FATAL EXCEPTION|AndroidRuntime|E/flutter|KIZUKI_ERROR|Impeller|libc.*Fatal" "$OUT/release/logcat.txt" > "$OUT/release/errors.txt" || true
echo "release process: $(cat "$OUT/release/process.txt")"
echo "release error lines: $(wc -l < "$OUT/release/errors.txt")"
adb uninstall "$PKG" </dev/null >/dev/null 2>&1 || true

# ---------------------------------------------------------------- 2. profile-mode flow test
echo "== flow test (profile mode)"
( for _ in $(seq 1 600); do
    if adb shell pm list packages "$PKG" </dev/null 2>/dev/null | grep -q "$PKG"; then grant; echo "granted notifications"; break; fi
    sleep 1
  done ) &
GRANT_PID=$!
allow_dialogs &
ALLOW_PID=$!
adb logcat -c </dev/null
( adb logcat -v raw -s flutter:I </dev/null | while IFS= read -r line; do
    case "$line" in
      *E2E_SHOT*)
        name=$(printf '%s' "${line##*E2E_SHOT }" | tr -cd 'A-Za-z0-9_-')
        shot "$OUT/flow/$name.png"
        echo "captured $name"
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
grep -E "FATAL EXCEPTION|AndroidRuntime|E/flutter|KIZUKI_ERROR" "$OUT/flow/logcat.txt" > "$OUT/flow/errors.txt" || true
kill "$GRANT_PID" "$ALLOW_PID" "$SHOT_PID" 2>/dev/null || true
pkill -f "adb logcat" 2>/dev/null || true
echo "flow test exit code: $RC"
ls -1 "$OUT/flow" | sed 's/^/  /'
exit "$RC"
