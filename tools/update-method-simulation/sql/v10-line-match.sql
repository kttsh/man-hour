-- V-10 OKS02とOKS10の採用行は明細単位で一致するか
-- 目的: 締切済みの月で、OKS02の明細とADR-002の手順で作った承認済みの明細を、9列と工数で比べる（R-08）。
-- 実行: SSMSで全体を1回実行する（GOなし、1バッチ）。読取のみで、ビューは変更しない。一時テーブルを使う。
-- 出力: 集計だけ。氏名・自由記述・ユーザIDは出さない。ラベルは英数字。
-- 詳細: tools/update-method-simulation/README.md

USE GEMS_DM_S;
SET NOCOUNT ON;

-- 対象範囲（keijo_dateはyyyymmddの文字列。@toは含まない）。@companyをNULLにすると全社。
-- 重いときは @company='AAA'、@from='20260801'、@to='20260901' から始める。
DECLARE @from varchar(8) = '20260401';
DECLARE @to   varchar(8) = '20260901';
DECLARE @company nvarchar(3) = NULL;

IF OBJECT_ID('tempdb..#adopted') IS NOT NULL DROP TABLE #adopted;
IF OBJECT_ID('tempdb..#k10') IS NOT NULL DROP TABLE #k10;
IF OBJECT_ID('tempdb..#k02') IS NOT NULL DROP TABLE #k02;
IF OBJECT_ID('tempdb..#j') IS NOT NULL DROP TABLE #j;

-- OKS10の採用手順（ADR-002 6.3）。V-04と同じ。
WITH g AS (
    SELECT
        company_cd, user_id, keijo_date, shusei_dt,
        SUM(CASE WHEN shusei_kbn = 'A' THEN 1 ELSE 0 END) AS a_rows,
        SUM(CASE WHEN shusei_kbn = 'A' AND status IN ('4','5','6','7') THEN 1 ELSE 0 END) AS a_approved,
        SUM(CASE WHEN shusei_kbn = 'B' THEN 1 ELSE 0 END) AS b_rows,
        SUM(CASE WHEN shusei_kbn = 'B' AND status IN ('1','2','3') THEN 1 ELSE 0 END) AS b_pending
    FROM dbo.V_T_OKS10
    WHERE keijo_date >= @from AND keijo_date < @to
      AND (@company IS NULL OR company_cd = @company)
    GROUP BY company_cd, user_id, keijo_date, shusei_dt
), k AS (
    SELECT
        company_cd, user_id, keijo_date, shusei_dt,
        CASE
            WHEN a_rows > 0 AND a_approved = a_rows THEN 'ADOPT_A'
            WHEN a_rows = 0 AND b_rows > 0 AND b_pending = 0 THEN 'DELETED'
            ELSE 'SKIP'
        END AS group_kind
    FROM g
), p AS (
    SELECT
        k.*,
        ROW_NUMBER() OVER (PARTITION BY company_cd, user_id, keijo_date ORDER BY shusei_dt DESC) AS rn
    FROM k
    WHERE group_kind <> 'SKIP'
)
SELECT company_cd, user_id, keijo_date, shusei_dt, group_kind
INTO #adopted
FROM p
WHERE rn = 1
OPTION (RECOMPILE);

-- 0時間の行は比べない（OKS02が出さないため）。
-- 全列同一の重複はまとめない。両ビューに同じように出るので、工数の合計で比べれば差にならない。
SELECT
    o.company_cd, o.user_id, o.keijo_date,
    LTRIM(RTRIM(ISNULL(o.wbs_cd, '')))                 AS k_wbs,
    LTRIM(RTRIM(ISNULL(o.opa_cd, '')))                 AS k_opa,
    LTRIM(RTRIM(ISNULL(o.genka_center_cd, '')))        AS k_gc,
    LTRIM(RTRIM(ISNULL(o.katudo_type, '')))            AS k_kt,
    LTRIM(RTRIM(ISNULL(o.kyotenbetu_bunseki_key, ''))) AS k_kbk,
    LTRIM(RTRIM(ISNULL(o.mhi_wbs, '')))                AS k_mw,
    LTRIM(RTRIM(ISNULL(o.shokushu_cd, '')))            AS k_sk,
    LTRIM(RTRIM(ISNULL(o.keijo_genka_center_cd, '')))  AS k_kgc,
    LTRIM(RTRIM(ISNULL(o.youeki_cd, '')))              AS k_yo,
    COUNT(*) AS line_rows,
    SUM(o.keijo_kosu) AS hours
INTO #k10
FROM dbo.V_T_OKS10 AS o
JOIN #adopted AS a
  ON a.company_cd = o.company_cd AND a.user_id = o.user_id AND a.keijo_date = o.keijo_date
 AND a.shusei_dt = o.shusei_dt AND a.group_kind = 'ADOPT_A'
WHERE o.shusei_kbn = 'A' AND o.keijo_kosu <> 0
  AND o.keijo_date >= @from AND o.keijo_date < @to
GROUP BY
    o.company_cd, o.user_id, o.keijo_date,
    LTRIM(RTRIM(ISNULL(o.wbs_cd, ''))),
    LTRIM(RTRIM(ISNULL(o.opa_cd, ''))),
    LTRIM(RTRIM(ISNULL(o.genka_center_cd, ''))),
    LTRIM(RTRIM(ISNULL(o.katudo_type, ''))),
    LTRIM(RTRIM(ISNULL(o.kyotenbetu_bunseki_key, ''))),
    LTRIM(RTRIM(ISNULL(o.mhi_wbs, ''))),
    LTRIM(RTRIM(ISNULL(o.shokushu_cd, ''))),
    LTRIM(RTRIM(ISNULL(o.keijo_genka_center_cd, ''))),
    LTRIM(RTRIM(ISNULL(o.youeki_cd, '')))
OPTION (RECOMPILE);

SELECT
    company_cd, user_id, keijo_date,
    LTRIM(RTRIM(ISNULL(wbs_cd, '')))                 AS k_wbs,
    LTRIM(RTRIM(ISNULL(opa_cd, '')))                 AS k_opa,
    LTRIM(RTRIM(ISNULL(genka_center_cd, '')))        AS k_gc,
    LTRIM(RTRIM(ISNULL(katudo_type, '')))            AS k_kt,
    LTRIM(RTRIM(ISNULL(kyotenbetu_bunseki_key, ''))) AS k_kbk,
    LTRIM(RTRIM(ISNULL(mhi_wbs, '')))                AS k_mw,
    LTRIM(RTRIM(ISNULL(shokushu_cd, '')))            AS k_sk,
    LTRIM(RTRIM(ISNULL(keijo_genka_center_cd, '')))  AS k_kgc,
    LTRIM(RTRIM(ISNULL(youeki_cd, '')))              AS k_yo,
    COUNT(*) AS line_rows,
    SUM(keijo_kosu) AS hours,
    MAX(CASE WHEN status IN ('1','2','3') THEN 1 ELSE 0 END) AS has_pending
INTO #k02
FROM dbo.V_T_OKS02
WHERE keijo_kosu <> 0
  AND keijo_date >= @from AND keijo_date < @to
  AND (@company IS NULL OR company_cd = @company)
GROUP BY
    company_cd, user_id, keijo_date,
    LTRIM(RTRIM(ISNULL(wbs_cd, ''))),
    LTRIM(RTRIM(ISNULL(opa_cd, ''))),
    LTRIM(RTRIM(ISNULL(genka_center_cd, ''))),
    LTRIM(RTRIM(ISNULL(katudo_type, ''))),
    LTRIM(RTRIM(ISNULL(kyotenbetu_bunseki_key, ''))),
    LTRIM(RTRIM(ISNULL(mhi_wbs, ''))),
    LTRIM(RTRIM(ISNULL(shokushu_cd, ''))),
    LTRIM(RTRIM(ISNULL(keijo_genka_center_cd, ''))),
    LTRIM(RTRIM(ISNULL(youeki_cd, '')))
OPTION (RECOMPILE);

SELECT
    COALESCE(o.company_cd, a.company_cd) AS company_cd,
    COALESCE(o.user_id, a.user_id)       AS user_id,
    COALESCE(o.keijo_date, a.keijo_date) AS keijo_date,
    COALESCE(o.k_wbs, a.k_wbs) AS k_wbs,
    COALESCE(o.k_opa, a.k_opa) AS k_opa,
    COALESCE(o.k_gc, a.k_gc)   AS k_gc,
    COALESCE(o.k_kt, a.k_kt)   AS k_kt,
    COALESCE(o.k_kbk, a.k_kbk) AS k_kbk,
    COALESCE(o.k_mw, a.k_mw)   AS k_mw,
    COALESCE(o.k_sk, a.k_sk)   AS k_sk,
    COALESCE(o.k_kgc, a.k_kgc) AS k_kgc,
    COALESCE(o.k_yo, a.k_yo)   AS k_yo,
    ISNULL(o.line_rows, 0) AS rows02,
    ISNULL(a.line_rows, 0) AS rows10,
    ISNULL(o.hours, 0)     AS hours02,
    ISNULL(a.hours, 0)     AS hours10,
    ISNULL(o.has_pending, 0) AS has_pending,
    CASE
        WHEN a.company_cd IS NULL THEN 'ONLY_OKS02'
        WHEN o.company_cd IS NULL THEN 'ONLY_OKS10'
        WHEN o.hours = a.hours    THEN 'MATCH'
        ELSE 'HOURS_DIFF'
    END AS line_kind
INTO #j
FROM #k02 AS o
FULL OUTER JOIN #k10 AS a
  ON a.company_cd = o.company_cd AND a.user_id = o.user_id AND a.keijo_date = o.keijo_date
 AND a.k_wbs = o.k_wbs AND a.k_opa = o.k_opa AND a.k_gc = o.k_gc AND a.k_kt = o.k_kt
 AND a.k_kbk = o.k_kbk AND a.k_mw = o.k_mw AND a.k_sk = o.k_sk
 AND a.k_kgc = o.k_kgc AND a.k_yo = o.k_yo;

-- 結果1: 社員日ごとの一致状況
-- KEY_DIFF_SAME_TOTAL は、行数と合計は同じなのに明細が違う社員日。これまでの比較では見えなかった。
-- 締切済みの月で ALL_MATCH 以外があれば、OKS02を正解の代わりにできない社員日がある。
WITH d AS (
    SELECT
        company_cd, user_id, keijo_date,
        SUM(CASE WHEN line_kind IN ('ONLY_OKS02','ONLY_OKS10') THEN 1 ELSE 0 END) AS only_lines,
        SUM(CASE WHEN line_kind = 'HOURS_DIFF' THEN 1 ELSE 0 END) AS diff_lines,
        COUNT(*) AS lines,
        SUM(rows02) AS rows02, SUM(rows10) AS rows10,
        SUM(hours02) AS hours02, SUM(hours10) AS hours10,
        MAX(has_pending) AS has_pending
    FROM #j
    GROUP BY company_cd, user_id, keijo_date
), k AS (
    SELECT
        d.*,
        CASE
            WHEN rows10 = 0 THEN 'OKS02_ONLY_DAY'
            WHEN rows02 = 0 THEN 'OKS10_ONLY_DAY'
            WHEN only_lines = 0 AND diff_lines = 0 THEN 'ALL_MATCH'
            WHEN only_lines = 0 THEN 'HOURS_DIFF'
            WHEN rows02 = rows10 AND hours02 = hours10 THEN 'KEY_DIFF_SAME_TOTAL'
            ELSE 'KEY_DIFF'
        END AS day_kind
    FROM d
)
SELECT
    k.company_cd,
    LEFT(k.keijo_date, 6) AS keijo_month,
    k.day_kind,
    CASE WHEN k.rows02 = 0 THEN 'NO_OKS02' WHEN k.has_pending = 1 THEN 'PENDING' ELSE 'APPROVED' END AS oks02_state,
    COALESCE(a.group_kind, 'NO_APPROVED') AS adopted_kind,
    COUNT(*) AS shain_days,
    SUM(k.lines) AS line_cnt,
    SUM(k.only_lines) AS only_lines,
    SUM(k.diff_lines) AS hours_diff_lines,
    SUM(k.rows02) AS oks02_rows,
    SUM(k.rows10) AS oks10_rows,
    SUM(k.hours02) AS oks02_hours,
    SUM(k.hours10) AS oks10_hours
FROM k
LEFT JOIN #adopted AS a
  ON a.company_cd = k.company_cd AND a.user_id = k.user_id AND a.keijo_date = k.keijo_date
GROUP BY
    k.company_cd, LEFT(k.keijo_date, 6), k.day_kind,
    CASE WHEN k.rows02 = 0 THEN 'NO_OKS02' WHEN k.has_pending = 1 THEN 'PENDING' ELSE 'APPROVED' END,
    COALESCE(a.group_kind, 'NO_APPROVED')
ORDER BY company_cd, keijo_month, day_kind, oks02_state, adopted_kind
OPTION (RECOMPILE);

-- 結果2: 片方にしかない明細が1対1の社員日で、違っていた列
-- diff_cols が keijo_gc だけなら賃金計上先原価センタの付け直し、というように原因の列を絞る。
WITH o AS (
    SELECT
        j.*,
        COUNT(*) OVER (PARTITION BY company_cd, user_id, keijo_date, line_kind) AS same_kind_lines
    FROM #j AS j
    WHERE line_kind IN ('ONLY_OKS02', 'ONLY_OKS10')
)
SELECT
    a.company_cd,
    RTRIM(CONCAT(
        CASE WHEN a.k_wbs <> b.k_wbs THEN 'wbs ' ELSE '' END,
        CASE WHEN a.k_opa <> b.k_opa THEN 'opa ' ELSE '' END,
        CASE WHEN a.k_gc  <> b.k_gc  THEN 'genka_center ' ELSE '' END,
        CASE WHEN a.k_kt  <> b.k_kt  THEN 'katudo_type ' ELSE '' END,
        CASE WHEN a.k_kbk <> b.k_kbk THEN 'kyotenbetu ' ELSE '' END,
        CASE WHEN a.k_mw  <> b.k_mw  THEN 'mhi_wbs ' ELSE '' END,
        CASE WHEN a.k_sk  <> b.k_sk  THEN 'shokushu ' ELSE '' END,
        CASE WHEN a.k_kgc <> b.k_kgc THEN 'keijo_gc ' ELSE '' END,
        CASE WHEN a.k_yo  <> b.k_yo  THEN 'youeki ' ELSE '' END
    )) AS diff_cols,
    CASE WHEN a.hours02 = b.hours10 THEN 'SAME_HOURS' ELSE 'DIFF_HOURS' END AS hours_kind,
    COUNT(*) AS shain_days
FROM o AS a
JOIN o AS b
  ON b.company_cd = a.company_cd AND b.user_id = a.user_id AND b.keijo_date = a.keijo_date
WHERE a.line_kind = 'ONLY_OKS02' AND b.line_kind = 'ONLY_OKS10'
  AND a.same_kind_lines = 1 AND b.same_kind_lines = 1
GROUP BY
    a.company_cd,
    RTRIM(CONCAT(
        CASE WHEN a.k_wbs <> b.k_wbs THEN 'wbs ' ELSE '' END,
        CASE WHEN a.k_opa <> b.k_opa THEN 'opa ' ELSE '' END,
        CASE WHEN a.k_gc  <> b.k_gc  THEN 'genka_center ' ELSE '' END,
        CASE WHEN a.k_kt  <> b.k_kt  THEN 'katudo_type ' ELSE '' END,
        CASE WHEN a.k_kbk <> b.k_kbk THEN 'kyotenbetu ' ELSE '' END,
        CASE WHEN a.k_mw  <> b.k_mw  THEN 'mhi_wbs ' ELSE '' END,
        CASE WHEN a.k_sk  <> b.k_sk  THEN 'shokushu ' ELSE '' END,
        CASE WHEN a.k_kgc <> b.k_kgc THEN 'keijo_gc ' ELSE '' END,
        CASE WHEN a.k_yo  <> b.k_yo  THEN 'youeki ' ELSE '' END
    )),
    CASE WHEN a.hours02 = b.hours10 THEN 'SAME_HOURS' ELSE 'DIFF_HOURS' END
ORDER BY a.company_cd, shain_days DESC
OPTION (RECOMPILE);
