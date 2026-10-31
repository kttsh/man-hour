-- V-04 OKS10の採用結果とOKS02の行の有無
-- 目的: OKS02に行がない社員日は、OKS10の採用行がすべて0時間かを確かめる。
-- 実行: SSMSで全体を1回実行する（GOなし、1バッチ）。読取のみで、データは変更しない。
-- 出力: 集計だけ。氏名・自由記述・ユーザIDは出さない。ラベルは英数字。
-- 詳細: tools/update-method-simulation/README.md

USE GEMS_DM_S;
SET NOCOUNT ON;

-- 対象範囲（keijo_dateはyyyymmddの文字列。@toは含まない）。@companyをNULLにすると全社。
DECLARE @from varchar(8) = '20260901';
DECLARE @to   varchar(8) = '20261001';
DECLARE @company nvarchar(3) = NULL;

-- OKS10の採用手順（Silver旧手順、ADR-002 6.3）
--   新しい組から順に、次の最初の組を採用する。
--     ADOPT_A : A行があり、すべてstatus 4-7
--     DELETED : A行がなく、B行がすべてstatus 4-7
--   それ以外の組は承認待ちとして読み飛ばす。採用できる組がなければ NO_APPROVED。
-- 確認の中心は、adopted_kind = ADOPT_A かつ oks02 = NO_OKS02 の行。
-- hours_kind = ALL_ZERO_HOURS なら原因は0時間で説明できる。HAS_HOURS は要調査。
WITH g AS (
    SELECT
        company_cd, user_id, keijo_date, shusei_dt,
        SUM(CASE WHEN shusei_kbn = 'A' THEN 1 ELSE 0 END) AS a_rows,
        SUM(CASE WHEN shusei_kbn = 'A' AND status IN ('1','2','3') THEN 1 ELSE 0 END) AS a_pending,
        SUM(CASE WHEN shusei_kbn = 'A' AND status IN ('4','5','6','7') THEN 1 ELSE 0 END) AS a_approved,
        SUM(CASE WHEN shusei_kbn = 'B' THEN 1 ELSE 0 END) AS b_rows,
        SUM(CASE WHEN shusei_kbn = 'B' AND status IN ('1','2','3') THEN 1 ELSE 0 END) AS b_pending,
        SUM(CASE WHEN shusei_kbn = 'A' AND keijo_kosu <> 0 THEN 1 ELSE 0 END) AS a_nonzero_rows,
        SUM(CASE WHEN shusei_kbn = 'A' THEN keijo_kosu ELSE 0 END) AS a_hours
    FROM dbo.V_T_OKS10
    WHERE keijo_date >= @from AND keijo_date < @to
      AND (@company IS NULL OR company_cd = @company)
    GROUP BY company_cd, user_id, keijo_date, shusei_dt
), k AS (
    SELECT
        g.*,
        CASE
            WHEN a_rows > 0 AND a_approved = a_rows THEN 'ADOPT_A'
            WHEN a_rows = 0 AND b_rows > 0 AND b_pending = 0 THEN 'DELETED'
            ELSE 'SKIP'
        END AS group_kind
    FROM g
), picked AS (
    SELECT
        k.*,
        ROW_NUMBER() OVER (PARTITION BY company_cd, user_id, keijo_date ORDER BY shusei_dt DESC) AS rn
    FROM k
    WHERE group_kind <> 'SKIP'
), shain_day AS (
    SELECT DISTINCT company_cd, user_id, keijo_date FROM g
), adopted AS (
    SELECT
        s.company_cd, s.user_id, s.keijo_date,
        COALESCE(p.group_kind, 'NO_APPROVED') AS adopted_kind,
        p.a_nonzero_rows, p.a_hours
    FROM shain_day AS s
    LEFT JOIN picked AS p
      ON p.company_cd = s.company_cd AND p.user_id = s.user_id AND p.keijo_date = s.keijo_date AND p.rn = 1
), o02 AS (
    SELECT company_cd, user_id, keijo_date, COUNT(*) AS row_cnt, SUM(keijo_kosu) AS hours
    FROM dbo.V_T_OKS02
    WHERE keijo_date >= @from AND keijo_date < @to
      AND (@company IS NULL OR company_cd = @company)
    GROUP BY company_cd, user_id, keijo_date
), j AS (
    SELECT
        COALESCE(a.company_cd, o.company_cd) AS company_cd,
        COALESCE(a.keijo_date, o.keijo_date) AS keijo_date,
        COALESCE(a.adopted_kind, 'NO_OKS10') AS adopted_kind,
        CASE WHEN o.company_cd IS NULL THEN 'NO_OKS02' ELSE 'HAS_OKS02' END AS oks02,
        CASE
            WHEN a.adopted_kind <> 'ADOPT_A' OR a.adopted_kind IS NULL THEN 'NOT_APPLICABLE'
            WHEN a.a_nonzero_rows = 0 THEN 'ALL_ZERO_HOURS'
            ELSE 'HAS_HOURS'
        END AS hours_kind,
        a.a_hours,
        o.hours
    FROM adopted AS a
    FULL OUTER JOIN o02 AS o
      ON o.company_cd = a.company_cd AND o.user_id = a.user_id AND o.keijo_date = a.keijo_date
)
SELECT
    company_cd, LEFT(keijo_date, 6) AS keijo_month, adopted_kind, oks02, hours_kind,
    COUNT(*) AS shain_days,
    SUM(a_hours) AS oks10_adopted_hours,
    SUM(hours) AS oks02_hours
FROM j
GROUP BY company_cd, LEFT(keijo_date, 6), adopted_kind, oks02, hours_kind
ORDER BY company_cd, keijo_month, adopted_kind, oks02, hours_kind
OPTION (RECOMPILE);
