-- V-02 社員日の中のstatus混在
-- 目的: 承認ゲートの判定単位（社員日）が成り立つかを確かめる。
-- 実行: SSMSで全体を1回実行する（GOなし、1バッチ）。読取のみで、データは変更しない。
-- 出力: 集計だけ。氏名・自由記述・ユーザIDは出さない。ラベルは英数字。
-- 詳細: tools/update-method-simulation/README.md

USE GEMS_DM_S;
SET NOCOUNT ON;

-- 対象範囲（keijo_dateはyyyymmddの文字列。@toは含まない）。@companyをNULLにすると全社。
DECLARE @from varchar(8) = '20260401';
DECLARE @to   varchar(8) = '20261101';
DECLARE @company nvarchar(3) = NULL;

-- 社員日 = company_cd + user_id + keijo_date
-- status 1-3 = 承認待ち、4-7 = 承認済み
WITH d AS (
    SELECT
        company_cd, user_id, keijo_date,
        COUNT(*) AS row_cnt,
        COUNT(DISTINCT status) AS status_kinds,
        SUM(CASE WHEN status IN ('1','2','3') THEN 1 ELSE 0 END) AS pending_rows,
        SUM(CASE WHEN status IN ('4','5','6','7') THEN 1 ELSE 0 END) AS approved_rows,
        SUM(CASE WHEN status IN ('1','2','3','4','5','6','7') THEN 0 ELSE 1 END) AS other_rows
    FROM dbo.V_T_OKS02
    WHERE keijo_date >= @from AND keijo_date < @to
      AND (@company IS NULL OR company_cd = @company)
    GROUP BY company_cd, user_id, keijo_date
), k AS (
    SELECT
        company_cd, LEFT(keijo_date, 6) AS keijo_month, row_cnt, status_kinds,
        CASE
            WHEN other_rows > 0                       THEN 'OTHER_VALUE'
            WHEN pending_rows > 0 AND approved_rows > 0 THEN 'MIXED_PENDING_APPROVED'
            WHEN pending_rows > 0                     THEN 'ALL_PENDING'
            WHEN status_kinds > 1                     THEN 'ALL_APPROVED_MULTI_STATUS'
            ELSE 'ALL_APPROVED_ONE_STATUS'
        END AS gate_kind
    FROM d
)
SELECT
    company_cd, keijo_month, gate_kind,
    COUNT(*) AS shain_days,
    SUM(row_cnt) AS row_cnt,
    MAX(row_cnt) AS max_rows_per_shain_day
FROM k
GROUP BY company_cd, keijo_month, gate_kind
ORDER BY company_cd, keijo_month, gate_kind
OPTION (RECOMPILE);
