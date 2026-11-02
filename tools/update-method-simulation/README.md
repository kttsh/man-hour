# 更新方式シミュレーションの確認SQL

[更新方式シミュレーションの要求事項](../../docs/planning/update-method-simulation-requirements.md)の4.1節にある、V-01〜V-08の単発確認をまとめたツール。再生を作る前に、[ADR-003](../../docs/adr/adr-003-separate-latest-input-and-approved-actuals.md)の前提が実データで成り立つかを確かめる。

V-09〜V-17は、[V-01〜V-08の結果](../../docs/research/2026-11-02-update-method-checks-report.html)で残った論点を追う追加の確認である。

## 使い方

Windowsでは `run-checks.cmd` で全SQLの実行と結果の保存をまとめて行える。追加のインストールは要らない。SSMSで1本ずつ流す場合は、[SSMSで流す場合](#ssmsで流す場合)を参照する。

### 初回の準備

1. コマンドプロンプトでこのフォルダに移動し、`copy .env.example .env` を実行する。
2. `.env` をメモ帳で開き、`MSSQL_SERVER` と `MSSQL_USER` を入れる。`MSSQL_PASSWORD` は空のままにすると、実行のたびに入力を求められる。

`.env` はgitの管理外にしてある。社内共有やAIへ渡すときに、フォルダごと渡さないよう注意する。

### 実行

| やりたいこと | コマンド |
| --- | --- |
| V-01〜V-08の軽い6本を流す（ダブルクリックでも可） | `run-checks.cmd` |
| 追加のV-09〜V-17だけを流す（重いものも含む） | `run-checks.cmd -Extra` |
| 指定したSQLだけ流す（重いものも可） | `run-checks.cmd -Only v01` または `-Only v05,v08` |
| V-01〜V-08を重い2本も含めて流す | `run-checks.cmd -IncludeHeavy` |
| 今日成功済みのSQLをもう一度流す | `run-checks.cmd -Only v01 -Force` または `-Extra -Force` |

`-Only` と `-Extra` は同時に指定できない。

**実行の順番：** V-01 → V-06 → V-02 → V-03 → V-04 → V-07 → V-05 → V-08 の順に、軽いものから流す。V-05とV-08は既定では流れないので、参照環境の利用が少ない時間帯に `-Only` で流す。V-01は日をまたいでもう一度流す。

`-Extra` は V-14 → V-09 → V-12 → V-15 → V-16 → V-11 → V-13 → V-17 → V-10 の順に流す。重いV-17とV-10を最後にしたので、そこで止まっても他の結果は残る。

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
| ログに `Null value is eliminated by an aggregate` が出る | 集計でNULLを読み飛ばした通知で、結果には影響しない |

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
| V-09 | `v09-oks07-on-oks02.sql` | OKS07の修正がOKS02の明細に9列で当たるか（ADR-003の前提2） | 全期間 | 中 |
| V-10 | `v10-line-match.sql` | OKS02とOKS10の採用行が明細単位で一致するか（R-08） | 2026年4月〜8月 | **重い** |
| V-11 | `v11-oks02-missing-detail.sql` | OKS02に行がない社員日の内訳（V-04の続き） | 2026年4月〜9月 | 中 |
| V-12 | `v12-last-save-exceptions.sql` | OKS02と最後の保存が合わない社員日（V-03の続き） | 2026年9月 | 中 |
| V-13 | `v13-oks10-update-date.sql` | OKS10のupdate_dateが承認時刻の代わりになるか（R-02） | 2026年4月〜9月 | 中 |
| V-14 | `v14-oks07-lag-status.sql` | OKS07の遡りと、statusと承認日時の関係 | 全期間 | 軽い |
| V-15 | `v15-company-shortfall.sql` | 会社の社員日の不足の原因（既定はB46の8月と9月） | 1社 | 中 |
| V-16 | `v16-close-unmoved-rows.sql` | 締切で動かない約0.25%の行（R-04） | 2026年4月〜8月 | 中 |
| V-17 | `v17-key-collation.sql` | キー列の照合順序と空白 | 2026年4月〜9月 | **重い** |

重さは見込みで、本物のビューでは測っていない。重いときは、`@company` に会社コードを入れるか、期間を1か月に狭める。V-10は `@company='AAA'`、`@from='20260801'`、`@to='20260901'` で試してから全社に広げる。ファイルを書き換えて試した後に同じ日に全社で流すときは、`-Force` を付ける。

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
| V-09 | `match_kind`、`pre_check`、`post_check` | `MATCH9` が修正の当たり先。`KEIJO_GC_DIFF`、`YOUEKI_DIFF`、`HIT_MULTI_ROW`、`PRE_VALUE_NO_ROW`、`PRE_DIFF` が多ければ前提2が崩れる。`NO_BASE_7COL` は修正前がNULLか0なら明細の追加で、正常とみる |
| V-10 | 結果1の `day_kind`、結果2の `diff_cols` | 締切済みの月は `ALL_MATCH` が大半の見込み。`KEY_DIFF_SAME_TOTAL` は行数と合計では見えなかったずれ。OKS02を正解の代わりにできない社員日になる |
| V-11 | `adopted_kind = ADOPT_A` かつ `adopted_hours_kind = HAS_HOURS` の行の `latest_kind` | `PENDING_A_ZERO`、`B_ONLY_PENDING` はADR-003が受け入れた範囲。`APPROVED_A_HOURS` はゲートが実績を消す。4〜8月に残れば承認待ちでは説明できない |
| V-12 | `save_match`、`update_kind`、`gap_bucket` | `INSERT_BEFORE_LAST_SAVE` で `SAVE_BEFORE_OKS02_CUT` なら、時間差では説明できず、OKS02が最新の入力ではない。`UPDATE_BEFORE_LAST_SAVE` は案2の差分に載らない。`OKS02_MORE` は全行書き直しの反例の候補 |
| V-13 | 結果1の `next_save_kind`、`window_kind`、結果2の遅れの分布 | `AFTER_NEXT_SAVE` は次の保存の後に書き換えられた組で、承認時刻とは言えない。`in_close_window` が多いと、R-02は維持を多く数える |
| V-14 | 結果1の `months_back`、結果2のstatus 1〜3の `has_shonin` | `has_shonin = 1` でstatus 1〜3の行があれば、承認済みの修正が確定まで重ならない。結果3は締切が過去月の修正を書き換える量を示す |
| V-15 | 結果3の `user_group`、`last_day`、結果4 | `IN_BOTH` の `last_day` が月の途中に集まれば入力の遅れ。`ONLY_BASE` や特定の所属の消失が多ければ、人や組織の変化 |
| V-16 | 結果1の `moved_kind`、`status`、結果2の `user_kind` | `UNMOVED` の会社とstatusを見る。`ALL_UNMOVED` が多ければ、人の単位で締切の対象外になっている |
| V-17 | 結果3の `kinds_normalized`、`kinds_db_collation`、`rows_collation_merged` | `kinds_normalized` のほうが多い列は、SQL Serverでの一致件数がDuckDB、BigQuery、HASHBYTESでは再現しない。結果1と結果2は照合順序そのもの |

既存の集計との突き合わせ：V-04の会社AAA・2026年9月は、以前の調査で「OKS02だけ行なし」が30社員日だった。当時の採用ルールは見直し前なので、少し違う件数になる可能性がある。

V-09〜V-17は、実行時に参照環境が同じ断面なら、2026-11-02の結果と次の値が合うはずである。

| ID | 合うはずの値 |
| --- | --- |
| V-11 | 2026年9月の `ADOPT_A` × `HAS_HOURS` の合計が42社員日・346.0時間（V-04） |
| V-12 | `INSERT_BEFORE_LAST_SAVE` が121社員日、`ALL_ROWS_AT_LAST_SAVE` × `OKS02_MORE` が102社員日、`INSERT_AFTER_LAST_SAVE` が39,276社員日（V-03） |
| V-16 | `UNMOVED` の行数が4月から順に1,071、917、1,253、1,197、979行（V-06） |

## 入力と出力

- **入力：** `GEMS_DM_S.dbo.V_T_OKS02`、`V_T_OKS07`、`V_T_OKS10`。ビューのSELECT権限だけで動く。
- **出力：** 集計だけ。氏名、自由記述、ユーザID、従業員番号は出さない。ラベルは英数字で、会社コードは出る。V-15の所属コードはハッシュで出す。
- **データの変更：** しない。V-08、V-09、V-10、V-13は、自分のセッションの一時テーブルを使う。

## 動作確認

架空データを入れたSQL Server 2022（Docker）で実行した。ビューのSELECT権限だけのユーザーで、互換性レベル160と110（SQL Server 2012相当）の両方を確認した。各SQLの分岐を通るデータを用意し、結果を期待値と照合した。

本物のビューでは実行していない。実行時間、実データでの型の変換、全43列のGROUP BYが通るかは未確認である。V-05で行サイズのエラーが出たら、対象の期間か会社を狭める。

V-09〜V-17も架空データのSQL Server 2022（Docker）で確認した。ビューのSELECT権限だけのユーザーで、各分岐を通るデータを用意し、結果を手計算の期待値と照合した。照合順序は `Japanese_CI_AS` と `SQL_Latin1_General_CP1_CI_AS`、互換性レベルは150と110で実行し、V-17の照合順序の表示を除いて結果は同じだった。V-09、V-10、V-13は同じセッションで2回流せることも確認した。本物のビューでは実行していないので、実行時間と実データでの型の変換は未確認である。

`-Extra` の選択は、既定の実行、`-IncludeHeavy`、`-Only`、`-Force`、同じ日の再実行、`-Only` との同時指定の組み合わせを、架空データのSQL Server 2022に対してLinux上のPowerShell 7.4で確認した。

`run-checks.ps1` は、Windowsでは未確認である。架空データのSQL Server 2022に対し、Linux上のPowerShell 7.4で実行した。全SQLのCSVが直接のクエリ結果と一致すること、記号入りパスワード、パスワードの入力、接続失敗、途中のSQLエラー、タイムアウト、V-08の打ち切り、同日の再実行、値の形式（38桁のdecimal、日付、改行入りの文字列）を確認した。Windows PowerShell 5.1については、構文とコマンドの互換性を静的検査（PSScriptAnalyzer）で確かめただけで、`run-checks.cmd` も実行していない。

SQLファイルと `run-checks.ps1` はBOM付きのUTF-8で保存している。SSMSとWindows PowerShell 5.1で日本語が文字化けしないようにするためである。編集後もBOMを消さない。
