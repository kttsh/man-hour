-- V-09 OKS07の修正がOKS02の明細に当たるか
-- 目的: ADR-003の前提2を確かめる。これまでの照合相手はOKS10から作った状態で、OKS02では未確認。
-- 実行: SSMSで全体を1回実行する（GOなし、1バッチ）。読取のみで、ビューは変更しない。一時テーブルを使う。
-- 出力: 集計だけ。氏名・自由記述・ユーザIDは出さない。ラベルは英数字。
-- 詳細: tools/update-method-simulation/README.md

USE GEMS_DM_S;
SET NOCOUNT ON;

-- 対象範囲（keijo_dateはyyyymmddの文字列。@toは含まない）。@companyをNULLにすると全社。
DECLARE @from varchar(8) = '20230101';
DECLARE @to   varchar(8) = '20261101';
DECLARE @company nvarchar(3) = NULL;

IF OBJECT_ID('tempdb..#c') IS NOT NULL DROP TABLE #c;
IF OBJECT_ID('tempdb..#b') IS NOT NULL DROP TABLE #b;

-- 照合キー9列は、Silver仕様のとおり NULL・空白を空文字にそろえ、前後の空白を除いて比べる。
SELECT
    company_cd, user_id, keijo_date, correction_kbn, shusei_mae_kosu, keijo_kosu,
    TRY_CONVERT(int, correction_num) AS correction_no,
    CASE
        WHEN status IN ('4','5','6','7') THEN 'APPROVED'
        WHEN status IN ('1','2','3')     THEN 'PENDING'
        ELSE 'OTHER_VALUE'
    END AS status_group,
    LTRIM(RTRIM(ISNULL(wbs_cd, '')))                 AS k_wbs,
    LTRIM(RTRIM(ISNULL(opa_cd, '')))                 AS k_opa,
    LTRIM(RTRIM(ISNULL(genka_center_cd, '')))        AS k_gc,
    LTRIM(RTRIM(ISNULL(katudo_type, '')))            AS k_kt,
    LTRIM(RTRIM(ISNULL(kyotenbetu_bunseki_key, ''))) AS k_kbk,
    LTRIM(RTRIM(ISNULL(mhi_wbs, '')))                AS k_mw,
    LTRIM(RTRIM(ISNULL(shokushu_cd, '')))            AS k_sk,
    LTRIM(RTRIM(ISNULL(keijo_genka_center_cd, '')))  AS k_kgc,
    LTRIM(RTRIM(ISNULL(youeki_cd, '')))              AS k_yo
INTO #c
FROM dbo.V_T_OKS07
WHERE keijo_date >= @from AND keijo_date < @to
  AND (@company IS NULL OR company_cd = @company);

-- OKS02は修正がある社員日だけ読む。
SELECT
    o.company_cd, o.user_id, o.keijo_date, o.keijo_kosu,
    LTRIM(RTRIM(ISNULL(o.wbs_cd, '')))                 AS k_wbs,
    LTRIM(RTRIM(ISNULL(o.opa_cd, '')))                 AS k_opa,
    LTRIM(RTRIM(ISNULL(o.genka_center_cd, '')))        AS k_gc,
    LTRIM(RTRIM(ISNULL(o.katudo_type, '')))            AS k_kt,
    LTRIM(RTRIM(ISNULL(o.kyotenbetu_bunseki_key, ''))) AS k_kbk,
    LTRIM(RTRIM(ISNULL(o.mhi_wbs, '')))                AS k_mw,
    LTRIM(RTRIM(ISNULL(o.shokushu_cd, '')))            AS k_sk,
    LTRIM(RTRIM(ISNULL(o.keijo_genka_center_cd, '')))  AS k_kgc,
    LTRIM(RTRIM(ISNULL(o.youeki_cd, '')))              AS k_yo
INTO #b
FROM dbo.V_T_OKS02 AS o
WHERE o.keijo_date >= @from AND o.keijo_date < @to
  AND EXISTS (
      SELECT 1 FROM #c AS c
      WHERE c.company_cd = o.company_cd AND c.user_id = o.user_id AND c.keijo_date = o.keijo_date
  )
OPTION (RECOMPILE);

-- 修正の行ごとに社員日の明細を探すので、社員日で引けるようにする。
CREATE CLUSTERED INDEX ix_b ON #b (company_cd, user_id, keijo_date);

-- match_kind : MATCH9 が修正の当たり先。NO_BASE_7COL・NO_OKS02_DAY は明細の追加なら正常。
--              KEIJO_GC_DIFF・YOUEKI_DIFF・HIT_MULTI_ROW は0件の見込み。
-- pre_check  : 明細ごとの最初の修正で、修正前工数とOKS02の工数を比べる。
-- post_check : 明細ごとの最後の修正で、OKS02が修正後の値になっているかを見る。
WITH h AS (
    SELECT
        c.*,
        d.day_rows, n9.rows9, n9.hours9, n8.rows8, n7.rows7,
        ROW_NUMBER() OVER (
            PARTITION BY c.company_cd, c.user_id, c.keijo_date,
                         c.k_wbs, c.k_opa, c.k_gc, c.k_kt, c.k_kbk, c.k_mw, c.k_sk, c.k_kgc, c.k_yo
            ORDER BY c.correction_no) AS first_rn,
        ROW_NUMBER() OVER (
            PARTITION BY c.company_cd, c.user_id, c.keijo_date,
                         c.k_wbs, c.k_opa, c.k_gc, c.k_kt, c.k_kbk, c.k_mw, c.k_sk, c.k_kgc, c.k_yo
            ORDER BY c.correction_no DESC) AS last_rn
    FROM #c AS c
    OUTER APPLY (
        SELECT COUNT(*) AS day_rows FROM #b AS b
        WHERE b.company_cd = c.company_cd AND b.user_id = c.user_id AND b.keijo_date = c.keijo_date
    ) AS d
    OUTER APPLY (
        SELECT COUNT(*) AS rows9, SUM(b.keijo_kosu) AS hours9 FROM #b AS b
        WHERE b.company_cd = c.company_cd AND b.user_id = c.user_id AND b.keijo_date = c.keijo_date
          AND b.k_wbs = c.k_wbs AND b.k_opa = c.k_opa AND b.k_gc = c.k_gc AND b.k_kt = c.k_kt
          AND b.k_kbk = c.k_kbk AND b.k_mw = c.k_mw AND b.k_sk = c.k_sk
          AND b.k_kgc = c.k_kgc AND b.k_yo = c.k_yo
    ) AS n9
    OUTER APPLY (
        SELECT COUNT(*) AS rows8 FROM #b AS b
        WHERE b.company_cd = c.company_cd AND b.user_id = c.user_id AND b.keijo_date = c.keijo_date
          AND b.k_wbs = c.k_wbs AND b.k_opa = c.k_opa AND b.k_gc = c.k_gc AND b.k_kt = c.k_kt
          AND b.k_kbk = c.k_kbk AND b.k_mw = c.k_mw AND b.k_sk = c.k_sk
          AND b.k_kgc = c.k_kgc
    ) AS n8
    OUTER APPLY (
        SELECT COUNT(*) AS rows7 FROM #b AS b
        WHERE b.company_cd = c.company_cd AND b.user_id = c.user_id AND b.keijo_date = c.keijo_date
          AND b.k_wbs = c.k_wbs AND b.k_opa = c.k_opa AND b.k_gc = c.k_gc AND b.k_kt = c.k_kt
          AND b.k_kbk = c.k_kbk AND b.k_mw = c.k_mw AND b.k_sk = c.k_sk
    ) AS n7
), k AS (
    SELECT
        company_cd, user_id, keijo_date, status_group, correction_kbn, keijo_kosu,
        CASE WHEN first_rn = 1 THEN 'FIRST_ON_LINE' ELSE 'LATER_ON_LINE' END AS line_round,
        CASE
            WHEN day_rows = 0 THEN 'NO_OKS02_DAY'
            WHEN rows9 = 1    THEN 'MATCH9'
            WHEN rows9 > 1    THEN 'HIT_MULTI_ROW'
            WHEN rows8 > 0    THEN 'YOUEKI_DIFF'
            WHEN rows7 > 0    THEN 'KEIJO_GC_DIFF'
            ELSE 'NO_BASE_7COL'
        END AS match_kind,
        CASE
            WHEN first_rn <> 1 THEN 'NOT_FIRST'
            WHEN rows9 > 0 AND shusei_mae_kosu IS NULL THEN 'PRE_NULL_HAS_ROW'
            WHEN rows9 > 0 AND shusei_mae_kosu = hours9 THEN 'PRE_EQUAL'
            WHEN rows9 > 0 THEN 'PRE_DIFF'
            WHEN shusei_mae_kosu IS NULL THEN 'PRE_NULL_NO_ROW'
            WHEN shusei_mae_kosu = 0 THEN 'PRE_ZERO_NO_ROW'
            ELSE 'PRE_VALUE_NO_ROW'
        END AS pre_check,
        CASE
            WHEN last_rn <> 1 THEN 'NOT_LAST'
            WHEN rows9 = 0 THEN 'POST_NO_ROW'
            WHEN keijo_kosu IS NULL THEN 'POST_NULL'
            WHEN keijo_kosu = hours9 THEN 'OKS02_EQ_POST'
            ELSE 'OKS02_NE_POST'
        END AS post_check
    FROM h
)
SELECT
    company_cd, status_group, correction_kbn, line_round, match_kind, pre_check, post_check,
    COUNT(*) AS row_cnt,
    COUNT(DISTINCT CONCAT(user_id, '|', keijo_date)) AS shain_days,
    SUM(keijo_kosu) AS post_hours
FROM k
GROUP BY company_cd, status_group, correction_kbn, line_round, match_kind, pre_check, post_check
ORDER BY company_cd, status_group, correction_kbn, line_round, match_kind, pre_check, post_check
OPTION (RECOMPILE);
