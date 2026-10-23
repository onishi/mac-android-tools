# mac-android-tools

Mac から Android Emulator を扱うための、小さな macOS アプリ集です。

| アプリ | 機能 |
| --- | --- |
| Android Tablet | 対象の Android Emulator を起動。起動済みなら手前に表示 |
| Android 日本語切替 | Mac の「英数」「かな」キーを Android のキーイベントへ転送 |
| 画像をAndroidへ送る | クリップボードまたは Finder で選択した画像を Emulator の `Download` フォルダへ転送 |

## 必要なもの

- macOS 13 以降
- Xcode Command Line Tools
- Android SDK（`adb` と `emulator`）
- 作成済みの Android Virtual Device (AVD)

Android SDK は `ANDROID_SDK_ROOT`、`ANDROID_HOME`、`~/Library/Android/sdk` の順に探索します。

## 設定

対象 AVD は [Sources/AndroidToolsCore/ToolConfiguration.swift](Sources/AndroidToolsCore/ToolConfiguration.swift) の
`avdName` で一元管理しています。

```swift
static let avdName = "Android_Tablet_API_36_1"
```

## ビルドとインストール

```sh
make build       # dist/ に3つの .app を作成
make install     # ~/Applications にインストール
make uninstall   # このプロジェクトで入れた3アプリを削除
make test        # 共通処理のテスト
```

通常はデバッグシンボルを含むローカル用ビルドです。最適化する場合は
`CONFIGURATION=release make build` を使います。

`make install` は同名アプリを置き換えます。出力先を変える場合は
`make install INSTALL_DIR=/path/to/apps` と指定できます。

初回起動時、「Android 日本語切替」には macOS のアクセシビリティ権限を許可してください。

### 画像を送る

- アプリを普通に起動: クリップボードの画像を送信
- Finder で画像を右クリック →「クイックアクション」または「サービス」→「画像をAndroidへ送る」
- 画像をアプリへドラッグ＆ドロップ、または「このアプリケーションで開く」

Finder からは複数の画像をまとめて送れます。元のファイル名と画像形式を保ったまま
Android の `Downloads` へ保存します。

## 構成

```text
Sources/
  AndroidToolsCore/       # adb、Emulator 検出、共通設定
  AndroidTablet/          # Emulator ランチャー
  AndroidJapaneseSwitch/  # 英数・かなキー転送（メニューバー常駐）
  SendClipboardImage/     # クリップボード・Finder画像転送
scripts/build-apps.sh     # .app バンドル生成
```
