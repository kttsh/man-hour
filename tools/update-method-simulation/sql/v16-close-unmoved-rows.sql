-- V-16 締切で動かない行
-- 目的: 翌月にupdate_dateが動かない約0.25%の行を特定する。R-04は対象月の全行が動く前提を置いている。
-- 実行: SSMSで全体を1回実行する（GOなし、1バッチ）。読取のみで、データは変更しない。
-- 出力: 集計だけ。氏名・自由記述・ユーザIDは出さない。ラベルは英数字。
-- 詳細: tools/update-method-simulation/README.md

USE GEMS_DM_S;
SET NOCOUNT ON;

-- 対象範囲（keijo_dateはyyyymmddの文字列。@toは含まない）。@companyをNULLにすると全社。締切が済んだ月を指定する。
DECLARE @from varchar(8) = '20260401';
DECLARE @to   varchar(8) = '20260901';
DECLARE @company nvarchar(3) = NULL;

-- 結果1: 動いた行と動かなかった行の、会社・status別の件数
-- moved_kind = UNMOVED の status が 4 のままなら、締切の処理を通っていない行とみられる。
WITH r AS (
    SELECT
        company_cd, user_id, keijo_date, status, if_status, machine_flg, keijo_kosu,
        CASE
            WHEN CONVERT(char(6), update_date, 112) > LEFT(keijo_date, 6) THEN 'MOVED'
            ELSE 'UNMOVED'
        END AS moved_kind
    FROM dbo.V_T_OKS02
    WHERE keijo_date >= @from AND keijo_date < @to
      AND (@company IS NULL OR company_cd = @company)
)
SELECT
    company_cd, LEFT(keijo_date, 6) AS keijo_month, moved_kind, status, if_status, machine_flg,
    COUNT(*) AS row_cnt,
    COUNT(DISTINCT CONCAT(user_id, '|', keijo_date)) AS shain_days,
    COUNT(DISTINCT user_id) AS users,
    SUM(keijo_kosu) AS hours
FROM r
GROUP BY company_cd, LEFT(keijo_date, 6), moved_kind, status, if_status, machine_flg
ORDER BY company_cd, keijo_month, moved_kind, status, if_status, machine_flg
OPTION (RECOMPILE);

-- 結果2: 動かなかった行は、特定の人に偏るか
-- ALL_UNMOVED が多ければ、人の単位で締切の対象外になっている。
WITH u AS (
    SELECT
        company_cd, user_id, LEFT(keijo_date, 6) AS keijo_month,
        COUNT(*) AS row_cnt,
        SUM(CASE WHEN CONVERT(char(6), update_date, 112) > LEFT(keijo_date, 6) THEN 0 ELSE 1 END) AS unmoved_rows
    FROM dbo.V_T_OKS02
    WHERE keijo_date >= @from AND keijo_date < @to
      AND (@company IS NULL OR company_cd = @company)
    GROUP BY company_cd, user_id, LEFT(keijo_date, 6)
)
SELECT
    company_cd, keijo_month,
    CASE WHEN unmoved_rows = row_cnt THEN 'ALL_UNMOVED' ELSE 'PARTLY_UNMOVED' END AS user_kind,
    COUNT(*) AS users,
    SUM(row_cnt) AS row_cnt,
    SUM(unmoved_rows) AS unmoved_rows
FROM u
WHERE unmoved_rows > 0
GROUP BY company_cd, keijo_month, CASE WHEN unmoved_rows = row_cnt THEN 'ALL_UNMOVED' ELSE 'PARTLY_UNMOVED' END
ORDER BY company_cd, keijo_month, user_kind
OPTION (RECOMPILE);
