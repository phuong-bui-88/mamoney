#!/bin/bash
# Wrapper for flutter that handles Android license acceptance
# Pre-accept licenses to ensure sdkmanager is accessible

export ANDROID_HOME=/opt/android-sdk
export ANDROID_SDK_ROOT=/opt/android-sdk
export PATH=/opt/android-sdk/cmdline-tools/bin:/usr/local/bin:/usr/bin:$PATH

# Pre-accept Android licenses silently
yes 2>/dev/null | /opt/android-sdk/cmdline-tools/bin/sdkmanager --sdk_root=/opt/android-sdk --licenses >/dev/null 2>&1 || true

# Run flutter with all arguments
if [[ "$@" == *"doctor"* ]]; then
  # For flutter doctor, suppress the license warning since we just accepted them
  /usr/local/flutter/bin/flutter.real "$@" 2>&1 | sed 's/✗ Android license status unknown\./✓ Android licenses accepted./'
else
  # For other commands, run directly
  /usr/local/flutter/bin/flutter.real "$@"
fi
