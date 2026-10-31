-- V-07 OKS02の1行の実バイト数
-- 目的: 費用の試算に使う実際の行幅を列ごとに測る。全列を読むので、まず1か月で実行する。
-- 実行: SSMSで全体を1回実行する（GOなし、1バッチ）。読取のみで、データは変更しない。
-- 出力: 集計だけ。氏名・自由記述・ユーザIDは出さない。ラベルは英数字。
-- 詳細: tools/update-method-simulation/README.md

USE GEMS_DM_S;
SET NOCOUNT ON;

-- 対象範囲（keijo_dateはyyyymmddの文字列。@toは含まない）。@companyをNULLにすると全社。
DECLARE @from varchar(8) = '20260901';
DECLARE @to   varchar(8) = '20261001';
DECLARE @company nvarchar(3) = NULL;

-- sqlserver_bytes : SQL Server上のバイト数（nvarcharは文字数の2倍）
-- csv_bytes_upper : UTF-8のCSVにしたときの上限の目安。非ASCIIを含む値は1文字3バイト、それ以外は1文字1バイトで数える。
--                   datetimeは23文字（yyyy-mm-dd hh:mm:ss.nnn）で数える。
-- row_bytes_upper_avg : 全列を足した1行あたりの平均。CSVの区切りと改行は含まない。
WITH c AS (
    SELECT
        v.column_name, v.data_type,
        COUNT_BIG(*) AS rows_total,
        SUM(CASE WHEN v.bytes IS NULL THEN 1 ELSE 0 END) AS null_rows,
        SUM(CASE WHEN v.chars = 0 THEN 1 ELSE 0 END) AS empty_rows,
        SUM(CAST(v.bytes AS bigint)) AS sqlserver_bytes,
        SUM(CAST(v.chars AS bigint)) AS total_chars,
        MAX(v.chars) AS max_chars,
        SUM(CAST(CASE WHEN v.non_ascii = 1 THEN v.chars * 3 ELSE v.chars END AS bigint)) AS csv_bytes_upper
    FROM dbo.V_T_OKS02 AS t
    CROSS APPLY (VALUES
        ('company_cd', 'nvarchar', DATALENGTH(company_cd), LEN(company_cd), CASE WHEN CAST(company_cd AS nvarchar(max)) COLLATE Latin1_General_BIN LIKE N'%[^ -~]%' THEN 1 ELSE 0 END),
        ('keijo_date', 'varchar', DATALENGTH(keijo_date), LEN(keijo_date), CASE WHEN CAST(keijo_date AS nvarchar(max)) COLLATE Latin1_General_BIN LIKE N'%[^ -~]%' THEN 1 ELSE 0 END),
        ('user_id', 'varchar', DATALENGTH(user_id), LEN(user_id), CASE WHEN CAST(user_id AS nvarchar(max)) COLLATE Latin1_General_BIN LIKE N'%[^ -~]%' THEN 1 ELSE 0 END),
        ('mhi_emp_no', 'varchar', DATALENGTH(mhi_emp_no), LEN(mhi_emp_no), CASE WHEN CAST(mhi_emp_no AS nvarchar(max)) COLLATE Latin1_General_BIN LIKE N'%[^ -~]%' THEN 1 ELSE 0 END),
        ('sei_mei', 'nvarchar', DATALENGTH(sei_mei), LEN(sei_mei), CASE WHEN CAST(sei_mei AS nvarchar(max)) COLLATE Latin1_General_BIN LIKE N'%[^ -~]%' THEN 1 ELSE 0 END),
        ('shozoku_cd', 'varchar', DATALENGTH(shozoku_cd), LEN(shozoku_cd), CASE WHEN CAST(shozoku_cd AS nvarchar(max)) COLLATE Latin1_General_BIN LIKE N'%[^ -~]%' THEN 1 ELSE 0 END),
        ('shozoku_name', 'nvarchar', DATALENGTH(shozoku_name), LEN(shozoku_name), CASE WHEN CAST(shozoku_name AS nvarchar(max)) COLLATE Latin1_General_BIN LIKE N'%[^ -~]%' THEN 1 ELSE 0 END),
        ('keijo_genka_center_cd', 'nvarchar', DATALENGTH(keijo_genka_center_cd), LEN(keijo_genka_center_cd), CASE WHEN CAST(keijo_genka_center_cd AS nvarchar(max)) COLLATE Latin1_General_BIN LIKE N'%[^ -~]%' THEN 1 ELSE 0 END),
        ('keijo_genka_center_name', 'nvarchar', DATALENGTH(keijo_genka_center_name), LEN(keijo_genka_center_name), CASE WHEN CAST(keijo_genka_center_name AS nvarchar(max)) COLLATE Latin1_General_BIN LIKE N'%[^ -~]%' THEN 1 ELSE 0 END),
        ('wbs_cd', 'nvarchar', DATALENGTH(wbs_cd), LEN(wbs_cd), CASE WHEN CAST(wbs_cd AS nvarchar(max)) COLLATE Latin1_General_BIN LIKE N'%[^ -~]%' THEN 1 ELSE 0 END),
        ('wbs_name', 'nvarchar', DATALENGTH(wbs_name), LEN(wbs_name), CASE WHEN CAST(wbs_name AS nvarchar(max)) COLLATE Latin1_General_BIN LIKE N'%[^ -~]%' THEN 1 ELSE 0 END),
        ('opa_cd', 'nvarchar', DATALENGTH(opa_cd), LEN(opa_cd), CASE WHEN CAST(opa_cd AS nvarchar(max)) COLLATE Latin1_General_BIN LIKE N'%[^ -~]%' THEN 1 ELSE 0 END),
        ('opa_name', 'nvarchar', DATALENGTH(opa_name), LEN(opa_name), CASE WHEN CAST(opa_name AS nvarchar(max)) COLLATE Latin1_General_BIN LIKE N'%[^ -~]%' THEN 1 ELSE 0 END),
        ('genka_center_cd', 'nvarchar', DATALENGTH(genka_center_cd), LEN(genka_center_cd), CASE WHEN CAST(genka_center_cd AS nvarchar(max)) COLLATE Latin1_General_BIN LIKE N'%[^ -~]%' THEN 1 ELSE 0 END),
        ('genka_center_name', 'nvarchar', DATALENGTH(genka_center_name), LEN(genka_center_name), CASE WHEN CAST(genka_center_name AS nvarchar(max)) COLLATE Latin1_General_BIN LIKE N'%[^ -~]%' THEN 1 ELSE 0 END),
        ('katudo_type', 'varchar', DATALENGTH(katudo_type), LEN(katudo_type), CASE WHEN CAST(katudo_type AS nvarchar(max)) COLLATE Latin1_General_BIN LIKE N'%[^ -~]%' THEN 1 ELSE 0 END),
        ('katudo_type_name', 'nvarchar', DATALENGTH(katudo_type_name), LEN(katudo_type_name), CASE WHEN CAST(katudo_type_name AS nvarchar(max)) COLLATE Latin1_General_BIN LIKE N'%[^ -~]%' THEN 1 ELSE 0 END),
        ('mhi_wbs', 'varchar', DATALENGTH(mhi_wbs), LEN(mhi_wbs), CASE WHEN CAST(mhi_wbs AS nvarchar(max)) COLLATE Latin1_General_BIN LIKE N'%[^ -~]%' THEN 1 ELSE 0 END),
        ('mhi_wbs_name', 'nvarchar', DATALENGTH(mhi_wbs_name), LEN(mhi_wbs_name), CASE WHEN CAST(mhi_wbs_name AS nvarchar(max)) COLLATE Latin1_General_BIN LIKE N'%[^ -~]%' THEN 1 ELSE 0 END),
        ('kyotenbetu_bunseki_key', 'varchar', DATALENGTH(kyotenbetu_bunseki_key), LEN(kyotenbetu_bunseki_key), CASE WHEN CAST(kyotenbetu_bunseki_key AS nvarchar(max)) COLLATE Latin1_General_BIN LIKE N'%[^ -~]%' THEN 1 ELSE 0 END),
        ('youeki_cd', 'varchar', DATALENGTH(youeki_cd), LEN(youeki_cd), CASE WHEN CAST(youeki_cd AS nvarchar(max)) COLLATE Latin1_General_BIN LIKE N'%[^ -~]%' THEN 1 ELSE 0 END),
        ('shokushu_cd', 'varchar', DATALENGTH(shokushu_cd), LEN(shokushu_cd), CASE WHEN CAST(shokushu_cd AS nvarchar(max)) COLLATE Latin1_General_BIN LIKE N'%[^ -~]%' THEN 1 ELSE 0 END),
        ('keijo_kosu', 'decimal', DATALENGTH(keijo_kosu), LEN(CONVERT(varchar(20), keijo_kosu)), 0),
        ('text_item01', 'nvarchar', DATALENGTH(text_item01), LEN(text_item01), CASE WHEN CAST(text_item01 AS nvarchar(max)) COLLATE Latin1_General_BIN LIKE N'%[^ -~]%' THEN 1 ELSE 0 END),
        ('text_item02', 'nvarchar', DATALENGTH(text_item02), LEN(text_item02), CASE WHEN CAST(text_item02 AS nvarchar(max)) COLLATE Latin1_General_BIN LIKE N'%[^ -~]%' THEN 1 ELSE 0 END),
        ('text_item03', 'nvarchar', DATALENGTH(text_item03), LEN(text_item03), CASE WHEN CAST(text_item03 AS nvarchar(max)) COLLATE Latin1_General_BIN LIKE N'%[^ -~]%' THEN 1 ELSE 0 END),
        ('text_item04', 'nvarchar', DATALENGTH(text_item04), LEN(text_item04), CASE WHEN CAST(text_item04 AS nvarchar(max)) COLLATE Latin1_General_BIN LIKE N'%[^ -~]%' THEN 1 ELSE 0 END),
        ('text_item05', 'nvarchar', DATALENGTH(text_item05), LEN(text_item05), CASE WHEN CAST(text_item05 AS nvarchar(max)) COLLATE Latin1_General_BIN LIKE N'%[^ -~]%' THEN 1 ELSE 0 END),
        ('text_item06', 'nvarchar', DATALENGTH(text_item06), LEN(text_item06), CASE WHEN CAST(text_item06 AS nvarchar(max)) COLLATE Latin1_General_BIN LIKE N'%[^ -~]%' THEN 1 ELSE 0 END),
        ('text_item07', 'nvarchar', DATALENGTH(text_item07), LEN(text_item07), CASE WHEN CAST(text_item07 AS nvarchar(max)) COLLATE Latin1_General_BIN LIKE N'%[^ -~]%' THEN 1 ELSE 0 END),
        ('text_item08', 'nvarchar', DATALENGTH(text_item08), LEN(text_item08), CASE WHEN CAST(text_item08 AS nvarchar(max)) COLLATE Latin1_General_BIN LIKE N'%[^ -~]%' THEN 1 ELSE 0 END),
        ('text_item09', 'nvarchar', DATALENGTH(text_item09), LEN(text_item09), CASE WHEN CAST(text_item09 AS nvarchar(max)) COLLATE Latin1_General_BIN LIKE N'%[^ -~]%' THEN 1 ELSE 0 END),
        ('text_item10', 'nvarchar', DATALENGTH(text_item10), LEN(text_item10), CASE WHEN CAST(text_item10 AS nvarchar(max)) COLLATE Latin1_General_BIN LIKE N'%[^ -~]%' THEN 1 ELSE 0 END),
        ('shusei_flg', 'varchar', DATALENGTH(shusei_flg), LEN(shusei_flg), CASE WHEN CAST(shusei_flg AS nvarchar(max)) COLLATE Latin1_General_BIN LIKE N'%[^ -~]%' THEN 1 ELSE 0 END),
        ('shusei_riyu', 'nvarchar', DATALENGTH(shusei_riyu), LEN(shusei_riyu), CASE WHEN CAST(shusei_riyu AS nvarchar(max)) COLLATE Latin1_General_BIN LIKE N'%[^ -~]%' THEN 1 ELSE 0 END),
        ('status', 'varchar', DATALENGTH(status), LEN(status), CASE WHEN CAST(status AS nvarchar(max)) COLLATE Latin1_General_BIN LIKE N'%[^ -~]%' THEN 1 ELSE 0 END),
        ('if_status', 'varchar', DATALENGTH(if_status), LEN(if_status), CASE WHEN CAST(if_status AS nvarchar(max)) COLLATE Latin1_General_BIN LIKE N'%[^ -~]%' THEN 1 ELSE 0 END),
        ('shuusei_siji', 'nvarchar', DATALENGTH(shuusei_siji), LEN(shuusei_siji), CASE WHEN CAST(shuusei_siji AS nvarchar(max)) COLLATE Latin1_General_BIN LIKE N'%[^ -~]%' THEN 1 ELSE 0 END),
        ('insert_user', 'nvarchar', DATALENGTH(insert_user), LEN(insert_user), CASE WHEN CAST(insert_user AS nvarchar(max)) COLLATE Latin1_General_BIN LIKE N'%[^ -~]%' THEN 1 ELSE 0 END),
        ('insert_date', 'datetime', DATALENGTH(insert_date), CASE WHEN insert_date IS NULL THEN NULL ELSE 23 END, 0),
        ('update_user', 'nvarchar', DATALENGTH(update_user), LEN(update_user), CASE WHEN CAST(update_user AS nvarchar(max)) COLLATE Latin1_General_BIN LIKE N'%[^ -~]%' THEN 1 ELSE 0 END),
        ('update_date', 'datetime', DATALENGTH(update_date), CASE WHEN update_date IS NULL THEN NULL ELSE 23 END, 0),
        ('machine_flg', 'varchar', DATALENGTH(machine_flg), LEN(machine_flg), CASE WHEN CAST(machine_flg AS nvarchar(max)) COLLATE Latin1_General_BIN LIKE N'%[^ -~]%' THEN 1 ELSE 0 END)
    ) AS v(column_name, data_type, bytes, chars, non_ascii)
    WHERE t.keijo_date >= @from AND t.keijo_date < @to
      AND (@company IS NULL OR t.company_cd = @company)
    GROUP BY v.column_name, v.data_type
)
SELECT
    c.*,
    CAST(SUM(csv_bytes_upper) OVER () AS decimal(20, 1)) / NULLIF(rows_total, 0) AS row_bytes_upper_avg
FROM c
ORDER BY csv_bytes_upper DESC
OPTION (RECOMPILE);
