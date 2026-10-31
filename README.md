# 工数モデリング

工数システムのデータモデリングに使う図書とツールを保管する。

## フォルダ構成

```text
man-hour/
├── README.md          このページ（索引）
├── docs/              図書
│   ├── planning/      進め方・タスク・取込方式の比較
│   ├── spec/          仕様書
│   │   ├── source/    取得元（工数システム）
│   │   ├── bronze/    Bronze
│   │   └── silver/    Silver
│   ├── adr/           設計判断の記録（ADR）
│   ├── research/      調査・検証の記録
│   └── learning/      モデリングの学習資料
└── tools/             ツール
```

フォルダ名・ファイル名は英語のハイフン区切りにする。ただし、Javaのファイルはクラス名と一致させる必要があるため元の名前のままにする。

## 進め方

- [進め方＆タスク](docs/planning/plan-and-tasks.md)
  - [事前準備タスク｜工数データ取込方式の比較](docs/planning/ingestion-method-comparison.md)
  - [更新方式シミュレーションの要求事項](docs/planning/update-method-simulation-requirements.md)

## 仕様書

| 層 | コンセプト（方針・理由） | テーブル仕様（列・型・検査） |
| --- | --- | --- |
| 取得元 | — | [工数システム テーブル仕様書](docs/spec/source/table.md) |
| Bronze | [concept.md](docs/spec/bronze/concept.md) | [table.md](docs/spec/bronze/table.md) |
| Silver | [concept.md](docs/spec/silver/concept.md) | [table.md](docs/spec/silver/table.md) |

- 定数ファイル：[KeijoKosuConstants.java](docs/spec/source/KeijoKosuConstants.java)
- Boxの仕様書フォルダ：<https://mhig.ent.box.com/folder/182098082900>

## 接続情報

> [!CAUTION]
> サーバー名・ユーザーID・パスワードはマスクしている。実際の値はこのフォルダに書かず、別に管理する。

```text
サーバー：********（マスク済み）
データベース：GEMS_DM_S
認証方式：SQL Server認証
ユーザーID：********（マスク済み）
パスワード：********（マスク済み）
```

データは以下のビューから取得可能です。データは本日時点の本番環境のデータをコピーしてあります。

| データ | 工数計上システムのIF | ビュー |
| --- | --- | --- |
| 工数データ出力 | IF05 | V_T_OKS02 |
| 締切済工数修正情報 | IF21 | V_T_OKS07（前月より前の） |
| 変更履歴情報 | IF24 | V_T_OKS10 |

## 学習資料

- [モデリング講座](docs/learning/modeling-course.md)
- [工数モデリング｜学習の要点](docs/learning/key-takeaways.md)

## 調査・検証の記録

- [調査まとめ｜承認済みの工数はどこにある？（2026-10-27）](docs/research/2026-10-27-where-are-approved-man-hours.md)
- [サンプルデータ](docs/research/sample-data.md)
- [図書の点検記録（2026-10-31）](docs/research/2026-10-31-document-consistency-review.md)

## 設計判断の記録（ADR）

- [ADR-001 社員は「会社コード＋ユーザID」で識別する](docs/adr/adr-001-identify-employees-by-company-code-and-user-id.md)
- [ADR-002 Bronzeに繰り返し入る変更履歴（V_T_OKS10）をSilverでどう扱うか](docs/adr/adr-002-handle-repeated-oks10-change-history-in-silver.md)
- [ADR-003 最新の入力と承認済み実績を別のfactにし、承認済みは承認ゲートで作る](docs/adr/adr-003-separate-latest-input-and-approved-actuals.md)

## メモ

- この実装したときにどう可視化できるのか？
- チャネルに投稿→こんな使い方したい等あるかT向けに発信
