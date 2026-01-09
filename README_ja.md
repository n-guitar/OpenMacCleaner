# OpenMacCleaner

![Platform](https://img.shields.io/badge/platform-macOS-lightgrey)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-blue)

> [!NOTE]
> この製品は **Antigravity** (生成AI) を利用して作成されました。

> [!CAUTION]
> **自己責任でご利用ください。**
> 本アプリケーションは、その特性上、ユーザーの操作に基づいてファイルの削除を実行します。開発者は、本アプリの使用によって生じたデータの消失やシステムの不具合について、一切の責任を負いません。削除の前には必ず重要なファイルを確認してください。

**[🇺🇸 English README is here](README.md)**

OpenMacCleanerは、不要なファイルを削除してディスク容量を解放するための、macOS用オープンソース・システムクリーニングユーティリティです。

## 概要

<img src="docs/images/image1.png" width="45%"> <img src="docs/images/image2.png" width="45%">

*(画面はイメージです)*

OpenMacCleanerは、アプリケーションキャッシュ、ログ、未使用の開発者データなど、システム内の様々なジャンクファイルをスキャンします。macOSネイティブのクリーンなインターフェースで、これらの項目を確認し、安全に削除することができます。

## 機能

- **システムスキャン**: 削除しても安全なファイルを素早く特定します。
    - ユーザーキャッシュ
    - ログファイル
    - Xcode Derived Data (開発者ジャンク)
    - 未使用のアプリケーションデータ
- **安全第一**: 「安全」「注意」「危険」のラベルを表示し、重要なシステムファイルの誤削除を防ぎます。
- **大容量ファイル検索**: ホームディレクトリとアプリケーションフォルダ内の100MB以上のファイルを検出します。
- **モダンなUI**: 100% SwiftUIで構築され、ライトモードとダークモードの両方に対応しています。
- **CLI (実験的機能)**: システム診断やスキャンを行うための実験的なコマンドラインラインツールです。

## 動作環境

- macOS 13.0 (Ventura) 以降
- Xcode 15+ (ビルドする場合)

## インストール

[Releasesページ](https://github.com/n-guitar/OpenMacCleaner/releases) から最新版をダウンロードしてください。

1. `OpenMacCleaner.zip` を解凍します。
2. `OpenMacCleaner.app` をアプリケーションフォルダに移動します。
3. アプリを開きます（未署名のため、初回は右クリックして「開く」を選択する必要がある場合があります）。

## ビルドと実行 (開発者向け)

1. リポジトリをクローンします。
   ```bash
   git clone https://github.com/n-guitar/OpenMacCleaner.git
   cd OpenMacCleaner
   ```

2. Xcodeでプロジェクトを開きます。
   ```bash
   open OpenMacCleanerApp/OpenMacCleanerApp.xcodeproj
   ```

3. ビルドして実行します (Cmd+R)。

## ライセンス

MIT License
