#!/bin/sh

# Fail this script if any subcommand fails.
set -e

# The default execution directory of this script is the ci_scripts directory.
cd $CI_PRIMARY_REPOSITORY_PATH # change working directory to the root of your cloned repo.

# Install Flutter using git.
git clone https://github.com/flutter/flutter.git --depth 1 -b stable $HOME/flutter
export PATH="$PATH:$HOME/flutter/bin"

# Install Flutter artifacts for iOS (--ios), or macOS (--macos) platforms.
flutter precache --ios
flutter config --no-enable-swift-package-manager

# CocoaPods trunk CDN occasionally times out on Xcode Cloud while resolving
# Firebase. Retry the config-only build so a single blip doesn't fail CI.
attempt=1
max_attempts=5
until ./build.sh "ios --config-only --no-codesign"; do
  if [ "$attempt" -ge "$max_attempts" ]; then
    echo "ios config build failed after $max_attempts attempts" >&2
    exit 1
  fi
  echo "ios config build failed (attempt $attempt/$max_attempts); retrying..."
  attempt=$((attempt + 1))
  sleep $((attempt * 10))
done
exit 0
