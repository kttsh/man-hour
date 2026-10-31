# 工数 Silver テーブル仕様書

> [!NOTE]
> 論理モデル草案（2026年10月29日、2026-10-28までの決定を反映）。方針・理由は [docs/spec/silver/concept.md](concept.md)、未確定事項はconceptの5節。dimensionの物理キー、全列・変換式・SQLは未確定。DDL・SQLの実装と動作検証は未実施。

入力：[docs/spec/bronze/table.md](../bronze/table.md)（bronze.oks10・oks07。oks02は照合用）

## 1. テーブル構成（候補）

| 表名案 | 種別 | 1行の意味 | 未確定 |
| --- | --- | --- | --- |
| fact_work_actual | fact | 承認済み最新状態の入力明細1件（0時間は除外） | 全列定義、例外の記録方法 |
| dim_date | dimension | 暦日1日 | — |
| dim_employee | dimension | company_cd＋user_idで識別する社員（設備の行も含め、machine_flgで区別） | 属性の配置、物理キー |
| dim_organization | dimension候補 | 所属コード1件（履歴なし） | 表を作るか |
| dim_charge_destination | dimension候補 | 計上先1件（WBS・OPA・原価センタを種別で区別） | 表を作るか |
| dim_activity_type | dimension | 活動タイプ1件 | コードの識別範囲 |
| dim_analysis_key | dimension | 拠点別分析キー1件（空欄は「未設定」） | 「未設定」の物理キー |

MHI WBS・職種はfactの列として持つ（dim_mhi_wbs・dim_job_typeは作らない）。

## 2. 共通仕様

| 対象 | ルール |
| --- | --- |
| 物理設計 | プロジェクト・データセット・リージョン、パーティション、命名、権限はすべて未確定 |
| 入力の追跡 | 実績構築に使ったBronzeの取込処理IDと元ファイルを追跡できるようにする |
| 作業日 | 各Bronzeのkeijo_date（STRING・yyyymmdd）をDATEへ変換する（変換できない行は現データ0件） |
| コード・名称 | 元の値のまま持つ。照合キー・IDの計算時だけ、NULL・空文字・空白のみを空文字にそろえ、前後の空白を除く |
| 工数 | NULLを0にしない |
| dimension参照 | 参照先が1行に定まることを検査する。参照できなくても明細と元コードを残し、名称不明として扱う。複数見つかった場合は任意に選ばず原因を確認する |

## 3. fact_work_actual

### 3.1 粒度とキー

- **粒度**：社員日（company_cd＋user_id＋keijo_date）＋照合キー9列（wbs_cd・opa_cd・genka_center_cd・katudo_type・kyotenbetu_bunseki_key・mhi_wbs・shokushu_cd・keijo_genka_center_cd・youeki_cd）。
- **主キー**：社員日＋9列＋連番のハッシュ値（SHA-256など）。連結の書式とハッシュ関数は詳細設計で定義する。
- **連番**：同じ照合キーの明細が2行以上あるときだけ使う。並び順はinsert_date → keijo_kosu → テキスト項目。それでも区別できなければ例外とする。
- 工数だけが変わった明細は同じID、計上先を付け替えた明細は新しいIDになる。
- 同じ照合キーの明細が複数あれば、合算せず別行として残す（会社AAA全期間で13キー・26行）。

### 3.2 列（候補）

| 列（名前は仮） | 型案 | 内容 |
| --- | --- | --- |
| actual_detail_key | STRING | 主キー（3.1のハッシュ値） |
| key_version | INT64 | IDの作り方のバージョン |
| detail_seq | INT64 | 同じ照合キーの中の連番（通常は1） |
| work_date | DATE | keijo_dateをDATE化。dim_dateを参照 |
| employee_key | 未確定 | dim_employeeを参照。mhi_emp_noは作業日当時の値を保持 |
| 所属コード・所属名 | 元の型 | 採用した行（OKS10のA行またはOKS07の行）の値をそのまま持つ |
| 計上先コード・名称 | 元の型 | wbs_cd・opa_cd・genka_center_cdと各名称。採用した行の値のまま。集計はコードで行う |
| activity_type_key | 未確定 | katudo_typeでdim_activity_typeを参照 |
| analysis_key | 未確定 | kyotenbetu_bunseki_keyでdim_analysis_keyを参照 |
| 作業分類の元の値 | 元の型 | text_item01（分類名の候補）、text_item02（識別情報の候補）、text_item03〜10（補足）を削らずに保持 |
| MHI WBS・職種・賃金計上先原価センタ・用役 | 元の型 | mhi_wbs・shokushu_cd（名称も）、keijo_genka_center_cd・youeki_cd |
| actual_hours | NUMERIC | 採用した工数（時間単位） |
| machine_flg | 元の型 | 設備の行の区別 |
| 構築元・確認状態 | 未確定 | 使用した取込処理・ファイル、参照不明などの追跡用 |

### 3.3 作成手順（方針案）

1. **対象の社員日を選ぶ**：前回のSilver処理より後に取り込んだOKS10・OKS07の行（_loaded_atで判断）に出てくる社員日。Bronzeにたまった全行から作り直す。
2. **入力を整理する**：OKS10は同じ取得回の全列同一行を1行にまとめ（元の行数を残す）、取得回をまたぐ同じ履歴IDは最後に受け取った状態を使う。OKS07は社員日＋9列＋correction_numごとに最後に受け取った行を使う。
3. **締切前の承認済み状態（OKS10）**：同じ社員日・同じshusei_dtの行を1組とし、新しい組から判定する。
   - A行がすべてstatus 4〜7 → そのA行を採用
   - A行にstatus 1〜3がある → 承認待ちとして前の組へ（A1＋B4は前の承認済みの組を採用）
   - A行がなく、B行がstatus 4〜7 → 削除の承認済みとして実績なし
   - A行がなく、B行がstatus 1〜3 → 前の組へ
   - 承認済みの組がない → 実績なし
   - 組の中でstatusが混在 → 承認待ちとして読み飛ばし、例外として記録
4. **締切後の修正（OKS07）**：status 4〜7の修正をcorrection_numの小さい順に、照合キー9列でkeijo_kosuに置換・追加する。status 1〜3の修正は読み飛ばす。複数明細に当たる修正は、同じキーの行をすべて修正後の1行に置き換え、例外として記録する。
5. **0時間を除外する**（NULLは0とみなさない）。
6. **IDを計算し、dimensionを参照する**。結合前後の件数・工数と、参照先の一意性を検査する。
7. **社員日まるごと一度に置き換える**。結果が0行ならその社員日の行はすべて消える。明細IDで結合する下流の表も社員日単位で作り直す。
8. **処理済みの印**（今回使った_loaded_atの最大値）を記録し、次回の手順1に使う。

一度に入れ替える方法、順位式とSQLは詳細設計で定義する。

### 3.4 検査

| 検査 | 期待結果 | 状況 |
| --- | --- | --- |
| PKの一意性 | 粒度どおりに一意 | 設計待ち |
| dimension参照 | 参照先の欠落・重複を検知 | 設計待ち |
| 結合前後の件数・工数 | 意図しない増減がない | 設計待ち |
| 二重計上 | ビュー・取得回・修正前後で同じ実績を重ねて加算しない | 設計待ち |
| 例外の件数 | 組内status混在、承認前の修正をはさむ場合、同じ照合キーの複数明細、連番で区別できない明細、複数明細に当たる修正を件数で監視 | 記録先・形式は未確定 |

## 4. 詳細定義を追加するとき

各テーブルの全列定義は、取得元との対応を確定した後、次の項目を記載する：1行の意味、行を分ける条件、入力Bronze、PK（保証と検証結果を区別）、参照dimension、メジャーの単位・加算性、採用条件、更新・取消・遡及修正、パーティション、列定義（列名・型・NULL可否・PK／FK・入力列・変換式）、作成手順、固有の検査。
