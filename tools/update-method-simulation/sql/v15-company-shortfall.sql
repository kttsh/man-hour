-- V-15 会社の社員日の不足（既定はB46の8月と9月）
-- 目的: 不足の原因が入力の遅れか、人や組織の変化かを切り分ける。P-1の基準月を確定する。
-- 実行: SSMSで全体を1回実行する（GOなし、1バッチ）。読取のみで、データは変更しない。
-- 出力: 集計だけ。氏名・自由記述・ユーザIDは出さない。所属コードはハッシュで出す。ラベルは英数字。
-- 詳細: tools/update-method-simulation/README.md

USE GEMS_DM_S;
SET NOCOUNT ON;

DECLARE @company nvarchar(3) = 'B46';
DECLARE @base_month varchar(6) = '202608';
DECLARE @target_month varchar(6) = '202609';
DECLARE @trend_from varchar(8) = '20260401';

DECLARE @from varchar(8) = @base_month + '01';
DECLARE @to varchar(8) = CONVERT(char(8), DATEADD(MONTH, 1, CONVERT(date, @target_month + '01', 112)), 112);

-- 結果1: 作業日別の件数。特定の日から落ちていれば、入力の遅れか異動を疑う。
WITH o02 AS (
    SELECT
        keijo_date,
        COUNT(*) AS oks02_rows,
        COUNT(DISTINCT user_id) AS oks02_users,
        SUM(keijo_kosu) AS oks02_hours
    FROM dbo.V_T_OKS02
    WHERE company_cd = @company AND keijo_date >= @from AND keijo_date < @to
    GROUP BY keijo_date
), o10 AS (
    SELECT keijo_date, COUNT(DISTINCT user_id) AS oks10_users
    FROM dbo.V_T_OKS10
    WHERE company_cd = @company AND keijo_date >= @from AND keijo_date < @to
    GROUP BY keijo_date
)
SELECT
    COALESCE(a.keijo_date, b.keijo_date) AS keijo_date,
    a.oks02_rows, a.oks02_users, a.oks02_hours, b.oks10_users
FROM o02 AS a
FULL OUTER JOIN o10 AS b ON b.keijo_date = a.keijo_date
ORDER BY keijo_date
OPTION (RECOMPILE);

-- 結果2: 月別の人数と密度。rows_per_day が下がる月は、人の構成が変わった可能性がある。
SELECT
    LEFT(keijo_date, 6) AS keijo_month,
    COUNT(DISTINCT user_id) AS users,
    COUNT(DISTINCT CONCAT(user_id, '|', keijo_date)) AS shain_days,
    COUNT(*) AS row_cnt,
    SUM(keijo_kosu) AS hours,
    CAST(COUNT(*) * 1.0 / COUNT(DISTINCT CONCAT(user_id, '|', keijo_date)) AS decimal(10, 2)) AS rows_per_day,
    CAST(COUNT(DISTINCT CONCAT(user_id, '|', keijo_date)) * 1.0 / COUNT(DISTINCT user_id) AS decimal(10, 2)) AS days_per_user
FROM dbo.V_T_OKS02
WHERE company_cd = @company AND keijo_date >= @trend_from AND keijo_date < @to
GROUP BY LEFT(keijo_date, 6)
ORDER BY keijo_month
OPTION (RECOMPILE);

-- 結果3: 人の出入りと、対象月の最後の入力日
-- user_group = IN_BOTH で last_day が月の途中に集まれば、入力の遅れが有力。
-- ONLY_BASE が多ければ、異動や組織変更が有力（last_day は NONE）。
WITH u AS (
    SELECT
        user_id,
        SUM(CASE WHEN LEFT(keijo_date, 6) = @base_month THEN 1 ELSE 0 END) AS base_rows,
        SUM(CASE WHEN LEFT(keijo_date, 6) = @target_month THEN 1 ELSE 0 END) AS target_rows,
        COUNT(DISTINCT CASE WHEN LEFT(keijo_date, 6) = @base_month THEN keijo_date END) AS base_days,
        COUNT(DISTINCT CASE WHEN LEFT(keijo_date, 6) = @target_month THEN keijo_date END) AS target_days,
        MAX(CASE WHEN LEFT(keijo_date, 6) = @target_month THEN keijo_date END) AS last_target_date
    FROM dbo.V_T_OKS02
    WHERE company_cd = @company AND keijo_date >= @from AND keijo_date < @to
    GROUP BY user_id
)
SELECT
    CASE
        WHEN base_rows > 0 AND target_rows > 0 THEN 'IN_BOTH'
        WHEN base_rows > 0 THEN 'ONLY_BASE'
        ELSE 'ONLY_TARGET'
    END AS user_group,
    COALESCE(last_target_date, 'NONE') AS last_day,
    COUNT(*) AS users,
    SUM(base_days) AS base_shain_days,
    SUM(target_days) AS target_shain_days,
    SUM(base_rows) AS base_rows,
    SUM(target_rows) AS target_rows
FROM u
GROUP BY
    CASE
        WHEN base_rows > 0 AND target_rows > 0 THEN 'IN_BOTH'
        WHEN base_rows > 0 THEN 'ONLY_BASE'
        ELSE 'ONLY_TARGET'
    END,
    COALESCE(last_target_date, 'NONE')
ORDER BY user_group, last_day
OPTION (RECOMPILE);

-- 結果4: 所属別の増減（社員日の減少が大きい順に50件）
-- 特定の所属だけが消えていれば、組織の変更や取込みの対象外を疑う。
SELECT TOP (50)
    CONVERT(char(8), HASHBYTES('SHA2_256', shozoku_cd), 2) AS shozoku_hash,
    COUNT(DISTINCT CASE WHEN LEFT(keijo_date, 6) = @base_month THEN user_id END) AS base_users,
    COUNT(DISTINCT CASE WHEN LEFT(keijo_date, 6) = @target_month THEN user_id END) AS target_users,
    COUNT(DISTINCT CASE WHEN LEFT(keijo_date, 6) = @base_month THEN CONCAT(user_id, '|', keijo_date) END) AS base_shain_days,
    COUNT(DISTINCT CASE WHEN LEFT(keijo_date, 6) = @target_month THEN CONCAT(user_id, '|', keijo_date) END) AS target_shain_days
FROM dbo.V_T_OKS02
WHERE company_cd = @company AND keijo_date >= @from AND keijo_date < @to
GROUP BY CONVERT(char(8), HASHBYTES('SHA2_256', shozoku_cd), 2)
ORDER BY
    COUNT(DISTINCT CASE WHEN LEFT(keijo_date, 6) = @target_month THEN CONCAT(user_id, '|', keijo_date) END)
    - COUNT(DISTINCT CASE WHEN LEFT(keijo_date, 6) = @base_month THEN CONCAT(user_id, '|', keijo_date) END),
    shozoku_hash
OPTION (RECOMPILE);
