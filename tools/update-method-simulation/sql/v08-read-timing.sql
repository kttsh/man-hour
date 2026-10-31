-- V-08 全行読取の実行時間
-- 目的: 月単位の全行読取がどれだけかかるかを測り、ツールの分割単位を決める。
-- 実行: SSMSで全体を1回実行する（GOなし、1バッチ）。読取のみで、データは変更しない。
-- 出力: 集計だけ。氏名・自由記述・ユーザIDは出さない。ラベルは英数字。
-- 詳細: tools/update-method-simulation/README.md

USE GEMS_DM_S;
SET NOCOUNT ON;

-- 新しい月から順に読み、@budget_seconds を超えたら次の月に進まず止める。
-- 全列のバイト数を足すので、ビューの全列が実際に読まれる。CSV出力や転送の時間は含まない。
-- 進み具合はSSMSの「メッセージ」タブに出る。
DECLARE @first_month date = '20260401';
DECLARE @last_month  date = '20261001';
DECLARE @budget_seconds int = 1800;

DECLARE @started datetime2 = SYSUTCDATETIME();
DECLARE @d date = @last_month;
DECLARE @t0 datetime2;
DECLARE @m char(6), @lo varchar(8), @hi varchar(8), @msg varchar(100);

CREATE TABLE #timing (
    view_name sysname NOT NULL,
    keijo_month char(6) NOT NULL,
    row_cnt bigint NULL,
    bytes_sum bigint NULL,
    seconds_taken decimal(12, 1) NULL
);

WHILE @d >= @first_month
BEGIN
    IF DATEDIFF(SECOND, @started, SYSUTCDATETIME()) > @budget_seconds
    BEGIN
        RAISERROR('budget exceeded: stopped before next month', 0, 1) WITH NOWAIT;
        BREAK;
    END;

    SET @m  = CONVERT(char(6), @d, 112);
    SET @lo = @m + '01';
    SET @hi = CONVERT(char(6), DATEADD(MONTH, 1, @d), 112) + '01';
    SET @msg = 'reading ' + @m;
    RAISERROR(@msg, 0, 1) WITH NOWAIT;

        SET @t0 = SYSUTCDATETIME();
        INSERT INTO #timing (view_name, keijo_month, row_cnt, bytes_sum)
        SELECT 'V_T_OKS02', @m, COUNT_BIG(*),
              SUM(CAST(ISNULL(DATALENGTH(company_cd), 0) AS bigint)
                  + ISNULL(DATALENGTH(keijo_date), 0)
                  + ISNULL(DATALENGTH(user_id), 0)
                  + ISNULL(DATALENGTH(mhi_emp_no), 0)
                  + ISNULL(DATALENGTH(sei_mei), 0)
                  + ISNULL(DATALENGTH(shozoku_cd), 0)
                  + ISNULL(DATALENGTH(shozoku_name), 0)
                  + ISNULL(DATALENGTH(keijo_genka_center_cd), 0)
                  + ISNULL(DATALENGTH(keijo_genka_center_name), 0)
                  + ISNULL(DATALENGTH(wbs_cd), 0)
                  + ISNULL(DATALENGTH(wbs_name), 0)
                  + ISNULL(DATALENGTH(opa_cd), 0)
                  + ISNULL(DATALENGTH(opa_name), 0)
                  + ISNULL(DATALENGTH(genka_center_cd), 0)
                  + ISNULL(DATALENGTH(genka_center_name), 0)
                  + ISNULL(DATALENGTH(katudo_type), 0)
                  + ISNULL(DATALENGTH(katudo_type_name), 0)
                  + ISNULL(DATALENGTH(mhi_wbs), 0)
                  + ISNULL(DATALENGTH(mhi_wbs_name), 0)
                  + ISNULL(DATALENGTH(kyotenbetu_bunseki_key), 0)
                  + ISNULL(DATALENGTH(youeki_cd), 0)
                  + ISNULL(DATALENGTH(shokushu_cd), 0)
                  + ISNULL(DATALENGTH(keijo_kosu), 0)
                  + ISNULL(DATALENGTH(text_item01), 0)
                  + ISNULL(DATALENGTH(text_item02), 0)
                  + ISNULL(DATALENGTH(text_item03), 0)
                  + ISNULL(DATALENGTH(text_item04), 0)
                  + ISNULL(DATALENGTH(text_item05), 0)
                  + ISNULL(DATALENGTH(text_item06), 0)
                  + ISNULL(DATALENGTH(text_item07), 0)
                  + ISNULL(DATALENGTH(text_item08), 0)
                  + ISNULL(DATALENGTH(text_item09), 0)
                  + ISNULL(DATALENGTH(text_item10), 0)
                  + ISNULL(DATALENGTH(shusei_flg), 0)
                  + ISNULL(DATALENGTH(shusei_riyu), 0)
                  + ISNULL(DATALENGTH(status), 0)
                  + ISNULL(DATALENGTH(if_status), 0)
                  + ISNULL(DATALENGTH(shuusei_siji), 0)
                  + ISNULL(DATALENGTH(insert_user), 0)
                  + ISNULL(DATALENGTH(insert_date), 0)
                  + ISNULL(DATALENGTH(update_user), 0)
                  + ISNULL(DATALENGTH(update_date), 0)
                  + ISNULL(DATALENGTH(machine_flg), 0)
              )
        FROM dbo.V_T_OKS02
        WHERE keijo_date >= @lo AND keijo_date < @hi;
        UPDATE #timing SET seconds_taken = DATEDIFF(MILLISECOND, @t0, SYSUTCDATETIME()) / 1000.0
        WHERE view_name = 'V_T_OKS02' AND keijo_month = @m;

        SET @t0 = SYSUTCDATETIME();
        INSERT INTO #timing (view_name, keijo_month, row_cnt, bytes_sum)
        SELECT 'V_T_OKS07', @m, COUNT_BIG(*),
              SUM(CAST(ISNULL(DATALENGTH(company_cd), 0) AS bigint)
                  + ISNULL(DATALENGTH(keijo_date), 0)
                  + ISNULL(DATALENGTH(shozoku_cd), 0)
                  + ISNULL(DATALENGTH(shozoku_name), 0)
                  + ISNULL(DATALENGTH(mhi_emp_no), 0)
                  + ISNULL(DATALENGTH(machine_flg), 0)
                  + ISNULL(DATALENGTH(user_id), 0)
                  + ISNULL(DATALENGTH(sei_mei), 0)
                  + ISNULL(DATALENGTH(correction_kbn), 0)
                  + ISNULL(DATALENGTH(correction_num), 0)
                  + ISNULL(DATALENGTH(keijo_genka_center_cd), 0)
                  + ISNULL(DATALENGTH(keijo_genka_center_name), 0)
                  + ISNULL(DATALENGTH(wbs_cd), 0)
                  + ISNULL(DATALENGTH(wbs_name), 0)
                  + ISNULL(DATALENGTH(others_wbs), 0)
                  + ISNULL(DATALENGTH(opa_cd), 0)
                  + ISNULL(DATALENGTH(opa_name), 0)
                  + ISNULL(DATALENGTH(sashizu), 0)
                  + ISNULL(DATALENGTH(genka_center_cd), 0)
                  + ISNULL(DATALENGTH(genka_center_name), 0)
                  + ISNULL(DATALENGTH(katudo_type), 0)
                  + ISNULL(DATALENGTH(katudo_type_name), 0)
                  + ISNULL(DATALENGTH(mhi_wbs), 0)
                  + ISNULL(DATALENGTH(mhi_wbs_name), 0)
                  + ISNULL(DATALENGTH(kyotenbetu_bunseki_key), 0)
                  + ISNULL(DATALENGTH(youeki_cd), 0)
                  + ISNULL(DATALENGTH(shokushu_cd), 0)
                  + ISNULL(DATALENGTH(keijo_kosu), 0)
                  + ISNULL(DATALENGTH(shusei_mae_kosu), 0)
                  + ISNULL(DATALENGTH(correction_user_id), 0)
                  + ISNULL(DATALENGTH(correction_user_name), 0)
                  + ISNULL(DATALENGTH(correction_date), 0)
                  + ISNULL(DATALENGTH(shonin_user_id), 0)
                  + ISNULL(DATALENGTH(shonin_user_name), 0)
                  + ISNULL(DATALENGTH(shonin_date), 0)
                  + ISNULL(DATALENGTH(keiri_shonin_user_id), 0)
                  + ISNULL(DATALENGTH(keiri_shonin_user_name), 0)
                  + ISNULL(DATALENGTH(keiri_shonin_date), 0)
                  + ISNULL(DATALENGTH(kakutei_user_id), 0)
                  + ISNULL(DATALENGTH(kakutei_user_name), 0)
                  + ISNULL(DATALENGTH(kakutei_date), 0)
                  + ISNULL(DATALENGTH(simekiri_user_id), 0)
                  + ISNULL(DATALENGTH(simekiri_user_name), 0)
                  + ISNULL(DATALENGTH(simekiri_date), 0)
                  + ISNULL(DATALENGTH(keiri_setuzoku_user_id), 0)
                  + ISNULL(DATALENGTH(keiri_setuzoku_user_name), 0)
                  + ISNULL(DATALENGTH(keiri_setuzoku_date), 0)
                  + ISNULL(DATALENGTH(text_item01), 0)
                  + ISNULL(DATALENGTH(text_item02), 0)
                  + ISNULL(DATALENGTH(text_item03), 0)
                  + ISNULL(DATALENGTH(text_item04), 0)
                  + ISNULL(DATALENGTH(text_item05), 0)
                  + ISNULL(DATALENGTH(text_item06), 0)
                  + ISNULL(DATALENGTH(text_item07), 0)
                  + ISNULL(DATALENGTH(text_item08), 0)
                  + ISNULL(DATALENGTH(text_item09), 0)
                  + ISNULL(DATALENGTH(text_item10), 0)
                  + ISNULL(DATALENGTH(shusei_flg), 0)
                  + ISNULL(DATALENGTH(shusei_riyu), 0)
                  + ISNULL(DATALENGTH(status), 0)
                  + ISNULL(DATALENGTH(if_status), 0)
                  + ISNULL(DATALENGTH(shuusei_siji), 0)
                  + ISNULL(DATALENGTH(insert_user), 0)
                  + ISNULL(DATALENGTH(insert_date), 0)
                  + ISNULL(DATALENGTH(update_user), 0)
                  + ISNULL(DATALENGTH(update_date), 0)
              )
        FROM dbo.V_T_OKS07
        WHERE keijo_date >= @lo AND keijo_date < @hi;
        UPDATE #timing SET seconds_taken = DATEDIFF(MILLISECOND, @t0, SYSUTCDATETIME()) / 1000.0
        WHERE view_name = 'V_T_OKS07' AND keijo_month = @m;

        SET @t0 = SYSUTCDATETIME();
        INSERT INTO #timing (view_name, keijo_month, row_cnt, bytes_sum)
        SELECT 'V_T_OKS10', @m, COUNT_BIG(*),
              SUM(CAST(ISNULL(DATALENGTH(hnko_rireki_id), 0) AS bigint)
                  + ISNULL(DATALENGTH(company_cd), 0)
                  + ISNULL(DATALENGTH(keijo_date), 0)
                  + ISNULL(DATALENGTH(shozoku_cd), 0)
                  + ISNULL(DATALENGTH(shozoku_name), 0)
                  + ISNULL(DATALENGTH(mhi_emp_no), 0)
                  + ISNULL(DATALENGTH(user_id), 0)
                  + ISNULL(DATALENGTH(sei_mei), 0)
                  + ISNULL(DATALENGTH(keijo_genka_center_cd), 0)
                  + ISNULL(DATALENGTH(keijo_genka_center_name), 0)
                  + ISNULL(DATALENGTH(wbs_cd), 0)
                  + ISNULL(DATALENGTH(wbs_name), 0)
                  + ISNULL(DATALENGTH(others_wbs), 0)
                  + ISNULL(DATALENGTH(opa_cd), 0)
                  + ISNULL(DATALENGTH(opa_name), 0)
                  + ISNULL(DATALENGTH(sashizu), 0)
                  + ISNULL(DATALENGTH(genka_center_cd), 0)
                  + ISNULL(DATALENGTH(genka_center_name), 0)
                  + ISNULL(DATALENGTH(katudo_type), 0)
                  + ISNULL(DATALENGTH(katudo_type_name), 0)
                  + ISNULL(DATALENGTH(mhi_wbs), 0)
                  + ISNULL(DATALENGTH(mhi_wbs_name), 0)
                  + ISNULL(DATALENGTH(kyotenbetu_bunseki_key), 0)
                  + ISNULL(DATALENGTH(youeki_cd), 0)
                  + ISNULL(DATALENGTH(shokushu_cd), 0)
                  + ISNULL(DATALENGTH(keijo_kosu), 0)
                  + ISNULL(DATALENGTH(text_item01), 0)
                  + ISNULL(DATALENGTH(text_item02), 0)
                  + ISNULL(DATALENGTH(text_item03), 0)
                  + ISNULL(DATALENGTH(text_item04), 0)
                  + ISNULL(DATALENGTH(text_item05), 0)
                  + ISNULL(DATALENGTH(text_item06), 0)
                  + ISNULL(DATALENGTH(text_item07), 0)
                  + ISNULL(DATALENGTH(text_item08), 0)
                  + ISNULL(DATALENGTH(text_item09), 0)
                  + ISNULL(DATALENGTH(text_item10), 0)
                  + ISNULL(DATALENGTH(shusei_flg), 0)
                  + ISNULL(DATALENGTH(shusei_riyu), 0)
                  + ISNULL(DATALENGTH(status), 0)
                  + ISNULL(DATALENGTH(if_status), 0)
                  + ISNULL(DATALENGTH(shuusei_siji), 0)
                  + ISNULL(DATALENGTH(shusei_dt), 0)
                  + ISNULL(DATALENGTH(shusei_kbn), 0)
                  + ISNULL(DATALENGTH(update_user_id), 0)
                  + ISNULL(DATALENGTH(update_sei_mei), 0)
                  + ISNULL(DATALENGTH(insert_user), 0)
                  + ISNULL(DATALENGTH(insert_date), 0)
                  + ISNULL(DATALENGTH(update_user), 0)
                  + ISNULL(DATALENGTH(update_date), 0)
                  + ISNULL(DATALENGTH(machine_flg), 0)
              )
        FROM dbo.V_T_OKS10
        WHERE keijo_date >= @lo AND keijo_date < @hi;
        UPDATE #timing SET seconds_taken = DATEDIFF(MILLISECOND, @t0, SYSUTCDATETIME()) / 1000.0
        WHERE view_name = 'V_T_OKS10' AND keijo_month = @m;

    SET @d = DATEADD(MONTH, -1, @d);
END;

SELECT
    view_name, keijo_month, row_cnt, bytes_sum, seconds_taken,
    CAST(bytes_sum AS decimal(20, 1)) / NULLIF(row_cnt, 0) AS sqlserver_bytes_per_row
FROM #timing
ORDER BY view_name, keijo_month;

DROP TABLE #timing;
