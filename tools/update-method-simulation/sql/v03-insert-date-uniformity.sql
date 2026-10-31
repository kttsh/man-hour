-- V-03 保存のたびに社員日の全行が書き直されるか
-- 目的: OKS02のinsert_date・update_dateが社員日の中で揃い、OKS10の最後の保存時刻と一致するかを確かめる。
-- 実行: SSMSで全体を1回実行する（GOなし、1バッチ）。読取のみで、データは変更しない。
-- 出力: 集計だけ。氏名・自由記述・ユーザIDは出さない。ラベルは英数字。
-- 詳細: tools/update-method-simulation/README.md

USE GEMS_DM_S;
SET NOCOUNT ON;

-- 対象範囲（keijo_dateはyyyymmddの文字列。@toは含まない）。@companyをNULLにすると全社。
DECLARE @from varchar(8) = '20260901';
DECLARE @to   varchar(8) = '20261001';
DECLARE @company nvarchar(3) = NULL;

-- 結果1: OKS02の社員日の中で、日時が揃うか
WITH d AS (
    SELECT
        company_cd, user_id, keijo_date,
        COUNT(*) AS row_cnt,
        COUNT(DISTINCT insert_date) AS insert_kinds,
        COUNT(DISTINCT update_date) AS update_kinds
    FROM dbo.V_T_OKS02
    WHERE keijo_date >= @from AND keijo_date < @to
      AND (@company IS NULL OR company_cd = @company)
    GROUP BY company_cd, user_id, keijo_date
)
SELECT
    CASE WHEN row_cnt = 1 THEN 'ONE_ROW' ELSE 'MULTI_ROW' END AS shain_day_size,
    CASE WHEN insert_kinds = 1 THEN 'INSERT_1' WHEN insert_kinds = 2 THEN 'INSERT_2' ELSE 'INSERT_3PLUS' END AS insert_date_kinds,
    CASE WHEN update_kinds = 1 THEN 'UPDATE_1' WHEN update_kinds = 2 THEN 'UPDATE_2' ELSE 'UPDATE_3PLUS' END AS update_date_kinds,
    COUNT(*) AS shain_days,
    SUM(row_cnt) AS row_cnt
FROM d
GROUP BY
    CASE WHEN row_cnt = 1 THEN 'ONE_ROW' ELSE 'MULTI_ROW' END,
    CASE WHEN insert_kinds = 1 THEN 'INSERT_1' WHEN insert_kinds = 2 THEN 'INSERT_2' ELSE 'INSERT_3PLUS' END,
    CASE WHEN update_kinds = 1 THEN 'UPDATE_1' WHEN update_kinds = 2 THEN 'UPDATE_2' ELSE 'UPDATE_3PLUS' END
ORDER BY shain_day_size, insert_date_kinds, update_date_kinds
OPTION (RECOMPILE);

-- 結果2: OKS02の行と、OKS10の最後の保存（最後の組）の比較
-- ALL_ROWS_AT_LAST_SAVE が大半なら、差分は社員日の全行で届くとみてよい。
-- ROWS_EQUAL は「0時間以外のA行数 = OKS02の行数」で、Q2の見積り式の当たり具合を表す。
WITH o02 AS (
    SELECT
        company_cd, user_id, keijo_date,
        COUNT(*) AS row_cnt,
        MIN(insert_date) AS min_insert,
        MAX(insert_date) AS max_insert
    FROM dbo.V_T_OKS02
    WHERE keijo_date >= @from AND keijo_date < @to
      AND (@company IS NULL OR company_cd = @company)
    GROUP BY company_cd, user_id, keijo_date
), o10 AS (
    SELECT
        company_cd, user_id, keijo_date, shusei_dt, shusei_kbn, keijo_kosu,
        MAX(shusei_dt) OVER (PARTITION BY company_cd, user_id, keijo_date) AS last_save
    FROM dbo.V_T_OKS10
    WHERE keijo_date >= @from AND keijo_date < @to
      AND (@company IS NULL OR company_cd = @company)
), last_group AS (
    SELECT
        company_cd, user_id, keijo_date, last_save,
        SUM(CASE WHEN shusei_kbn = 'A' AND keijo_kosu <> 0 THEN 1 ELSE 0 END) AS a_nonzero_rows
    FROM o10
    WHERE shusei_dt = last_save
    GROUP BY company_cd, user_id, keijo_date, last_save
), j AS (
    SELECT
        CASE
            WHEN l.last_save IS NULL THEN 'NO_OKS10'
            WHEN o.min_insert = l.last_save AND o.max_insert = l.last_save THEN 'ALL_ROWS_AT_LAST_SAVE'
            WHEN o.max_insert = l.last_save THEN 'SOME_ROWS_AT_LAST_SAVE'
            WHEN o.max_insert < l.last_save THEN 'INSERT_BEFORE_LAST_SAVE'
            ELSE 'INSERT_AFTER_LAST_SAVE'
        END AS save_match,
        CASE
            WHEN l.last_save IS NULL THEN 'NO_OKS10'
            WHEN l.a_nonzero_rows = o.row_cnt THEN 'ROWS_EQUAL'
            WHEN l.a_nonzero_rows > o.row_cnt THEN 'OKS10_MORE'
            ELSE 'OKS02_MORE'
        END AS row_match,
        o.row_cnt
    FROM o02 AS o
    LEFT JOIN last_group AS l
      ON l.company_cd = o.company_cd AND l.user_id = o.user_id AND l.keijo_date = o.keijo_date
)
SELECT save_match, row_match, COUNT(*) AS shain_days, SUM(row_cnt) AS oks02_rows
FROM j
GROUP BY save_match, row_match
ORDER BY save_match, row_match
OPTION (RECOMPILE);
