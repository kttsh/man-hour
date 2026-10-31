# 工数システム テーブル仕様書

## ビュー一覧

| No | 論理名 | 物理名 | 列数 |
| --- | --- | --- | --- |
| 1 | 工数データ出力 | `GEMS_DM_S.dbo.V_T_OKS02` | 43 |
| 2 | 締切済工数修正情報 | `GEMS_DM_S.dbo.V_T_OKS07` | 66 |
| 3 | 変更履歴情報 | `GEMS_DM_S.dbo.V_T_OKS10` | 50 |

凡例

- **桁数**: 文字列は文字数、decimal は「精度,スケール」
- **バイト数**: nvarchar は文字数×2。decimal(5,1) は 5、datetime と bigint は 8
- **必須**: NOT NULL の列に「○」

---

## 工数データ出力（V_T_OKS02）

| No | 論理項目名 | 物理項目名 | 論理データ型 | 物理データ型 | 桁数 | バイト数 | 必須 | 説明 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 会社コード | company_cd | 文字列 | nvarchar | 3 | 6 | ○ | OpenGIM・会社コード |
| 2 | 計上日付 | keijo_date | 文字列 | varchar | 8 | 8 | ○ | yyyymmdd |
| 3 | ユーザID | user_id | 文字列 | varchar | 7 | 7 | ○ | OpenGIM・ユーザID |
| 4 | 従業員番号 | mhi_emp_no | 文字列 | varchar | 6 | 6 | ○ | OpenGIM・従業員番号 |
| 5 | 氏名 | sei_mei | 文字列 | nvarchar | 262 | 524 | ○ | OpenGIM・氏名・姓＋氏名・名 |
| 6 | 所属コード | shozoku_cd | 文字列 | varchar | 12 | 12 | ○ |  |
| 7 | 所属名称 | shozoku_name | 文字列 | nvarchar | 905 | 1810 | ○ | OpenGIM・事業所名（略称）＋総括部名（略称）＋部名（略称）＋課名（略称）＋係名（略称）＋班名（略称） |
| 8 | 賃金計上先原価センタ | keijo_genka_center_cd | 文字列 | nvarchar | 10 | 20 | ○ |  |
| 9 | 賃金計上先原価センタ名称 | keijo_genka_center_name | 文字列 | nvarchar | 40 | 80 | ○ |  |
| 10 | WBS要素 | wbs_cd | 文字列 | nvarchar | 24 | 48 | ○ | S4で決まっているもの |
| 11 | WBS名称 | wbs_name | 文字列 | nvarchar | 40 | 80 | ○ | S4で決まっているもの |
| 12 | OPA | opa_cd | 文字列 | nvarchar | 12 | 24 | ○ | S4で決まっているもの |
| 13 | OPA名称 | opa_name | 文字列 | nvarchar | 40 | 80 | ○ | S4で決まっているもの |
| 14 | 原価センタ | genka_center_cd | 文字列 | nvarchar | 10 | 20 | ○ | S4で決まっているもの |
| 15 | 原価センタ名称 | genka_center_name | 文字列 | nvarchar | 40 | 80 | ○ | S4で決まっているもの |
| 16 | 活動タイプ | katudo_type | 文字列 | varchar | 6 | 6 | ○ | S4で決まっているもの |
| 17 | 活動タイプ名称 | katudo_type_name | 文字列 | nvarchar | 20 | 40 | ○ | S4で決まっているもの |
| 18 | MHI WBS | mhi_wbs | 文字列 | varchar | 36 | 36 | ○ |  |
| 19 | MHI WBS 名称 | mhi_wbs_name | 文字列 | nvarchar | 40 | 80 | ○ |  |
| 20 | 拠点別分析キー | kyotenbetu_bunseki_key | 文字列 | varchar | 8000 | 8000 |  |  |
| 21 | 用役コード | youeki_cd | 文字列 | varchar | 10 | 10 | ○ |  |
| 22 | 職種コード | shokushu_cd | 文字列 | varchar | 10 | 10 | ○ |  |
| 23 | 計上工数 | keijo_kosu | 数値 | decimal | 5,1 | 5 | ○ |  |
| 24 | テキスト項目01 | text_item01 | 文字列 | nvarchar | 4000 | 8000 |  |  |
| 25 | テキスト項目02 | text_item02 | 文字列 | nvarchar | 4000 | 8000 |  |  |
| 26 | テキスト項目03 | text_item03 | 文字列 | nvarchar | 4000 | 8000 |  |  |
| 27 | テキスト項目04 | text_item04 | 文字列 | nvarchar | 4000 | 8000 |  |  |
| 28 | テキスト項目05 | text_item05 | 文字列 | nvarchar | 4000 | 8000 |  |  |
| 29 | テキスト項目06 | text_item06 | 文字列 | nvarchar | 4000 | 8000 |  |  |
| 30 | テキスト項目07 | text_item07 | 文字列 | nvarchar | 4000 | 8000 |  |  |
| 31 | テキスト項目08 | text_item08 | 文字列 | nvarchar | 4000 | 8000 |  |  |
| 32 | テキスト項目09 | text_item09 | 文字列 | nvarchar | 4000 | 8000 |  |  |
| 33 | テキスト項目10 | text_item10 | 文字列 | nvarchar | 4000 | 8000 |  |  |
| 34 | 修正フラグ | shusei_flg | 文字列 | varchar | 1 | 1 | ○ |  |
| 35 | 修正理由 | shusei_riyu | 文字列 | nvarchar | 4000 | 8000 |  |  |
| 36 | ステータス | status | 文字列 | varchar | 1 | 1 | ○ |  |
| 37 | I/Fステータス | if_status | 文字列 | varchar | 1 | 1 | ○ |  |
| 38 | 修正指示内容 | shuusei_siji | 文字列 | nvarchar | 4000 | 8000 |  |  |
| 39 | 登録ユーザ | insert_user | 文字列 | nvarchar | 10 | 20 | ○ |  |
| 40 | 登録日時 | insert_date | 日付 | datetime | - | 8 | ○ |  |
| 41 | 更新ユーザ | update_user | 文字列 | nvarchar | 10 | 20 | ○ |  |
| 42 | 更新日時 | update_date | 日付 | datetime | - | 8 | ○ |  |
| 43 | マシン区分 | machine_flg | 文字列 | varchar | 1 | 1 | ○ |  |

---

## 締切済工数修正情報（V_T_OKS07）

| No | 論理項目名 | 物理項目名 | 論理データ型 | 物理データ型 | 桁数 | バイト数 | 必須 | 説明 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 会社コード | company_cd | 文字列 | nvarchar | 3 | 6 | ○ | OpenGIM・会社コード |
| 2 | 計上日付 | keijo_date | 文字列 | varchar | 8 | 8 | ○ | yyyymmdd |
| 3 | 所属コード | shozoku_cd | 文字列 | varchar | 12 | 12 | ○ |  |
| 4 | 所属 | shozoku_name | 文字列 | nvarchar | 905 | 1810 | ○ | OpenGIM・事業所名（略称）＋総括部名（略称）＋部名（略称）＋課名（略称）＋係名（略称）＋班名（略称） |
| 5 | 従業員番号 | mhi_emp_no | 文字列 | varchar | 6 | 6 | ○ | OpenGIM・従業員番号 |
| 6 | マシン区分 | machine_flg | 文字列 | varchar | 1 | 1 | ○ |  |
| 7 | ユーザID | user_id | 文字列 | varchar | 7 | 7 | ○ | OpenGIM・ユーザID |
| 8 | ユーザ名 | sei_mei | 文字列 | nvarchar | 262 | 524 | ○ | OpenGIM・氏名・姓＋氏名・名 |
| 9 | 修正区分 | correction_kbn | 文字列 | nvarchar | 1 | 2 | ○ |  |
| 10 | 修正回数 | correction_num | 文字列 | nvarchar | 2 | 4 | ○ |  |
| 11 | 賃金計上先原価センタ | keijo_genka_center_cd | 文字列 | nvarchar | 10 | 20 | ○ |  |
| 12 | 賃金計上先原価センタ名称 | keijo_genka_center_name | 文字列 | nvarchar | 40 | 80 | ○ |  |
| 13 | WBS要素 | wbs_cd | 文字列 | nvarchar | 24 | 48 | ○ |  |
| 14 | WBS名称 | wbs_name | 文字列 | nvarchar | 40 | 80 | ○ |  |
| 15 | OthersWBS | others_wbs | 文字列 | nvarchar | 24 | 48 | ○ |  |
| 16 | OPA | opa_cd | 文字列 | nvarchar | 12 | 24 | ○ |  |
| 17 | OPA名称 | opa_name | 文字列 | nvarchar | 40 | 80 | ○ |  |
| 18 | 参照指図 | sashizu | 文字列 | nvarchar | 12 | 24 | ○ |  |
| 19 | 原価センタ | genka_center_cd | 文字列 | nvarchar | 10 | 20 | ○ |  |
| 20 | 原価センタ名称 | genka_center_name | 文字列 | nvarchar | 40 | 80 | ○ |  |
| 21 | 活動タイプ | katudo_type | 文字列 | varchar | 6 | 6 | ○ |  |
| 22 | 活動タイプ名称 | katudo_type_name | 文字列 | nvarchar | 20 | 40 | ○ |  |
| 23 | MHI WBS | mhi_wbs | 文字列 | varchar | 36 | 36 | ○ |  |
| 24 | MHI WBS 名称 | mhi_wbs_name | 文字列 | nvarchar | 40 | 80 | ○ |  |
| 25 | 拠点別分析キー | kyotenbetu_bunseki_key | 文字列 | varchar | 8000 | 8000 |  |  |
| 26 | 用役コード | youeki_cd | 文字列 | varchar | 10 | 10 | ○ |  |
| 27 | 職種コード | shokushu_cd | 文字列 | varchar | 10 | 10 | ○ |  |
| 28 | 計上工数 | keijo_kosu | 数値 | decimal | 5,1 | 5 |  |  |
| 29 | 修正前工数 | shusei_mae_kosu | 数値 | decimal | 5,1 | 5 |  |  |
| 30 | 修正ユーザ | correction_user_id | 文字列 | nvarchar | 10 | 20 | ○ |  |
| 31 | 修正ユーザ名 | correction_user_name | 文字列 | nvarchar | 262 | 524 | ○ |  |
| 32 | 修正登録日 | correction_date | 日付 | datetime | - | 8 | ○ |  |
| 33 | 承認ユーザ | shonin_user_id | 文字列 | nvarchar | 10 | 20 |  |  |
| 34 | 承認ユーザ名 | shonin_user_name | 文字列 | nvarchar | 262 | 524 |  |  |
| 35 | 承認登録日 | shonin_date | 日付 | datetime | - | 8 |  |  |
| 36 | 経理承認ユーザ | keiri_shonin_user_id | 文字列 | nvarchar | 10 | 20 |  |  |
| 37 | 経理承認ユーザ名 | keiri_shonin_user_name | 文字列 | nvarchar | 262 | 524 |  |  |
| 38 | 経理承認登録日 | keiri_shonin_date | 日付 | datetime | - | 8 |  |  |
| 39 | 確定ユーザ | kakutei_user_id | 文字列 | nvarchar | 10 | 20 |  |  |
| 40 | 確定ユーザ名 | kakutei_user_name | 文字列 | nvarchar | 262 | 524 |  |  |
| 41 | 確定登録日 | kakutei_date | 日付 | datetime | - | 8 |  |  |
| 42 | 締切ユーザ | simekiri_user_id | 文字列 | nvarchar | 10 | 20 |  |  |
| 43 | 締切ユーザ名 | simekiri_user_name | 文字列 | nvarchar | 262 | 524 |  |  |
| 44 | 締切登録日 | simekiri_date | 日付 | datetime | - | 8 |  |  |
| 45 | 経理接続ユーザ | keiri_setuzoku_user_id | 文字列 | nvarchar | 10 | 20 |  |  |
| 46 | 経理接続ユーザ名 | keiri_setuzoku_user_name | 文字列 | nvarchar | 262 | 524 |  |  |
| 47 | 経理接続登録日 | keiri_setuzoku_date | 日付 | datetime | - | 8 |  |  |
| 48 | テキスト項目01 | text_item01 | 文字列 | nvarchar | 4000 | 8000 |  |  |
| 49 | テキスト項目02 | text_item02 | 文字列 | nvarchar | 4000 | 8000 |  |  |
| 50 | テキスト項目03 | text_item03 | 文字列 | nvarchar | 4000 | 8000 |  |  |
| 51 | テキスト項目04 | text_item04 | 文字列 | nvarchar | 4000 | 8000 |  |  |
| 52 | テキスト項目05 | text_item05 | 文字列 | nvarchar | 4000 | 8000 |  |  |
| 53 | テキスト項目06 | text_item06 | 文字列 | nvarchar | 4000 | 8000 |  |  |
| 54 | テキスト項目07 | text_item07 | 文字列 | nvarchar | 4000 | 8000 |  |  |
| 55 | テキスト項目08 | text_item08 | 文字列 | nvarchar | 4000 | 8000 |  |  |
| 56 | テキスト項目09 | text_item09 | 文字列 | nvarchar | 4000 | 8000 |  |  |
| 57 | テキスト項目10 | text_item10 | 文字列 | nvarchar | 4000 | 8000 |  |  |
| 58 | 修正フラグ | shusei_flg | 文字列 | varchar | 1 | 1 | ○ |  |
| 59 | 修正理由 | shusei_riyu | 文字列 | nvarchar | 4000 | 8000 |  |  |
| 60 | ステータス | status | 文字列 | varchar | 1 | 1 | ○ |  |
| 61 | I/Fステータス | if_status | 文字列 | varchar | 1 | 1 | ○ |  |
| 62 | 修正指示内容 | shuusei_siji | 文字列 | nvarchar | 4000 | 8000 |  |  |
| 63 | 登録ユーザ | insert_user | 文字列 | nvarchar | 10 | 20 | ○ |  |
| 64 | 登録日時 | insert_date | 日付 | datetime | - | 8 | ○ |  |
| 65 | 更新ユーザ | update_user | 文字列 | nvarchar | 10 | 20 | ○ |  |
| 66 | 更新日時 | update_date | 日付 | datetime | - | 8 | ○ |  |

---

## 変更履歴情報（V_T_OKS10）

| No | 論理項目名 | 物理項目名 | 論理データ型 | 物理データ型 | 桁数 | バイト数 | 必須 | 説明 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 変更履歴ID | hnko_rireki_id | 数値 | bigint | - | 8 | ○ |  |
| 2 | 会社コード | company_cd | 文字列 | nvarchar | 3 | 6 | ○ | OpenGIM・会社コード |
| 3 | 計上日付 | keijo_date | 文字列 | varchar | 8 | 8 | ○ | yyyymmdd |
| 4 | 所属コード | shozoku_cd | 文字列 | varchar | 12 | 12 | ○ |  |
| 5 | 所属 | shozoku_name | 文字列 | nvarchar | 905 | 1810 | ○ | OpenGIM・事業所名（略称）＋総括部名（略称）＋部名（略称）＋課名（略称）＋係名（略称）＋班名（略称） |
| 6 | 従業員番号 | mhi_emp_no | 文字列 | varchar | 6 | 6 | ○ | OpenGIM・従業員番号 |
| 7 | ユーザID | user_id | 文字列 | varchar | 7 | 7 | ○ | OpenGIM・ユーザID |
| 8 | 氏名 | sei_mei | 文字列 | nvarchar | 262 | 524 | ○ | OpenGIM・氏名・姓＋氏名・名 |
| 9 | 賃金計上先原価センタ | keijo_genka_center_cd | 文字列 | nvarchar | 10 | 20 | ○ |  |
| 10 | 賃金計上先原価センタ名称 | keijo_genka_center_name | 文字列 | nvarchar | 40 | 80 | ○ |  |
| 11 | WBS要素 | wbs_cd | 文字列 | nvarchar | 24 | 48 | ○ |  |
| 12 | WBS名称 | wbs_name | 文字列 | nvarchar | 40 | 80 | ○ |  |
| 13 | OthersWBS | others_wbs | 文字列 | nvarchar | 24 | 48 | ○ |  |
| 14 | OPA | opa_cd | 文字列 | nvarchar | 12 | 24 | ○ |  |
| 15 | OPA名称 | opa_name | 文字列 | nvarchar | 40 | 80 | ○ |  |
| 16 | 参照指図 | sashizu | 文字列 | nvarchar | 12 | 24 | ○ |  |
| 17 | 原価センタ | genka_center_cd | 文字列 | nvarchar | 10 | 20 | ○ |  |
| 18 | 原価センタ名称 | genka_center_name | 文字列 | nvarchar | 40 | 80 | ○ |  |
| 19 | 活動タイプ | katudo_type | 文字列 | varchar | 6 | 6 | ○ |  |
| 20 | 活動タイプ名称 | katudo_type_name | 文字列 | nvarchar | 20 | 40 | ○ |  |
| 21 | MHI WBS | mhi_wbs | 文字列 | varchar | 36 | 36 | ○ |  |
| 22 | MHI WBS 名称 | mhi_wbs_name | 文字列 | nvarchar | 40 | 80 | ○ |  |
| 23 | 拠点別分析キー | kyotenbetu_bunseki_key | 文字列 | varchar | 8000 | 8000 |  |  |
| 24 | 用役コード | youeki_cd | 文字列 | varchar | 10 | 10 | ○ |  |
| 25 | 職種コード | shokushu_cd | 文字列 | varchar | 10 | 10 | ○ |  |
| 26 | 計上工数 | keijo_kosu | 数値 | decimal | 5,1 | 5 | ○ |  |
| 27 | テキスト項目01 | text_item01 | 文字列 | nvarchar | 4000 | 8000 |  |  |
| 28 | テキスト項目02 | text_item02 | 文字列 | nvarchar | 4000 | 8000 |  |  |
| 29 | テキスト項目03 | text_item03 | 文字列 | nvarchar | 4000 | 8000 |  |  |
| 30 | テキスト項目04 | text_item04 | 文字列 | nvarchar | 4000 | 8000 |  |  |
| 31 | テキスト項目05 | text_item05 | 文字列 | nvarchar | 4000 | 8000 |  |  |
| 32 | テキスト項目06 | text_item06 | 文字列 | nvarchar | 4000 | 8000 |  |  |
| 33 | テキスト項目07 | text_item07 | 文字列 | nvarchar | 4000 | 8000 |  |  |
| 34 | テキスト項目08 | text_item08 | 文字列 | nvarchar | 4000 | 8000 |  |  |
| 35 | テキスト項目09 | text_item09 | 文字列 | nvarchar | 4000 | 8000 |  |  |
| 36 | テキスト項目10 | text_item10 | 文字列 | nvarchar | 4000 | 8000 |  |  |
| 37 | 修正フラグ | shusei_flg | 文字列 | varchar | 1 | 1 | ○ |  |
| 38 | 修正理由 | shusei_riyu | 文字列 | nvarchar | 4000 | 8000 |  |  |
| 39 | ステータス | status | 文字列 | varchar | 1 | 1 | ○ |  |
| 40 | I/Fステータス | if_status | 文字列 | varchar | 1 | 1 | ○ |  |
| 41 | 修正指示内容 | shuusei_siji | 文字列 | nvarchar | 4000 | 8000 |  |  |
| 42 | 修正日時 | shusei_dt | 日付 | datetime | - | 8 | ○ |  |
| 43 | 修正区分 | shusei_kbn | 文字列 | varchar | 1 | 1 | ○ |  |
| 44 | 変更者ユーザID | update_user_id | 文字列 | varchar | 7 | 7 | ○ |  |
| 45 | 変更者氏名 | update_sei_mei | 文字列 | nvarchar | 262 | 524 | ○ |  |
| 46 | 登録ユーザ | insert_user | 文字列 | nvarchar | 10 | 20 | ○ |  |
| 47 | 登録日時 | insert_date | 日付 | datetime | - | 8 | ○ |  |
| 48 | 更新ユーザ | update_user | 文字列 | nvarchar | 10 | 20 | ○ |  |
| 49 | 更新日時 | update_date | 日付 | datetime | - | 8 | ○ |  |
| 50 | マシン区分 | machine_flg | 文字列 | varchar | 1 | 1 | ○ |  |
