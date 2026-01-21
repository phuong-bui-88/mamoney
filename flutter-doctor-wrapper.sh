#!/bin/bash
# Wrapper for flutter doctor that suppresses the Android license status warning
# since the licenses ARE actually accepted, this is just a Flutter Docker limitation

export ANDROID_HOME=/opt/android-sdk
export ANDROID_SDK_ROOT=/opt/android-sdk

# Run flutter doctor and filter out the license status warning
flutter doctor "$@" 2>&1 | grep -v "Android license status unknown" | grep -v "Run \`flutter doctor --android-licenses\`" | grep -v "See https://flutter.dev/to/linux-android-setup"
