-- V-06 OKS02のupdate_dateの日別分布
-- 目的: 締切の山の大きさと、チャートの9/4・9/5の山の原因を確かめる。
-- 実行: SSMSで全体を1回実行する（GOなし、1バッチ）。読取のみで、データは変更しない。
-- 出力: 集計だけ。氏名・自由記述・ユーザIDは出さない。ラベルは英数字。
-- 詳細: tools/update-method-simulation/README.md

USE GEMS_DM_S;
SET NOCOUNT ON;

-- 対象とする更新日の開始
DECLARE @from_dt datetime = '20260401';
DECLARE @company nvarchar(3) = NULL;

-- 現在のupdate_dateの分布であり、過去の日次差分そのものではない（後日再更新された行は後の日に数えられる）。
-- 結果1: 更新日ごとの件数
-- max_rows_same_timestamp が row_cnt に近い日は、一括更新（締切など）とみられる。
WITH r AS (
    SELECT
        company_cd, user_id, keijo_date, update_date,
        CAST(update_date AS date) AS update_day,
        LEFT(keijo_date, 6) AS keijo_month,
        CONVERT(char(6), update_date, 112) AS update_month
    FROM dbo.V_T_OKS02
    WHERE update_date >= @from_dt
      AND (@company IS NULL OR company_cd = @company)
), ts AS (
    SELECT update_date, COUNT(*) AS c FROM r GROUP BY update_date
), peak AS (
    SELECT CAST(update_date AS date) AS update_day, MAX(c) AS max_rows_same_timestamp
    FROM ts
    GROUP BY CAST(update_date AS date)
), day_agg AS (
    SELECT
        update_day,
        COUNT(*) AS row_cnt,
        SUM(CASE WHEN keijo_month = update_month THEN 1 ELSE 0 END) AS rows_same_month,
        SUM(CASE WHEN keijo_month < update_month THEN 1 ELSE 0 END) AS rows_past_month,
        SUM(CASE WHEN keijo_month > update_month THEN 1 ELSE 0 END) AS rows_future_month,
        COUNT(DISTINCT CONCAT(company_cd, '|', user_id, '|', keijo_date)) AS shain_days,
        COUNT(DISTINCT company_cd) AS companies
    FROM r
    GROUP BY update_day
)
SELECT d.*, p.max_rows_same_timestamp
FROM day_agg AS d
JOIN peak AS p ON p.update_day = d.update_day
ORDER BY d.update_day
OPTION (RECOMPILE);

-- 結果2: 作業月 × 更新月の行数（作業月からどれだけ後まで更新が続くか）
SELECT
    LEFT(keijo_date, 6) AS keijo_month,
    CONVERT(char(6), update_date, 112) AS update_month,
    COUNT(*) AS row_cnt,
    SUM(keijo_kosu) AS sum_kosu
FROM dbo.V_T_OKS02
WHERE update_date >= @from_dt
  AND (@company IS NULL OR company_cd = @company)
GROUP BY LEFT(keijo_date, 6), CONVERT(char(6), update_date, 112)
ORDER BY keijo_month, update_month
OPTION (RECOMPILE);
