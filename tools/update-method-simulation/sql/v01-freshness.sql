-- V-01 参照環境の鮮度と権限
-- 目的: 参照環境が毎日更新されるかを確かめる。日をまたいで2回以上実行し、結果を比べる。
-- 実行: SSMSで全体を1回実行する（GOなし、1バッチ）。読取のみで、データは変更しない。
-- 出力: 集計だけ。氏名・自由記述・ユーザIDは出さない。ラベルは英数字。
-- 詳細: tools/update-method-simulation/README.md

USE GEMS_DM_S;
SET NOCOUNT ON;

-- 結果1: サーバーの版と権限
SELECT
    CONVERT(varchar(30), SERVERPROPERTY('ProductVersion')) AS product_version,
    CONVERT(varchar(60), SERVERPROPERTY('Edition'))        AS edition,
    (SELECT compatibility_level FROM sys.databases WHERE name = DB_NAME()) AS compatibility_level,
    GETDATE() AS checked_at,
    CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.V_T_OKS02')) IS NULL THEN 0 ELSE 1 END AS can_read_view_definition,
    HAS_PERMS_BY_NAME(DB_NAME(), 'DATABASE', 'VIEW DATABASE STATE') AS has_view_database_state,
    HAS_PERMS_BY_NAME(DB_NAME(), 'DATABASE', 'SHOWPLAN')            AS has_showplan;

-- 結果2: ビューごとの最終更新
SELECT
    view_name, row_cnt, max_insert_date, max_update_date, max_event_date,
    DATEDIFF(HOUR, max_update_date, GETDATE()) AS hours_since_last_update
FROM (
    SELECT 'V_T_OKS02' AS view_name, COUNT_BIG(*) AS row_cnt,
           MAX(insert_date) AS max_insert_date, MAX(update_date) AS max_update_date,
           CAST(NULL AS datetime) AS max_event_date
    FROM dbo.V_T_OKS02
    UNION ALL
    SELECT 'V_T_OKS07', COUNT_BIG(*), MAX(insert_date), MAX(update_date), MAX(correction_date)
    FROM dbo.V_T_OKS07
    UNION ALL
    SELECT 'V_T_OKS10', COUNT_BIG(*), MAX(insert_date), MAX(update_date), MAX(shusei_dt)
    FROM dbo.V_T_OKS10
) AS s
ORDER BY view_name;

-- 結果3: 作業月ごとの件数と内容の指紋（2回の実行で比べる）
SELECT
    view_name, keijo_month, row_cnt, sum_kosu, max_update_date, content_checksum
FROM (
    SELECT 'V_T_OKS02' AS view_name, LEFT(keijo_date, 6) AS keijo_month, COUNT_BIG(*) AS row_cnt,
           SUM(keijo_kosu) AS sum_kosu, MAX(update_date) AS max_update_date,
           CHECKSUM_AGG(BINARY_CHECKSUM(company_cd, user_id, keijo_date, status, keijo_kosu, update_date)) AS content_checksum
    FROM dbo.V_T_OKS02
    WHERE keijo_date >= '20260401'
    GROUP BY LEFT(keijo_date, 6)
    UNION ALL
    SELECT 'V_T_OKS07', LEFT(keijo_date, 6), COUNT_BIG(*), SUM(keijo_kosu), MAX(update_date),
           CHECKSUM_AGG(BINARY_CHECKSUM(company_cd, user_id, keijo_date, status, keijo_kosu, update_date))
    FROM dbo.V_T_OKS07
    WHERE keijo_date >= '20260401'
    GROUP BY LEFT(keijo_date, 6)
    UNION ALL
    SELECT 'V_T_OKS10', LEFT(keijo_date, 6), COUNT_BIG(*), SUM(keijo_kosu), MAX(update_date),
           CHECKSUM_AGG(BINARY_CHECKSUM(hnko_rireki_id, status, update_date))
    FROM dbo.V_T_OKS10
    WHERE keijo_date >= '20260401'
    GROUP BY LEFT(keijo_date, 6)
) AS s
ORDER BY view_name, keijo_month;
