-- V-11 OKS02に行がない社員日の内訳
-- 目的: V-04で工数ありに分類された社員日を、最新の組の種類で分ける。ADR-003の影響見積りを置き換える。
-- 実行: SSMSで全体を1回実行する（GOなし、1バッチ）。読取のみで、データは変更しない。
-- 出力: 集計だけ。氏名・自由記述・ユーザIDは出さない。ラベルは英数字。
-- 詳細: tools/update-method-simulation/README.md

USE GEMS_DM_S;
SET NOCOUNT ON;

-- 対象範囲（keijo_dateはyyyymmddの文字列。@toは含まない）。@companyをNULLにすると全社。
DECLARE @from varchar(8) = '20260401';
DECLARE @to   varchar(8) = '20261001';
DECLARE @company nvarchar(3) = NULL;

-- OKS02の取込み時点。最後の保存がこれより後なら、時間差で説明できる可能性がある。
DECLARE @cut datetime = (
    SELECT MAX(update_date) FROM dbo.V_T_OKS02 WHERE keijo_date >= @from
);

-- OKS02に行がない社員日を、採用の結果と最新の組の種類に分ける。
-- 最初に見るのは adopted_kind = ADOPT_A かつ adopted_hours_kind = HAS_HOURS の行。
--   latest_kind = PENDING_A_ZERO・B_ONLY_PENDING : 削除や0時間化の承認待ち。ADR-003が受け入れた範囲。
--   latest_kind = PENDING_A_HOURS                : 承認待ちの工数があるのにOKS02にない。要調査。
--   latest_kind = APPROVED_A_HOURS               : 承認済みの工数があるのにOKS02にない。ゲートが実績を消す。
-- 4〜8月に HAS_HOURS が残れば、承認待ちでは説明できない。
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
        END AS group_kind,
        ROW_NUMBER() OVER (PARTITION BY company_cd, user_id, keijo_date ORDER BY shusei_dt DESC) AS latest_rn
    FROM g
), picked AS (
    SELECT
        k.*,
        ROW_NUMBER() OVER (PARTITION BY company_cd, user_id, keijo_date ORDER BY shusei_dt DESC) AS rn
    FROM k
    WHERE group_kind <> 'SKIP'
), j AS (
    SELECT
        l.company_cd, l.user_id, l.keijo_date,
        l.shusei_dt AS last_save,
        l.a_hours AS latest_hours,
        COALESCE(p.group_kind, 'NO_APPROVED') AS adopted_kind,
        p.a_nonzero_rows AS adopted_nonzero_rows,
        p.a_hours AS adopted_hours,
        CASE
            WHEN l.a_rows > 0 AND l.a_pending = l.a_rows AND l.a_nonzero_rows = 0 THEN 'PENDING_A_ZERO'
            WHEN l.a_rows > 0 AND l.a_pending = l.a_rows THEN 'PENDING_A_HOURS'
            WHEN l.a_rows > 0 AND l.a_pending > 0 THEN 'MIXED_A'
            WHEN l.a_rows > 0 AND l.a_nonzero_rows = 0 THEN 'APPROVED_A_ZERO'
            WHEN l.a_rows > 0 THEN 'APPROVED_A_HOURS'
            WHEN l.b_pending > 0 THEN 'B_ONLY_PENDING'
            ELSE 'B_ONLY_APPROVED'
        END AS latest_kind
    FROM k AS l
    LEFT JOIN picked AS p
      ON p.company_cd = l.company_cd AND p.user_id = l.user_id AND p.keijo_date = l.keijo_date AND p.rn = 1
    WHERE l.latest_rn = 1
      AND NOT EXISTS (
          SELECT 1 FROM dbo.V_T_OKS02 AS o
          WHERE o.company_cd = l.company_cd AND o.user_id = l.user_id AND o.keijo_date = l.keijo_date
            AND o.keijo_date >= @from AND o.keijo_date < @to
      )
), r AS (
    SELECT
        j.*,
        CASE
            WHEN adopted_kind <> 'ADOPT_A' THEN 'NOT_APPLICABLE'
            WHEN adopted_nonzero_rows = 0 THEN 'ALL_ZERO_HOURS'
            ELSE 'HAS_HOURS'
        END AS adopted_hours_kind,
        CASE WHEN last_save > @cut THEN 'SAVE_AFTER_OKS02_CUT' ELSE 'SAVE_BEFORE_OKS02_CUT' END AS cut_kind
    FROM j
)
SELECT
    company_cd,
    LEFT(keijo_date, 6) AS keijo_month,
    adopted_kind, adopted_hours_kind, latest_kind, cut_kind,
    COUNT(*) AS shain_days,
    COUNT(DISTINCT user_id) AS users,
    SUM(adopted_hours) AS adopted_hours,
    SUM(latest_hours) AS latest_hours,
    MAX(@cut) AS oks02_cut
FROM r
GROUP BY company_cd, LEFT(keijo_date, 6), adopted_kind, adopted_hours_kind, latest_kind, cut_kind
ORDER BY company_cd, keijo_month, adopted_kind, adopted_hours_kind, latest_kind, cut_kind
OPTION (RECOMPILE);
