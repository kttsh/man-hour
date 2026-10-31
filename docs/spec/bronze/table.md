# 工数 Bronze テーブル仕様書

> [!IMPORTANT]
> 正本（バージョン1.1、2026年10月29日）。3テーブルの列・型・管理列・物理設計・検査を定める。方針と理由は [docs/spec/bronze/concept.md](concept.md)、未確定事項はconceptの4節。DDL・取込・assertionの実装と動作確認は未実施。

参照：[工数システム テーブル仕様書](../source/table.md)（取得元の列定義）、[サンプルデータ](../../research/sample-data.md)（検証記録）

## 1. 対象テーブル

1行＝ある取得回のCSVの1レコード。業務上の一意キーは未確定で、管理列も単独ではPKにならない。

| Bronze名 | 取得元（GEMS_DM_S.dbo） | 列数 | 注意点 |
| --- | --- | --- | --- |
| bronze.oks02 | V_T_OKS02（工数データ出力） | 47（元43＋管理4） | 検証した複合候補で複数行・工数違いあり。工数をキーにせず、合算・重複除去しない |
| bronze.oks07 | V_T_OKS07（締切済工数修正情報） | 70（元66＋管理4） | 複合候補（社員日＋照合キー9列＋correction_num）は現データで重複なしだが一意性は未保証。修正前工数のNULL・0工数・複数回修正を保持 |
| bronze.oks10 | V_T_OKS10（変更履歴情報） | 54（元50＋管理4） | 変更履歴IDは単独で非一意（全列同値の2行あり）。DISTINCTで消さない |

## 2. 共通仕様

### 2.1 配置と物理設計

| 項目 | 内容 |
| --- | --- |
| プロジェクト・リージョン | man-hour／asia-（確認待ち） |
| データセット | bronze（環境別の完全名は未確定） |
| パーティション | snapshot_date（日本時間のBronze取込日）の日次パーティション |
| クラスタリング | 当初なし。量・読取条件・効果を見て追加を検討 |
| 保存期限 | パーティションの自動削除期限なし |
| description | 案：「〈ビュー名〉の日次CSVを取得回ごとに保持する。元の0・NULL・重複行を業務上の判断で除去しない。」（最終文言は未確定） |
| アクセス権 | 未確定 |

### 2.2 列・型

元列名・元列順を維持し、末尾に管理4列を追加する。改名・削除・空白除去・コードの意味付けはしない。

| 取得元の型 | Bronze型 | 扱い |
| --- | --- | --- |
| varchar／nvarchar | STRING | 先頭ゼロを維持 |
| decimal(5,1) | NUMERIC | 数値のまま |
| bigint | INT64 | 整数のまま |
| datetime | DATETIME | タイムゾーンなし。時刻基準は未確認 |

- keijo_dateはSTRING（yyyymmdd）のまま保持し、DATE化はSilverで行う。
- NULL可否は取得元仕様書の必須「○」に従う（○はNOT NULL）。NULLを0・空文字で補完しない。空文字はNOT NULLでも許容する。

### 2.3 管理列（すべてNOT NULL）

| 列名 | 型 | 内容 |
| --- | --- | --- |
| `_batch_id` | STRING | BigQuery取込処理ID。同じ取込処理の行に同じID。3ビュー共通IDでも行の一意キーでもない。生成式は未確定 |
| `_loaded_at` | TIMESTAMP | Bronze取込日時。付与式は実装時に定義 |
| `_source_file` | STRING | 読み込んだCSVのGCSパス（archive/へ移動後も取込時のパスのまま） |
| `snapshot_date` | DATE | DATE(_loaded_at, 'Asia/Tokyo')。遅延取込でも実際の取込日を記録 |

DataSpiderの取得回ID・抽出開始時刻は保持しない（_extracted_atは設けない）。

### 2.4 取込

- 外部テーブルはGCSのwork/とarchive/を参照する（GCSパス・ファイル命名・source_urisは未確定）。
- 通常取込はwork/のCSVのみ。`_FILE_NAME`と`_source_file`のbasenameを照合し、未取込ファイルの全行・全列を追加する（basenameは再利用されない前提）。
- ROW_NUMBERによる絞込み・uniqueKeyのMERGEはしない。ファイル名から抽出時刻・新旧を推測しない。
- 取込成功後、CSVをwork/からarchive/へ移動する（basenameは変えない）。
- 0件CSVは届かない前提。再実行・失敗時の制御、フルリフレッシュはWorkflows側・後工程で定義する。

### 2.5 検査

| 検査 | 期待結果 | 状況 |
| --- | --- | --- |
| 件数一致 | `_batch_id`×`_source_file`ごとに、CSVのレコード数（ヘッダー除く。改行数ではなくCSVとして読んだ数）＝Bronzeの行数。取込対象のファイル一覧を基に照合し、CSV件数が取れない場合は一致扱いしない | カスタムassertion（不一致を返し0行で正常）。CSV件数の受渡しは未確定 |
| 必須列 | 必須列・管理4列にNULLがない | NOT NULL制約 |
| 重複 | 同じ取得回の中で候補キー別の重複件数を記録（行は削除しない）。取得回をまたぐ重複とは分けて確認 | 一意性assertionは識別方法の確定後 |
| 0・NULL・空文字 | 除去・相互変換しない | — |

## 3. テーブル定義

取得元の列定義は工数システム テーブル仕様書に従う。備考の「候補」はPK指定ではない。

### 3.1 oks02

| No. | 列名 | 型 | 論理名 | 取得元の型 | NULL可 | 備考 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `company_cd` | STRING | 会社コード | nvarchar(3) | 不可 | OpenGIM・会社コード |
| 2 | `keijo_date` | STRING | 計上日付 | varchar(8) | 不可 | yyyymmdd |
| 3 | `user_id` | STRING | ユーザID | varchar(7) | 不可 | OpenGIM・ユーザID |
| 4 | `mhi_emp_no` | STRING | 従業員番号 | varchar(6) | 不可 | OpenGIM・従業員番号 |
| 5 | `sei_mei` | STRING | 氏名 | nvarchar(262) | 不可 | OpenGIM・氏名・姓＋氏名・名 |
| 6 | `shozoku_cd` | STRING | 所属コード | varchar(12) | 不可 |  |
| 7 | `shozoku_name` | STRING | 所属名称 | nvarchar(905) | 不可 | OpenGIM・所属名の連結（事業所〜班の略称） |
| 8 | `keijo_genka_center_cd` | STRING | 賃金計上先原価センタ | nvarchar(10) | 不可 |  |
| 9 | `keijo_genka_center_name` | STRING | 賃金計上先原価センタ名称 | nvarchar(40) | 不可 |  |
| 10 | `wbs_cd` | STRING | WBS要素 | nvarchar(24) | 不可 | S4で決まっているもの |
| 11 | `wbs_name` | STRING | WBS名称 | nvarchar(40) | 不可 | S4で決まっているもの |
| 12 | `opa_cd` | STRING | OPA | nvarchar(12) | 不可 | S4で決まっているもの |
| 13 | `opa_name` | STRING | OPA名称 | nvarchar(40) | 不可 | S4で決まっているもの |
| 14 | `genka_center_cd` | STRING | 原価センタ | nvarchar(10) | 不可 | S4で決まっているもの |
| 15 | `genka_center_name` | STRING | 原価センタ名称 | nvarchar(40) | 不可 | S4で決まっているもの |
| 16 | `katudo_type` | STRING | 活動タイプ | varchar(6) | 不可 | S4で決まっているもの |
| 17 | `katudo_type_name` | STRING | 活動タイプ名称 | nvarchar(20) | 不可 | S4で決まっているもの |
| 18 | `mhi_wbs` | STRING | MHI WBS | varchar(36) | 不可 |  |
| 19 | `mhi_wbs_name` | STRING | MHI WBS 名称 | nvarchar(40) | 不可 |  |
| 20 | `kyotenbetu_bunseki_key` | STRING | 拠点別分析キー | varchar(8000) | 可 |  |
| 21 | `youeki_cd` | STRING | 用役コード | varchar(10) | 不可 |  |
| 22 | `shokushu_cd` | STRING | 職種コード | varchar(10) | 不可 |  |
| 23 | `keijo_kosu` | NUMERIC | 計上工数 | decimal(5,1) | 不可 |  |
| 24 | `text_item01` | STRING | テキスト項目01 | nvarchar(4000) | 可 |  |
| 25 | `text_item02` | STRING | テキスト項目02 | nvarchar(4000) | 可 |  |
| 26 | `text_item03` | STRING | テキスト項目03 | nvarchar(4000) | 可 |  |
| 27 | `text_item04` | STRING | テキスト項目04 | nvarchar(4000) | 可 |  |
| 28 | `text_item05` | STRING | テキスト項目05 | nvarchar(4000) | 可 |  |
| 29 | `text_item06` | STRING | テキスト項目06 | nvarchar(4000) | 可 |  |
| 30 | `text_item07` | STRING | テキスト項目07 | nvarchar(4000) | 可 |  |
| 31 | `text_item08` | STRING | テキスト項目08 | nvarchar(4000) | 可 |  |
| 32 | `text_item09` | STRING | テキスト項目09 | nvarchar(4000) | 可 |  |
| 33 | `text_item10` | STRING | テキスト項目10 | nvarchar(4000) | 可 |  |
| 34 | `shusei_flg` | STRING | 修正フラグ | varchar(1) | 不可 |  |
| 35 | `shusei_riyu` | STRING | 修正理由 | nvarchar(4000) | 可 |  |
| 36 | `status` | STRING | ステータス | varchar(1) | 不可 |  |
| 37 | `if_status` | STRING | I/Fステータス | varchar(1) | 不可 |  |
| 38 | `shuusei_siji` | STRING | 修正指示内容 | nvarchar(4000) | 可 |  |
| 39 | `insert_user` | STRING | 登録ユーザ | nvarchar(10) | 不可 |  |
| 40 | `insert_date` | DATETIME | 登録日時 | datetime | 不可 |  |
| 41 | `update_user` | STRING | 更新ユーザ | nvarchar(10) | 不可 |  |
| 42 | `update_date` | DATETIME | 更新日時 | datetime | 不可 |  |
| 43 | `machine_flg` | STRING | マシン区分 | varchar(1) | 不可 |  |
| 44 | `_batch_id` | STRING | BigQuery取込処理ID | — | 不可 | 管理列（2.3） |
| 45 | `_loaded_at` | TIMESTAMP | Bronze取込日時 | — | 不可 | 管理列（2.3） |
| 46 | `_source_file` | STRING | 取込元ファイル | — | 不可 | 管理列（2.3） |
| 47 | `snapshot_date` | DATE | Bronze取込日 | — | 不可 | 管理列（2.3） |

### 3.2 oks07

| No. | 列名 | 型 | 論理名 | 取得元の型 | NULL可 | 備考 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `company_cd` | STRING | 会社コード | nvarchar(3) | 不可 | 複合候補の一部（未保証）。OpenGIM・会社コード |
| 2 | `keijo_date` | STRING | 計上日付 | varchar(8) | 不可 | 複合候補の一部（未保証）。yyyymmdd |
| 3 | `shozoku_cd` | STRING | 所属コード | varchar(12) | 不可 |  |
| 4 | `shozoku_name` | STRING | 所属 | nvarchar(905) | 不可 | OpenGIM・所属名の連結（事業所〜班の略称） |
| 5 | `mhi_emp_no` | STRING | 従業員番号 | varchar(6) | 不可 | OpenGIM・従業員番号 |
| 6 | `machine_flg` | STRING | マシン区分 | varchar(1) | 不可 |  |
| 7 | `user_id` | STRING | ユーザID | varchar(7) | 不可 | 複合候補の一部（未保証）。OpenGIM・ユーザID |
| 8 | `sei_mei` | STRING | ユーザ名 | nvarchar(262) | 不可 | OpenGIM・氏名・姓＋氏名・名 |
| 9 | `correction_kbn` | STRING | 修正区分 | nvarchar(1) | 不可 |  |
| 10 | `correction_num` | STRING | 修正回数 | nvarchar(2) | 不可 | 複合候補の一部（未保証） |
| 11 | `keijo_genka_center_cd` | STRING | 賃金計上先原価センタ | nvarchar(10) | 不可 | 複合候補の一部（未保証） |
| 12 | `keijo_genka_center_name` | STRING | 賃金計上先原価センタ名称 | nvarchar(40) | 不可 |  |
| 13 | `wbs_cd` | STRING | WBS要素 | nvarchar(24) | 不可 | 複合候補の一部（未保証） |
| 14 | `wbs_name` | STRING | WBS名称 | nvarchar(40) | 不可 |  |
| 15 | `others_wbs` | STRING | OthersWBS | nvarchar(24) | 不可 |  |
| 16 | `opa_cd` | STRING | OPA | nvarchar(12) | 不可 | 複合候補の一部（未保証） |
| 17 | `opa_name` | STRING | OPA名称 | nvarchar(40) | 不可 |  |
| 18 | `sashizu` | STRING | 参照指図 | nvarchar(12) | 不可 |  |
| 19 | `genka_center_cd` | STRING | 原価センタ | nvarchar(10) | 不可 | 複合候補の一部（未保証） |
| 20 | `genka_center_name` | STRING | 原価センタ名称 | nvarchar(40) | 不可 |  |
| 21 | `katudo_type` | STRING | 活動タイプ | varchar(6) | 不可 | 複合候補の一部（未保証） |
| 22 | `katudo_type_name` | STRING | 活動タイプ名称 | nvarchar(20) | 不可 |  |
| 23 | `mhi_wbs` | STRING | MHI WBS | varchar(36) | 不可 | 複合候補の一部（未保証） |
| 24 | `mhi_wbs_name` | STRING | MHI WBS 名称 | nvarchar(40) | 不可 |  |
| 25 | `kyotenbetu_bunseki_key` | STRING | 拠点別分析キー | varchar(8000) | 可 | 複合候補の一部（未保証） |
| 26 | `youeki_cd` | STRING | 用役コード | varchar(10) | 不可 | 複合候補の一部（未保証） |
| 27 | `shokushu_cd` | STRING | 職種コード | varchar(10) | 不可 | 複合候補の一部（未保証） |
| 28 | `keijo_kosu` | NUMERIC | 計上工数 | decimal(5,1) | 可 |  |
| 29 | `shusei_mae_kosu` | NUMERIC | 修正前工数 | decimal(5,1) | 可 |  |
| 30 | `correction_user_id` | STRING | 修正ユーザ | nvarchar(10) | 不可 |  |
| 31 | `correction_user_name` | STRING | 修正ユーザ名 | nvarchar(262) | 不可 |  |
| 32 | `correction_date` | DATETIME | 修正登録日 | datetime | 不可 |  |
| 33 | `shonin_user_id` | STRING | 承認ユーザ | nvarchar(10) | 可 |  |
| 34 | `shonin_user_name` | STRING | 承認ユーザ名 | nvarchar(262) | 可 |  |
| 35 | `shonin_date` | DATETIME | 承認登録日 | datetime | 可 |  |
| 36 | `keiri_shonin_user_id` | STRING | 経理承認ユーザ | nvarchar(10) | 可 |  |
| 37 | `keiri_shonin_user_name` | STRING | 経理承認ユーザ名 | nvarchar(262) | 可 |  |
| 38 | `keiri_shonin_date` | DATETIME | 経理承認登録日 | datetime | 可 |  |
| 39 | `kakutei_user_id` | STRING | 確定ユーザ | nvarchar(10) | 可 |  |
| 40 | `kakutei_user_name` | STRING | 確定ユーザ名 | nvarchar(262) | 可 |  |
| 41 | `kakutei_date` | DATETIME | 確定登録日 | datetime | 可 |  |
| 42 | `simekiri_user_id` | STRING | 締切ユーザ | nvarchar(10) | 可 |  |
| 43 | `simekiri_user_name` | STRING | 締切ユーザ名 | nvarchar(262) | 可 |  |
| 44 | `simekiri_date` | DATETIME | 締切登録日 | datetime | 可 |  |
| 45 | `keiri_setuzoku_user_id` | STRING | 経理接続ユーザ | nvarchar(10) | 可 |  |
| 46 | `keiri_setuzoku_user_name` | STRING | 経理接続ユーザ名 | nvarchar(262) | 可 |  |
| 47 | `keiri_setuzoku_date` | DATETIME | 経理接続登録日 | datetime | 可 |  |
| 48 | `text_item01` | STRING | テキスト項目01 | nvarchar(4000) | 可 |  |
| 49 | `text_item02` | STRING | テキスト項目02 | nvarchar(4000) | 可 |  |
| 50 | `text_item03` | STRING | テキスト項目03 | nvarchar(4000) | 可 |  |
| 51 | `text_item04` | STRING | テキスト項目04 | nvarchar(4000) | 可 |  |
| 52 | `text_item05` | STRING | テキスト項目05 | nvarchar(4000) | 可 |  |
| 53 | `text_item06` | STRING | テキスト項目06 | nvarchar(4000) | 可 |  |
| 54 | `text_item07` | STRING | テキスト項目07 | nvarchar(4000) | 可 |  |
| 55 | `text_item08` | STRING | テキスト項目08 | nvarchar(4000) | 可 |  |
| 56 | `text_item09` | STRING | テキスト項目09 | nvarchar(4000) | 可 |  |
| 57 | `text_item10` | STRING | テキスト項目10 | nvarchar(4000) | 可 |  |
| 58 | `shusei_flg` | STRING | 修正フラグ | varchar(1) | 不可 |  |
| 59 | `shusei_riyu` | STRING | 修正理由 | nvarchar(4000) | 可 |  |
| 60 | `status` | STRING | ステータス | varchar(1) | 不可 |  |
| 61 | `if_status` | STRING | I/Fステータス | varchar(1) | 不可 |  |
| 62 | `shuusei_siji` | STRING | 修正指示内容 | nvarchar(4000) | 可 |  |
| 63 | `insert_user` | STRING | 登録ユーザ | nvarchar(10) | 不可 |  |
| 64 | `insert_date` | DATETIME | 登録日時 | datetime | 不可 |  |
| 65 | `update_user` | STRING | 更新ユーザ | nvarchar(10) | 不可 |  |
| 66 | `update_date` | DATETIME | 更新日時 | datetime | 不可 |  |
| 67 | `_batch_id` | STRING | BigQuery取込処理ID | — | 不可 | 管理列（2.3） |
| 68 | `_loaded_at` | TIMESTAMP | Bronze取込日時 | — | 不可 | 管理列（2.3） |
| 69 | `_source_file` | STRING | 取込元ファイル | — | 不可 | 管理列（2.3） |
| 70 | `snapshot_date` | DATE | Bronze取込日 | — | 不可 | 管理列（2.3） |

### 3.3 oks10

| No. | 列名 | 型 | 論理名 | 取得元の型 | NULL可 | 備考 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `hnko_rireki_id` | INT64 | 変更履歴ID | bigint | 不可 | 単独では非一意（検証済み） |
| 2 | `company_cd` | STRING | 会社コード | nvarchar(3) | 不可 | OpenGIM・会社コード |
| 3 | `keijo_date` | STRING | 計上日付 | varchar(8) | 不可 | yyyymmdd |
| 4 | `shozoku_cd` | STRING | 所属コード | varchar(12) | 不可 |  |
| 5 | `shozoku_name` | STRING | 所属 | nvarchar(905) | 不可 | OpenGIM・所属名の連結（事業所〜班の略称） |
| 6 | `mhi_emp_no` | STRING | 従業員番号 | varchar(6) | 不可 | OpenGIM・従業員番号 |
| 7 | `user_id` | STRING | ユーザID | varchar(7) | 不可 | OpenGIM・ユーザID |
| 8 | `sei_mei` | STRING | 氏名 | nvarchar(262) | 不可 | OpenGIM・氏名・姓＋氏名・名 |
| 9 | `keijo_genka_center_cd` | STRING | 賃金計上先原価センタ | nvarchar(10) | 不可 |  |
| 10 | `keijo_genka_center_name` | STRING | 賃金計上先原価センタ名称 | nvarchar(40) | 不可 |  |
| 11 | `wbs_cd` | STRING | WBS要素 | nvarchar(24) | 不可 |  |
| 12 | `wbs_name` | STRING | WBS名称 | nvarchar(40) | 不可 |  |
| 13 | `others_wbs` | STRING | OthersWBS | nvarchar(24) | 不可 |  |
| 14 | `opa_cd` | STRING | OPA | nvarchar(12) | 不可 |  |
| 15 | `opa_name` | STRING | OPA名称 | nvarchar(40) | 不可 |  |
| 16 | `sashizu` | STRING | 参照指図 | nvarchar(12) | 不可 |  |
| 17 | `genka_center_cd` | STRING | 原価センタ | nvarchar(10) | 不可 |  |
| 18 | `genka_center_name` | STRING | 原価センタ名称 | nvarchar(40) | 不可 |  |
| 19 | `katudo_type` | STRING | 活動タイプ | varchar(6) | 不可 |  |
| 20 | `katudo_type_name` | STRING | 活動タイプ名称 | nvarchar(20) | 不可 |  |
| 21 | `mhi_wbs` | STRING | MHI WBS | varchar(36) | 不可 |  |
| 22 | `mhi_wbs_name` | STRING | MHI WBS 名称 | nvarchar(40) | 不可 |  |
| 23 | `kyotenbetu_bunseki_key` | STRING | 拠点別分析キー | varchar(8000) | 可 |  |
| 24 | `youeki_cd` | STRING | 用役コード | varchar(10) | 不可 |  |
| 25 | `shokushu_cd` | STRING | 職種コード | varchar(10) | 不可 |  |
| 26 | `keijo_kosu` | NUMERIC | 計上工数 | decimal(5,1) | 不可 |  |
| 27 | `text_item01` | STRING | テキスト項目01 | nvarchar(4000) | 可 |  |
| 28 | `text_item02` | STRING | テキスト項目02 | nvarchar(4000) | 可 |  |
| 29 | `text_item03` | STRING | テキスト項目03 | nvarchar(4000) | 可 |  |
| 30 | `text_item04` | STRING | テキスト項目04 | nvarchar(4000) | 可 |  |
| 31 | `text_item05` | STRING | テキスト項目05 | nvarchar(4000) | 可 |  |
| 32 | `text_item06` | STRING | テキスト項目06 | nvarchar(4000) | 可 |  |
| 33 | `text_item07` | STRING | テキスト項目07 | nvarchar(4000) | 可 |  |
| 34 | `text_item08` | STRING | テキスト項目08 | nvarchar(4000) | 可 |  |
| 35 | `text_item09` | STRING | テキスト項目09 | nvarchar(4000) | 可 |  |
| 36 | `text_item10` | STRING | テキスト項目10 | nvarchar(4000) | 可 |  |
| 37 | `shusei_flg` | STRING | 修正フラグ | varchar(1) | 不可 |  |
| 38 | `shusei_riyu` | STRING | 修正理由 | nvarchar(4000) | 可 |  |
| 39 | `status` | STRING | ステータス | varchar(1) | 不可 |  |
| 40 | `if_status` | STRING | I/Fステータス | varchar(1) | 不可 |  |
| 41 | `shuusei_siji` | STRING | 修正指示内容 | nvarchar(4000) | 可 |  |
| 42 | `shusei_dt` | DATETIME | 修正日時 | datetime | 不可 |  |
| 43 | `shusei_kbn` | STRING | 修正区分 | varchar(1) | 不可 |  |
| 44 | `update_user_id` | STRING | 変更者ユーザID | varchar(7) | 不可 |  |
| 45 | `update_sei_mei` | STRING | 変更者氏名 | nvarchar(262) | 不可 |  |
| 46 | `insert_user` | STRING | 登録ユーザ | nvarchar(10) | 不可 |  |
| 47 | `insert_date` | DATETIME | 登録日時 | datetime | 不可 |  |
| 48 | `update_user` | STRING | 更新ユーザ | nvarchar(10) | 不可 |  |
| 49 | `update_date` | DATETIME | 更新日時 | datetime | 不可 |  |
| 50 | `machine_flg` | STRING | マシン区分 | varchar(1) | 不可 |  |
| 51 | `_batch_id` | STRING | BigQuery取込処理ID | — | 不可 | 管理列（2.3） |
| 52 | `_loaded_at` | TIMESTAMP | Bronze取込日時 | — | 不可 | 管理列（2.3） |
| 53 | `_source_file` | STRING | 取込元ファイル | — | 不可 | 管理列（2.3） |
| 54 | `snapshot_date` | DATE | Bronze取込日 | — | 不可 | 管理列（2.3） |
