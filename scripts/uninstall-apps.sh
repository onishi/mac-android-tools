#!/bin/zsh
set -euo pipefail

install_dir=${1:-"$HOME/Applications"}
app_names=("Android Tablet" "Android 日本語切替" "画像をAndroidへ送る")

if [[ -z "$install_dir" || "$install_dir" == "/" ]]; then
  echo "Unsafe install directory: $install_dir" >&2
  exit 1
fi

for name in "${app_names[@]}"; do
  target_app="$install_dir/$name.app"
  if [[ -d "$target_app" ]]; then
    rm -rf "$target_app"
    echo "Removed $target_app"
  fi
done
