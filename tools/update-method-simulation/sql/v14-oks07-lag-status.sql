-- V-14 OKS07の遡りと状態
-- 目的: 修正が作業月からどれだけ後に届くかと、statusと承認日時の関係を確かめる。
-- 実行: SSMSで全体を1回実行する（GOなし、1バッチ）。読取のみで、データは変更しない。
-- 出力: 集計だけ。氏名・自由記述・ユーザIDは出さない。ラベルは英数字。
-- 詳細: tools/update-method-simulation/README.md

USE GEMS_DM_S;
SET NOCOUNT ON;

-- 対象範囲（keijo_dateはyyyymmddの文字列。@toは含まない）。@companyをNULLにすると全社。
DECLARE @from varchar(8) = '20230101';
DECLARE @to   varchar(8) = '20261101';
DECLARE @company nvarchar(3) = NULL;

-- 結果1: 作業月 × 修正月（修正がどれだけ遡るか）
-- months_back が大きい行が多いほど、過去月の実績が長く動き続ける。OKS07の取得範囲の根拠になる。
SELECT
    LEFT(keijo_date, 6) AS keijo_month,
    CONVERT(char(6), correction_date, 112) AS correction_month,
    DATEDIFF(MONTH, TRY_CONVERT(date, keijo_date, 112), correction_date) AS months_back,
    status,
    COUNT(*) AS row_cnt,
    COUNT(DISTINCT CONCAT(company_cd, '|', user_id, '|', keijo_date)) AS shain_days,
    COUNT(DISTINCT company_cd) AS companies
FROM dbo.V_T_OKS07
WHERE keijo_date >= @from AND keijo_date < @to
  AND (@company IS NULL OR company_cd = @company)
GROUP BY
    LEFT(keijo_date, 6),
    CONVERT(char(6), correction_date, 112),
    DATEDIFF(MONTH, TRY_CONVERT(date, keijo_date, 112), correction_date),
    status
ORDER BY keijo_month, correction_month, status
OPTION (RECOMPILE);

-- 結果2: statusと各段階の日時の有無
-- status 1〜3 で has_shonin = 1 の行があれば、上長の承認後もstatusが動かず、
-- 「status 4〜7だけ重ねる」では確定まで反映が遅れる。
SELECT
    company_cd, status,
    CASE WHEN shonin_date IS NULL THEN 0 ELSE 1 END AS has_shonin,
    CASE WHEN keiri_shonin_date IS NULL THEN 0 ELSE 1 END AS has_keiri_shonin,
    CASE WHEN kakutei_date IS NULL THEN 0 ELSE 1 END AS has_kakutei,
    CASE WHEN simekiri_date IS NULL THEN 0 ELSE 1 END AS has_simekiri,
    CASE WHEN keiri_setuzoku_date IS NULL THEN 0 ELSE 1 END AS has_keiri_setuzoku,
    COUNT(*) AS row_cnt,
    COUNT(DISTINCT CONCAT(user_id, '|', keijo_date)) AS shain_days,
    MIN(correction_date) AS min_correction_date,
    MAX(correction_date) AS max_correction_date,
    MAX(DATEDIFF(DAY, correction_date, shonin_date)) AS max_days_to_shonin,
    MAX(DATEDIFF(DAY, correction_date, kakutei_date)) AS max_days_to_kakutei,
    MAX(DATEDIFF(DAY, correction_date, simekiri_date)) AS max_days_to_simekiri
FROM dbo.V_T_OKS07
WHERE keijo_date >= @from AND keijo_date < @to
  AND (@company IS NULL OR company_cd = @company)
GROUP BY
    company_cd, status,
    CASE WHEN shonin_date IS NULL THEN 0 ELSE 1 END,
    CASE WHEN keiri_shonin_date IS NULL THEN 0 ELSE 1 END,
    CASE WHEN kakutei_date IS NULL THEN 0 ELSE 1 END,
    CASE WHEN simekiri_date IS NULL THEN 0 ELSE 1 END,
    CASE WHEN keiri_setuzoku_date IS NULL THEN 0 ELSE 1 END
ORDER BY company_cd, status, has_shonin, has_keiri_shonin, has_kakutei, has_simekiri, has_keiri_setuzoku
OPTION (RECOMPILE);

-- 結果3: update_dateの日別（締切が過去月の修正もまとめて書き換えるか）
-- keijo_months が大きい日は、複数の作業月の行を一括で書き換えている。OKS07の差分の山になる。
SELECT
    CAST(update_date AS date) AS update_day,
    COUNT(*) AS row_cnt,
    COUNT(DISTINCT LEFT(keijo_date, 6)) AS keijo_months,
    MIN(LEFT(keijo_date, 6)) AS min_keijo_month,
    MAX(LEFT(keijo_date, 6)) AS max_keijo_month,
    COUNT(DISTINCT company_cd) AS companies
FROM dbo.V_T_OKS07
WHERE keijo_date >= @from AND keijo_date < @to
  AND (@company IS NULL OR company_cd = @company)
GROUP BY CAST(update_date AS date)
ORDER BY update_day
OPTION (RECOMPILE);
