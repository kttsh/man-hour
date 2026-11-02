-- V-12 OKS02と最後の保存が合わない社員日
-- 目的: V-03の例外（最後の保存より古い、行が多い、insert_dateが後）を切り分ける。
-- 実行: SSMSで全体を1回実行する（GOなし、1バッチ）。読取のみで、データは変更しない。
-- 出力: 集計だけ。氏名・自由記述・ユーザIDは出さない。ラベルは英数字。
-- 詳細: tools/update-method-simulation/README.md

USE GEMS_DM_S;
SET NOCOUNT ON;

-- 対象範囲（keijo_dateはyyyymmddの文字列。@toは含まない）。@companyをNULLにすると全社。
DECLARE @from varchar(8) = '20260901';
DECLARE @to   varchar(8) = '20261001';
DECLARE @company nvarchar(3) = NULL;

-- OKS02の取込み時点。最後の保存がこれより後なら、時間差で説明できる可能性がある。
DECLARE @cut datetime = (
    SELECT MAX(update_date) FROM dbo.V_T_OKS02 WHERE keijo_date >= @from
);

-- V-03の正常な組み合わせ（ALL_ROWS_AT_LAST_SAVE × ROWS_EQUAL）以外を出す。
-- 見る順番:
--   save_match = INSERT_BEFORE_LAST_SAVE : OKS02が最新の入力ではない可能性。
--     update_kind = UPDATE_BEFORE_LAST_SAVE なら、案2の更新日時の差分に載らない。
--   save_match = ALL_ROWS_AT_LAST_SAVE × OKS02_MORE : 保存で全行が書き直されない反例の候補。
--   save_match = INSERT_AFTER_LAST_SAVE : gap_bucket が小さければ時刻のずれ、大きければ保存以外の処理。
WITH o02 AS (
    SELECT
        company_cd, user_id, keijo_date,
        COUNT(*) AS row_cnt,
        MIN(insert_date) AS min_insert,
        MAX(insert_date) AS max_insert,
        MAX(update_date) AS max_update,
        MAX(CASE WHEN status IN ('1','2','3') THEN 1 ELSE 0 END) AS has_pending,
        MAX(machine_flg) AS machine_flg
    FROM dbo.V_T_OKS02
    WHERE keijo_date >= @from AND keijo_date < @to
      AND (@company IS NULL OR company_cd = @company)
    GROUP BY company_cd, user_id, keijo_date
), g AS (
    SELECT
        company_cd, user_id, keijo_date, shusei_dt,
        SUM(CASE WHEN shusei_kbn = 'A' THEN 1 ELSE 0 END) AS a_rows,
        SUM(CASE WHEN shusei_kbn = 'A' AND status IN ('1','2','3') THEN 1 ELSE 0 END) AS a_pending,
        SUM(CASE WHEN shusei_kbn = 'A' AND keijo_kosu <> 0 THEN 1 ELSE 0 END) AS a_nonzero_rows
    FROM dbo.V_T_OKS10
    WHERE keijo_date >= @from AND keijo_date < @to
      AND (@company IS NULL OR company_cd = @company)
    GROUP BY company_cd, user_id, keijo_date, shusei_dt
), s AS (
    SELECT
        g.*,
        ROW_NUMBER() OVER (PARTITION BY company_cd, user_id, keijo_date ORDER BY shusei_dt DESC) AS rn,
        LAG(a_nonzero_rows) OVER (PARTITION BY company_cd, user_id, keijo_date ORDER BY shusei_dt) AS prev_nonzero_rows
    FROM g
), j AS (
    SELECT
        o.company_cd, o.row_cnt, o.machine_flg,
        CASE
            WHEN l.shusei_dt IS NULL THEN 'NO_OKS10'
            WHEN o.min_insert = l.shusei_dt AND o.max_insert = l.shusei_dt THEN 'ALL_ROWS_AT_LAST_SAVE'
            WHEN o.max_insert = l.shusei_dt THEN 'SOME_ROWS_AT_LAST_SAVE'
            WHEN o.max_insert < l.shusei_dt THEN 'INSERT_BEFORE_LAST_SAVE'
            ELSE 'INSERT_AFTER_LAST_SAVE'
        END AS save_match,
        CASE
            WHEN l.shusei_dt IS NULL THEN 'NO_OKS10'
            WHEN l.a_nonzero_rows = o.row_cnt THEN 'ROWS_EQUAL'
            WHEN l.a_nonzero_rows > o.row_cnt THEN 'OKS10_MORE'
            ELSE 'OKS02_MORE'
        END AS row_match,
        CASE
            WHEN l.shusei_dt IS NULL THEN 'NO_OKS10'
            WHEN ABS(DATEDIFF(SECOND, l.shusei_dt, o.max_insert)) = 0     THEN 'GAP_0S'
            WHEN ABS(DATEDIFF(SECOND, l.shusei_dt, o.max_insert)) <= 60    THEN 'GAP_LE_1M'
            WHEN ABS(DATEDIFF(SECOND, l.shusei_dt, o.max_insert)) <= 3600  THEN 'GAP_LE_1H'
            WHEN ABS(DATEDIFF(SECOND, l.shusei_dt, o.max_insert)) <= 86400 THEN 'GAP_LE_1D'
            ELSE 'GAP_GT_1D'
        END AS gap_bucket,
        CASE
            WHEN l.shusei_dt IS NULL THEN 'NO_OKS10'
            WHEN l.shusei_dt > @cut THEN 'SAVE_AFTER_OKS02_CUT'
            ELSE 'SAVE_BEFORE_OKS02_CUT'
        END AS cut_kind,
        CASE
            WHEN l.shusei_dt IS NULL THEN 'NO_OKS10'
            WHEN o.max_update < l.shusei_dt THEN 'UPDATE_BEFORE_LAST_SAVE'
            ELSE 'UPDATE_AT_OR_AFTER_LAST_SAVE'
        END AS update_kind,
        CASE WHEN o.has_pending = 1 THEN 'PENDING' ELSE 'APPROVED' END AS oks02_state,
        CASE
            WHEN l.shusei_dt IS NULL THEN 'NO_OKS10'
            WHEN l.a_rows = 0 THEN 'LAST_B_ONLY'
            WHEN l.a_pending = l.a_rows THEN 'LAST_A_PENDING'
            WHEN l.a_pending > 0 THEN 'LAST_A_MIXED'
            ELSE 'LAST_A_APPROVED'
        END AS last_group_kind,
        CASE
            WHEN l.prev_nonzero_rows IS NULL THEN 'NO_PREV_GROUP'
            WHEN l.prev_nonzero_rows = o.row_cnt THEN 'PREV_ROWS_EQUAL'
            ELSE 'PREV_ROWS_DIFF'
        END AS prev_match,
        CASE
            WHEN l.shusei_dt IS NULL THEN 'NO_OKS10'
            WHEN o.row_cnt - l.a_nonzero_rows >= 3 THEN 'OKS02_PLUS_3UP'
            WHEN o.row_cnt - l.a_nonzero_rows <= -3 THEN 'OKS10_PLUS_3UP'
            ELSE CONCAT('DIFF_', o.row_cnt - l.a_nonzero_rows)
        END AS row_gap
    FROM o02 AS o
    LEFT JOIN s AS l
      ON l.company_cd = o.company_cd AND l.user_id = o.user_id AND l.keijo_date = o.keijo_date AND l.rn = 1
)
SELECT
    company_cd, save_match, row_match, gap_bucket, cut_kind, update_kind,
    oks02_state, last_group_kind, prev_match, row_gap, machine_flg,
    COUNT(*) AS shain_days,
    SUM(row_cnt) AS oks02_rows,
    MAX(@cut) AS oks02_cut
FROM j
WHERE NOT (save_match = 'ALL_ROWS_AT_LAST_SAVE' AND row_match = 'ROWS_EQUAL')
GROUP BY
    company_cd, save_match, row_match, gap_bucket, cut_kind, update_kind,
    oks02_state, last_group_kind, prev_match, row_gap, machine_flg
ORDER BY
    save_match, row_match, company_cd, gap_bucket, cut_kind, update_kind,
    oks02_state, last_group_kind, prev_match, row_gap, machine_flg
OPTION (RECOMPILE);
