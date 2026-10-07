#!/bin/zsh
set -euo pipefail

device_id="${1:-0880ABCD-F1A1-4AF2-96E9-C1DA26ACDCE7}"
output_dir="${2:-output/app-store-screenshots/raw}"
mkdir -p "$output_dir"

flutter test integration_test/app_store_screenshots_test.dart -d "$device_id" 2>&1 |
while IFS= read -r line; do
  print -r -- "$line"
  if [[ "$line" == *"APP_STORE_CAPTURE:"* ]]; then
    name="${line##*APP_STORE_CAPTURE:}"
    name="${name%%[[:space:]]*}"
    xcrun simctl io "$device_id" screenshot --type=png "$output_dir/$name.png"
  fi
done
