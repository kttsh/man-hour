-- V-17 キー列の照合順序と空白
-- 目的: SQL Serverで同じとみなされた値が、DuckDB・BigQuery・HASHBYTESでは別の値になる範囲を確かめる。
-- 実行: SSMSで全体を1回実行する（GOなし、1バッチ）。読取のみで、データは変更しない。
-- 出力: 集計だけ。値そのものは出さない。ラベルは英数字。
-- 詳細: tools/update-method-simulation/README.md

USE GEMS_DM_S;
SET NOCOUNT ON;

-- 対象範囲（keijo_dateはyyyymmddの文字列。@toは含まない）。@companyをNULLにすると全社。
DECLARE @from varchar(8) = '20260401';
DECLARE @to   varchar(8) = '20261001';
DECLARE @company nvarchar(3) = NULL;

-- 結果1: データベースとサーバーの照合順序
SELECT
    CONVERT(nvarchar(128), DATABASEPROPERTYEX(DB_NAME(), 'Collation')) AS database_collation,
    CONVERT(nvarchar(128), SERVERPROPERTY('Collation')) AS server_collation;

-- 結果2: キー列の型と照合順序。権限がなければ0行になる。
SELECT
    v.name AS view_name, c.name AS column_name, t.name AS type_name, c.max_length, c.collation_name
FROM sys.views AS v
JOIN sys.columns AS c ON c.object_id = v.object_id
JOIN sys.types AS t ON t.user_type_id = c.user_type_id
WHERE v.name IN ('V_T_OKS02', 'V_T_OKS07', 'V_T_OKS10')
  AND c.name IN (
      'company_cd', 'user_id', 'wbs_cd', 'opa_cd', 'genka_center_cd', 'katudo_type',
      'kyotenbetu_bunseki_key', 'mhi_wbs', 'shokushu_cd', 'keijo_genka_center_cd', 'youeki_cd')
ORDER BY view_name, column_name;

-- 結果3: 列ごとの値の種類
-- SQL Serverの文字列比較は、バイナリ照合順序でも末尾の空白を無視する。値の末尾に | を足して、空白まで区別する。
--   kinds_exact          : バイト単位で数えた種類
--   kinds_normalized     : Silver仕様の整形（NULL・空白を空文字にそろえ、前後の空白を除く）の後の種類
--   kinds_db_collation   : 整形の後に、データベースの照合順序で数えた種類
--   rows_collation_merged: 大文字小文字・全角半角などの違いだけで同じとみなされた値を持つ行
-- kinds_normalized が kinds_db_collation より多い列は、SQL Serverでの一致件数が再生で再現しない。
-- rows_other_space は全角空白やタブが前後に残る行で、TRIMの結果が製品ごとに変わる。
WITH src AS (
    SELECT 'V_T_OKS02' AS view_name, x.column_name, x.val
    FROM dbo.V_T_OKS02 AS o
    CROSS APPLY (VALUES
        ('company_cd',             CONVERT(nvarchar(3999), o.company_cd)             COLLATE Latin1_General_100_BIN2 + N'|'),
        ('user_id',                CONVERT(nvarchar(3999), o.user_id)                COLLATE Latin1_General_100_BIN2 + N'|'),
        ('wbs_cd',                 CONVERT(nvarchar(3999), o.wbs_cd)                 COLLATE Latin1_General_100_BIN2 + N'|'),
        ('opa_cd',                 CONVERT(nvarchar(3999), o.opa_cd)                 COLLATE Latin1_General_100_BIN2 + N'|'),
        ('genka_center_cd',        CONVERT(nvarchar(3999), o.genka_center_cd)        COLLATE Latin1_General_100_BIN2 + N'|'),
        ('katudo_type',            CONVERT(nvarchar(3999), o.katudo_type)            COLLATE Latin1_General_100_BIN2 + N'|'),
        ('kyotenbetu_bunseki_key', CONVERT(nvarchar(3999), o.kyotenbetu_bunseki_key) COLLATE Latin1_General_100_BIN2 + N'|'),
        ('mhi_wbs',                CONVERT(nvarchar(3999), o.mhi_wbs)                COLLATE Latin1_General_100_BIN2 + N'|'),
        ('shokushu_cd',            CONVERT(nvarchar(3999), o.shokushu_cd)            COLLATE Latin1_General_100_BIN2 + N'|'),
        ('keijo_genka_center_cd',  CONVERT(nvarchar(3999), o.keijo_genka_center_cd)  COLLATE Latin1_General_100_BIN2 + N'|'),
        ('youeki_cd',              CONVERT(nvarchar(3999), o.youeki_cd)              COLLATE Latin1_General_100_BIN2 + N'|')
    ) AS x (column_name, val)
    WHERE o.keijo_date >= @from AND o.keijo_date < @to
      AND (@company IS NULL OR o.company_cd = @company)
    UNION ALL
    SELECT 'V_T_OKS07', x.column_name, x.val
    FROM dbo.V_T_OKS07 AS o
    CROSS APPLY (VALUES
        ('company_cd',             CONVERT(nvarchar(3999), o.company_cd)             COLLATE Latin1_General_100_BIN2 + N'|'),
        ('user_id',                CONVERT(nvarchar(3999), o.user_id)                COLLATE Latin1_General_100_BIN2 + N'|'),
        ('wbs_cd',                 CONVERT(nvarchar(3999), o.wbs_cd)                 COLLATE Latin1_General_100_BIN2 + N'|'),
        ('opa_cd',                 CONVERT(nvarchar(3999), o.opa_cd)                 COLLATE Latin1_General_100_BIN2 + N'|'),
        ('genka_center_cd',        CONVERT(nvarchar(3999), o.genka_center_cd)        COLLATE Latin1_General_100_BIN2 + N'|'),
        ('katudo_type',            CONVERT(nvarchar(3999), o.katudo_type)            COLLATE Latin1_General_100_BIN2 + N'|'),
        ('kyotenbetu_bunseki_key', CONVERT(nvarchar(3999), o.kyotenbetu_bunseki_key) COLLATE Latin1_General_100_BIN2 + N'|'),
        ('mhi_wbs',                CONVERT(nvarchar(3999), o.mhi_wbs)                COLLATE Latin1_General_100_BIN2 + N'|'),
        ('shokushu_cd',            CONVERT(nvarchar(3999), o.shokushu_cd)            COLLATE Latin1_General_100_BIN2 + N'|'),
        ('keijo_genka_center_cd',  CONVERT(nvarchar(3999), o.keijo_genka_center_cd)  COLLATE Latin1_General_100_BIN2 + N'|'),
        ('youeki_cd',              CONVERT(nvarchar(3999), o.youeki_cd)              COLLATE Latin1_General_100_BIN2 + N'|')
    ) AS x (column_name, val)
    WHERE o.keijo_date >= @from AND o.keijo_date < @to
      AND (@company IS NULL OR o.company_cd = @company)
    UNION ALL
    SELECT 'V_T_OKS10', x.column_name, x.val
    FROM dbo.V_T_OKS10 AS o
    CROSS APPLY (VALUES
        ('company_cd',             CONVERT(nvarchar(3999), o.company_cd)             COLLATE Latin1_General_100_BIN2 + N'|'),
        ('user_id',                CONVERT(nvarchar(3999), o.user_id)                COLLATE Latin1_General_100_BIN2 + N'|'),
        ('wbs_cd',                 CONVERT(nvarchar(3999), o.wbs_cd)                 COLLATE Latin1_General_100_BIN2 + N'|'),
        ('opa_cd',                 CONVERT(nvarchar(3999), o.opa_cd)                 COLLATE Latin1_General_100_BIN2 + N'|'),
        ('genka_center_cd',        CONVERT(nvarchar(3999), o.genka_center_cd)        COLLATE Latin1_General_100_BIN2 + N'|'),
        ('katudo_type',            CONVERT(nvarchar(3999), o.katudo_type)            COLLATE Latin1_General_100_BIN2 + N'|'),
        ('kyotenbetu_bunseki_key', CONVERT(nvarchar(3999), o.kyotenbetu_bunseki_key) COLLATE Latin1_General_100_BIN2 + N'|'),
        ('mhi_wbs',                CONVERT(nvarchar(3999), o.mhi_wbs)                COLLATE Latin1_General_100_BIN2 + N'|'),
        ('shokushu_cd',            CONVERT(nvarchar(3999), o.shokushu_cd)            COLLATE Latin1_General_100_BIN2 + N'|'),
        ('keijo_genka_center_cd',  CONVERT(nvarchar(3999), o.keijo_genka_center_cd)  COLLATE Latin1_General_100_BIN2 + N'|'),
        ('youeki_cd',              CONVERT(nvarchar(3999), o.youeki_cd)              COLLATE Latin1_General_100_BIN2 + N'|')
    ) AS x (column_name, val)
    WHERE o.keijo_date >= @from AND o.keijo_date < @to
      AND (@company IS NULL OR o.company_cd = @company)
), g1 AS (
    SELECT view_name, column_name, val, COUNT_BIG(*) AS row_cnt
    FROM src
    GROUP BY view_name, column_name, val
), g2 AS (
    SELECT
        view_name, column_name, val, row_cnt, stripped,
        LTRIM(RTRIM(ISNULL(stripped, N''))) AS norm
    FROM (
        SELECT g1.*, LEFT(val, LEN(val) - 1) AS stripped
        FROM g1
    ) AS s
), g3 AS (
    SELECT
        view_name, column_name, norm,
        SUM(row_cnt) AS row_cnt,
        COUNT(*) AS exact_kinds,
        SUM(CASE WHEN val IS NULL THEN row_cnt ELSE 0 END) AS null_rows,
        SUM(CASE WHEN DATALENGTH(stripped) <> DATALENGTH(norm) THEN row_cnt ELSE 0 END) AS outer_space_rows
    FROM g2
    GROUP BY view_name, column_name, norm
), g4 AS (
    SELECT
        g3.*,
        COUNT(*) OVER (PARTITION BY view_name, column_name, norm COLLATE DATABASE_DEFAULT) AS db_variants
    FROM g3
)
SELECT
    view_name, column_name,
    SUM(row_cnt) AS row_cnt,
    SUM(CAST(exact_kinds AS bigint)) AS kinds_exact,
    COUNT(*) AS kinds_normalized,
    COUNT(DISTINCT norm COLLATE DATABASE_DEFAULT) AS kinds_db_collation,
    SUM(null_rows) AS rows_null,
    SUM(outer_space_rows) AS rows_outer_space,
    SUM(CASE WHEN db_variants > 1 THEN row_cnt ELSE 0 END) AS rows_collation_merged,
    SUM(CASE
            WHEN LEFT(norm, 1) IN (NCHAR(12288), NCHAR(9), NCHAR(160))
              OR RIGHT(norm, 1) IN (NCHAR(12288), NCHAR(9), NCHAR(160))
            THEN row_cnt ELSE 0
        END) AS rows_other_space
FROM g4
GROUP BY view_name, column_name
ORDER BY view_name, column_name
OPTION (RECOMPILE);
