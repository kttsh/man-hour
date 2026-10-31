# 更新方式シミュレーションの確認SQL

[更新方式シミュレーションの要求事項](../../docs/planning/update-method-simulation-requirements.md)の4.1節にある、V-01〜V-08の単発確認をまとめたツール。再生を作る前に、[ADR-003](../../docs/adr/adr-003-separate-latest-input-and-approved-actuals.md)の前提が実データで成り立つかを確かめる。

## 使い方

Windowsでは `run-checks.cmd` で全SQLの実行と結果の保存をまとめて行える。追加のインストールは要らない。SSMSで1本ずつ流す場合は、[SSMSで流す場合](#ssmsで流す場合)を参照する。

### 初回の準備

1. コマンドプロンプトでこのフォルダに移動し、`copy .env.example .env` を実行する。
2. `.env` をメモ帳で開き、`MSSQL_SERVER` と `MSSQL_USER` を入れる。`MSSQL_PASSWORD` は空のままにすると、実行のたびに入力を求められる。

`.env` はgitの管理外にしてある。社内共有やAIへ渡すときに、フォルダごと渡さないよう注意する。

### 実行

| やりたいこと | コマンド |
| --- | --- |
| 軽い6本を流す（ダブルクリックでも可） | `run-checks.cmd` |
| 指定したSQLだけ流す（重いものも可） | `run-checks.cmd -Only v01` または `-Only v05,v08` |
| 重い2本も含めて全部流す | `run-checks.cmd -IncludeHeavy` |
| 今日成功済みのSQLをもう一度流す | `run-checks.cmd -Only v01 -Force` |

**実行の順番：** V-01 → V-06 → V-02 → V-03 → V-04 → V-07 → V-05 → V-08 の順に、軽いものから流す。V-05とV-08は既定では流れないので、参照環境の利用が少ない時間帯に `-Only` で流す。V-01は日をまたいでもう一度流す。

要求事項R-18（全行の読取は1日1回まで）のため、今日成功済みのSQLは飛ばす。失敗したSQLは同じ日に流し直せる。1本が失敗しても次のSQLへ進むが、接続できないときは何も流さずに止まる。

### 保存される結果

実行のたびに `results/<実行日時>/` を作る。`results/` もgitの管理外である。

```text
results/20261031_180012/
├── run-log.csv     SQLごとの対象ビュー、抽出条件、開始・終了、秒数、行数、成否、サーバーからのメッセージ
├── v01_r1.csv      V-01の結果1。結果が複数あるSQLは r1、r2、r3 と分かれる
├── v01_r2.csv
└── sql/            実行したSQLのコピー
```

CSVはBOM付きのUTF-8なので、そのままExcelで開ける。`run-log.csv` の `message` には、V-08の進み具合と、上限で打ち切ったときの `budget exceeded` が残る。ログのサーバー名とユーザーIDは `***` に置き換える。

結果を読み、[docs/research/](../../docs/research/)に記録する。AIに渡すときは `results/` の該当フォルダだけを渡す。

### うまくいかないとき

| 症状 | 対処 |
| --- | --- |
| 証明書のエラーで接続できない | SSMSでも「サーバー証明書を信頼する」を有効にしているなら、`MSSQL_TRUST_SERVER_CERTIFICATE=true` にする |
| 暗号化の交渉（handshake）で失敗する | サーバーが古い可能性がある。`MSSQL_ENCRYPT=false` を試す |
| `Timeout expired` で止まる | `MSSQL_COMMAND_TIMEOUT_SEC` を延ばす前に、SQLの期間か `@company` を狭める |
| `run-checks.cmd` が会社のポリシーで止められる | SSMSで流す |

### SSMSで流す場合

1. SSMSで `GEMS_DM_S` に接続し、`sql/` のファイルを開く。
2. 冒頭の `DECLARE` で対象範囲を確認し、ファイル全体を1回実行する。
3. 結果をCSVで保存する。ファイル名は `v02_20261031_1800.csv` のように、ID・日付・時刻を付ける。

## SQLの一覧

| ID | ファイル | 確かめること | 既定の範囲 | 重さ |
| --- | --- | --- | --- | --- |
| V-01 | `v01-freshness.sql` | 参照環境の更新、サーバーの版、権限 | 全期間の最終更新と、2026年4月以降の月別 | 中 |
| V-02 | `v02-status-mix.sql` | 社員日の中のstatus混在 | 2026年4月〜10月 | 中 |
| V-03 | `v03-insert-date-uniformity.sql` | 保存のたびに社員日の全行が書き直されるか | 2026年9月 | 中 |
| V-04 | `v04-oks02-missing-days.sql` | OKS02に行がない社員日の原因 | 2026年9月 | 中 |
| V-05 | `v05-full-row-duplicates.sql` | 全列同一行の件数 | 2026年4月〜10月 | **重い** |
| V-06 | `v06-update-date-by-day.sql` | 更新日の分布と締切の山 | 2026年4月以降 | 中 |
| V-07 | `v07-row-bytes.sql` | 1行の実バイト数 | 2026年9月 | 中 |
| V-08 | `v08-read-timing.sql` | 全行読取の実行時間 | 2026年4月〜10月、上限30分 | **重い** |

重さは見込みで、本物のビューでは測っていない。重いときは、`@company` に会社コードを入れるか、期間を1か月に狭める。

## 結果の読み方

| ID | 見る列 | 読み方 |
| --- | --- | --- |
| V-01 | 結果2の `hours_since_last_update`、結果3の `max_update_date` と `content_checksum` | 2回の実行で変わっていれば更新されている。結果1の版で、使える関数を判断する |
| V-02 | `gate_kind` | `MIXED_PENDING_APPROVED` は、承認済みと承認待ちが1社員日に混ざる社員日。多いと社員日単位のゲートが実績を維持しすぎる。`OTHER_VALUE` は0件の見込み |
| V-03 | 結果2の `save_match`、`row_match` | `ALL_ROWS_AT_LAST_SAVE` が大半なら、差分は社員日の全行で届くとみてよい。`ROWS_EQUAL` が大半なら、OKS10の最後の組のA行数で差分量を見積もれる |
| V-04 | `adopted_kind = ADOPT_A` かつ `oks02 = NO_OKS02` の行 | `ALL_ZERO_HOURS` は0時間で説明がつく。`HAS_HOURS` は要調査で、承認ゲートが実績を消す原因になりうる |
| V-05 | `excess_rows`、`excess_hours` | 1行にまとめたときに減る行数と工数。N32の既知の重複と比べる |
| V-06 | `row_cnt`、`max_rows_same_timestamp` | 2つが近い日は一括更新とみられる。結果2は、作業月からどれだけ後まで更新が続くかを示す |
| V-07 | `row_bytes_upper_avg` | 費用の試算に使う1行のバイト数の上限 |
| V-08 | `seconds_taken` | ツールの分割単位を決める。CSV出力と転送の時間は含まない |

既存の集計との突き合わせ：V-04の会社AAA・2026年9月は、以前の調査で「OKS02だけ行なし」が30社員日だった。当時の採用ルールは見直し前なので、少し違う件数になる可能性がある。

## 入力と出力

- **入力：** `GEMS_DM_S.dbo.V_T_OKS02`、`V_T_OKS07`、`V_T_OKS10`。ビューのSELECT権限だけで動く。
- **出力：** 集計だけ。氏名、自由記述、ユーザID、従業員番号は出さない。ラベルは英数字で、会社コードは出る。
- **データの変更：** しない。V-08だけ、自分のセッションの一時テーブルを使う。

## 動作確認

架空データを入れたSQL Server 2022（Docker）で実行した。ビューのSELECT権限だけのユーザーで、互換性レベル160と110（SQL Server 2012相当）の両方を確認した。各SQLの分岐を通るデータを用意し、結果を期待値と照合した。

本物のビューでは実行していない。実行時間、実データでの型の変換、全43列のGROUP BYが通るかは未確認である。V-05で行サイズのエラーが出たら、対象の期間か会社を狭める。

`run-checks.ps1` は、Windowsでは未確認である。架空データのSQL Server 2022に対し、Linux上のPowerShell 7.4で実行した。全SQLのCSVが直接のクエリ結果と一致すること、記号入りパスワード、パスワードの入力、接続失敗、途中のSQLエラー、タイムアウト、V-08の打ち切り、同日の再実行、値の形式（38桁のdecimal、日付、改行入りの文字列）を確認した。Windows PowerShell 5.1については、構文とコマンドの互換性を静的検査（PSScriptAnalyzer）で確かめただけで、`run-checks.cmd` も実行していない。

SQLファイルと `run-checks.ps1` はBOM付きのUTF-8で保存している。SSMSとWindows PowerShell 5.1で日本語が文字化けしないようにするためである。編集後もBOMを消さない。
