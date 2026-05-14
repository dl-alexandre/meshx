#!/bin/bash
# android/build_device.sh — Build and install MeshxMobileApp on an Android device.
#
# Smallest possible wrapper for the shell PR: it only invokes Gradle to
# assemble + install the debug APK. The BEAM/Mob runtime is not yet wired
# in (Kotlin BLE bridge and native OTP boot will land in follow-up PRs);
# until then the installed app is a placeholder Activity proving the
# manifest, permissions, and Gradle project build cleanly.
#
# Usage:
#   android/build_device.sh                # installs to the single attached device
#   android/build_device.sh <device-serial> # installs to a specific device
#
# Requires ANDROID_HOME (or ANDROID_SDK_ROOT) and a Gradle wrapper. If the
# project doesn't yet have a gradle/wrapper directory checked in, run
# `gradle wrapper` once inside android/ to generate it.

set -e
cd "$(dirname "$0")"

DEVICE_SERIAL="${1:-}"

if [ ! -x "./gradlew" ]; then
    echo "ERROR: ./gradlew not found in android/."
    echo "       Run 'gradle wrapper --gradle-version 8.7' inside android/ to generate it."
    exit 1
fi

if [ -n "$DEVICE_SERIAL" ]; then
    export ANDROID_SERIAL="$DEVICE_SERIAL"
    echo "=== Installing on device $DEVICE_SERIAL ==="
else
    echo "=== Installing on default attached device ==="
fi

./gradlew --no-daemon installDebug

echo "=== Build and install complete ==="
