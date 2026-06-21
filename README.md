# 居酒屋スタッフ管理アプリ

居酒屋の現場業務を効率化するための Flutter 製スタッフ向けモバイル/Webアプリです。  
Firebaseをバックエンドに採用し、複数デバイス間でリアルタイムに注文情報を共有できます。

**デモサイト（GitHub Pages）:** https://kanenosu.github.io/izakaya_staff_app/  
※ デモ用ログイン → ID: `maki` / パスワード: `makimaki`

---

## 主な機能

| 画面 | 機能概要 |
|------|----------|
| ログイン | スタッフID・パスワード認証 |
| 注文管理 | テーブル一覧のリアルタイム表示。未提供注文を赤字で強調、最終注文からの経過時間を表示 |
| ハンディ注文 | `maki_menu` 互換の入力形式。カテゴリ見出し付きグリッドをタップでカートへ追加 → 数量を ± で調整 → 席ごとにまとめて Firestore へ送信。音声認識（Whisper）デモボタン搭載 |
| 在庫管理 | 在庫数の増減、閾値設定による在庫切れ警告、カテゴリフィルタ |
| メニュー管理 | 管理者向け。メニューの追加・削除・並び替え（ドリンクはサブカテゴリ別） |
| 日本酒一覧 | 日本酒カタログ。動画プレビュー、タグ検索対応 |
| 会計履歴 | 会計済み伝票の一覧・明細確認 |

---

## 使用技術

| カテゴリ | 技術 |
|----------|------|
| フレームワーク | Flutter (Dart) |
| バックエンド | Firebase Firestore（リアルタイムDB） |
| 認証 | 独自ID・パスワード認証（Firestore管理） |
| 主要パッケージ | `cloud_firestore`, `firebase_core`, `flutter_staggered_grid_view`, `video_player`, `intl` |
| 対応プラットフォーム | Android / iOS / Web |

---

## 画面構成・操作フロー

```
ログイン画面
    └── 注文管理画面（テーブル一覧グリッド）
            ├── シングルタップ：注文詳細ダイアログ（会計ボタン付き）
            ├── ダブルタップ：ハンディ注文画面（maki_menu 入力形式）
            │       ├── メニューカードをタップ → カートへ追加
            │       ├── 注文確認モーダルで数量を ± 調整
            │       ├── 「まとめて送信」で席ごとに保存
            │       └── 🎤 音声認識（Whisper デモ）ボタン
            └── スワイプ or ボトムナビ
                    ├── 日本酒一覧
                    ├── 在庫管理
                    └── メニュー管理（管理者）
```

## maki_menu システムの導入

顧客向け多言語メニュー Web アプリ [`maki_menu`](https://github.com/kanenosu/maki_menu) の
「タップでカート追加 → 数量調整 → 注文確認」という入力 UX をハンディ注文画面に移植。
スタッフ操作に最適化しつつ、デザインをモダン・シンプル・スタイリッシュに刷新した。

- **入力形式**: カテゴリ見出し付きカードグリッド（ドリンクはサブカテゴリ別）＋カテゴリ絞り込みチップ
- **カート**: 下部バーから注文確認ボトムシートを開き、数量を ± で調整・合計金額を表示
- **席ごと保存**: `tables/{tableId}/orders` に `WriteBatch` で一括登録
- **音声認識（デモ）**: Whisper を模した録音アニメーション付きボタン。実際の通信は行わず、
  認識 UX を体験できるデモ実装（`lib/services/whisper_service.dart`）

---

## アーキテクチャ

- **データ層**: Cloud Firestore のリアルタイムリスナー（`StreamBuilder`）を使い、UI が常に最新状態を反映
- **状態管理**: Flutter 標準の `StatefulWidget` + `setState` を採用
- **画面遷移**: `MaterialApp` の名前付きルート + ジェスチャーナビゲーション（左右スワイプ）
- **Firestore 操作**: 会計処理は `WriteBatch` で複数ドキュメントをアトミックに更新

### Firestore コレクション設計

```
tables/{tableId}/orders/{orderId}
  - item: string       # 商品名
  - price: number      # 単価
  - qty: number        # 数量
  - status: string     # "未提供" | "提供済み"
  - timestamp: timestamp

payments/{paymentId}
  - tableId: string
  - paidAt: timestamp
  - items: array       # 会計時点のスナップショット

menu_items/{itemId}
  - name: string
  - price: number
  - category: string
  - subCategory: string  # ドリンクのみ
  - order: number        # 表示順

inventory/{itemId}
  - name: string
  - category: string
  - stock: number
  - threshold: number    # 警告閾値

sake/{sakeId}
  - name: string
  - tags: array
  - imageUrl: string
  - videoUrl: string
  - price: number
```

---

## セットアップ・実行手順

### 前提条件

- Flutter SDK（`^3.7.2`）
- Firebase プロジェクト（Firestore 有効化済み）

### 手順

```bash
# 1. リポジトリのクローン
git clone https://github.com/kanenosu/izakaya_staff_app.git
cd izakaya_staff_app

# 2. 依存パッケージのインストール
flutter pub get

# 3. Firebase の設定
#    FlutterFire CLI で lib/firebase_options.dart を生成してください
flutterfire configure

# 4. アプリ起動
flutter run
```

> **Firestore セキュリティルール**: 本番環境では適切なルールを設定してください。

---

## 工夫した点

- **リアルタイム同期**: Firestore の `snapshots()` を `StreamBuilder` で購読することで、複数スタッフ端末間で注文状況が即座に反映されるよう設計
- **会計のアトミック処理**: 注文履歴への書き込みと注文データの削除を `WriteBatch` でまとめ、データ不整合を防止
- **UXの細部**: テーブルカードに最終注文からの経過時間を表示し、提供漏れを防ぐ。未提供アイテムを赤字で強調することで視認性を向上
- **スワイプナビゲーション**: 現場での片手操作を想定し、左右スワイプで画面を移動できるジェスチャーを実装
- **マソングリッドレイアウト**: 注文量によってカードの高さが変わる `MasonryGridView` を採用し、情報量に応じた自然なレイアウトを実現

---

## 今後の改善案

- [ ] Firebase Authentication への移行（よりセキュアなログイン）
- [ ] 状態管理の Riverpod 化
- [ ] 注文の push 通知対応
- [ ] レイアウトのレスポンシブ対応強化（タブレット向け）
- [ ] 単体テスト・ウィジェットテストの拡充
