-- V-05 OKS02の全列同一行
-- 目的: 全列が同じ行の件数を会社別に数える。全43列でGROUP BYするので重い。
-- 実行: SSMSで全体を1回実行する（GOなし、1バッチ）。読取のみで、データは変更しない。
-- 出力: 集計だけ。氏名・自由記述・ユーザIDは出さない。ラベルは英数字。
-- 詳細: tools/update-method-simulation/README.md

USE GEMS_DM_S;
SET NOCOUNT ON;

-- 対象範囲（keijo_dateはyyyymmddの文字列。@toは含まない）。@companyをNULLにすると全社。
DECLARE @from varchar(8) = '20260401';
DECLARE @to   varchar(8) = '20261101';
DECLARE @company nvarchar(3) = NULL;

-- 全43列が同じ行のかたまりを数える。insert_dateも比較に含むので、同じ保存の中の重複だけが残る。
-- excess_rows・excess_hours は、1行にまとめたときに減る行数と工数。
WITH g AS (
    SELECT
        company_cd, user_id, keijo_date, machine_flg, keijo_kosu,
        COUNT(*) AS same_rows
    FROM dbo.V_T_OKS02
    WHERE keijo_date >= @from AND keijo_date < @to
      AND (@company IS NULL OR company_cd = @company)
    GROUP BY
        company_cd,
        keijo_date,
        user_id,
        mhi_emp_no,
        sei_mei,
        shozoku_cd,
        shozoku_name,
        keijo_genka_center_cd,
        keijo_genka_center_name,
        wbs_cd,
        wbs_name,
        opa_cd,
        opa_name,
        genka_center_cd,
        genka_center_name,
        katudo_type,
        katudo_type_name,
        mhi_wbs,
        mhi_wbs_name,
        kyotenbetu_bunseki_key,
        youeki_cd,
        shokushu_cd,
        keijo_kosu,
        text_item01,
        text_item02,
        text_item03,
        text_item04,
        text_item05,
        text_item06,
        text_item07,
        text_item08,
        text_item09,
        text_item10,
        shusei_flg,
        shusei_riyu,
        status,
        if_status,
        shuusei_siji,
        insert_user,
        insert_date,
        update_user,
        update_date,
        machine_flg
    HAVING COUNT(*) > 1
)
SELECT
    company_cd, machine_flg, LEFT(keijo_date, 6) AS keijo_month,
    COUNT(*) AS duplicate_groups,
    SUM(same_rows) AS duplicate_rows,
    SUM(same_rows - 1) AS excess_rows,
    SUM((same_rows - 1) * keijo_kosu) AS excess_hours,
    COUNT(DISTINCT CONCAT(company_cd, '|', user_id, '|', keijo_date)) AS shain_days,
    MAX(same_rows) AS max_same_rows
FROM g
GROUP BY company_cd, machine_flg, LEFT(keijo_date, 6)
ORDER BY company_cd, machine_flg, keijo_month
OPTION (RECOMPILE);
