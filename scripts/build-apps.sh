#!/bin/zsh
set -euo pipefail

project_dir=${0:A:h:h}
dist_dir="$project_dir/dist"
configuration=${CONFIGURATION:-debug}

swift build --package-path "$project_dir" --configuration "$configuration" --disable-sandbox
bin_dir=$(swift build --package-path "$project_dir" --configuration "$configuration" --disable-sandbox --show-bin-path)

rm -rf "$dist_dir"
mkdir -p "$dist_dir"

build_app() {
  local executable=$1
  local app_name=$2
  local plist_name=$3
  local app_dir="$dist_dir/$app_name.app"

  mkdir -p "$app_dir/Contents/MacOS"
  cp "$bin_dir/$executable" "$app_dir/Contents/MacOS/$executable"
  cp "$project_dir/Resources/$plist_name-Info.plist" "$app_dir/Contents/Info.plist"
  codesign --force --sign - "$app_dir"
  echo "Built $app_dir"
}

build_app AndroidTablet "Android Tablet" AndroidTablet
build_app AndroidJapaneseSwitch "Android 日本語切替" AndroidJapaneseSwitch
build_app SendClipboardImage "画像をAndroidへ送る" SendClipboardImage
