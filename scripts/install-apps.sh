#!/bin/zsh
set -euo pipefail

project_dir=${0:A:h:h}
install_dir=${1:-"$HOME/Applications"}
app_names=("Android Tablet" "Android 日本語切替" "画像をAndroidへ送る")

if [[ -z "$install_dir" || "$install_dir" == "/" ]]; then
  echo "Unsafe install directory: $install_dir" >&2
  exit 1
fi

mkdir -p "$install_dir"
for name in "${app_names[@]}"; do
  source_app="$project_dir/dist/$name.app"
  target_app="$install_dir/$name.app"
  [[ -d "$source_app" ]] || { echo "Missing build: $source_app" >&2; exit 1; }
  rm -rf "$target_app"
  ditto "$source_app" "$target_app"
  echo "Installed $target_app"
done
