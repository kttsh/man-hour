-- V-13 OKS10のupdate_dateは承認時刻の代わりになるか
-- 目的: R-02の近似（update_dateがT以前なら承認済み）の妥当性と、承認にかかる時間を確かめる。
-- 実行: SSMSで全体を1回実行する（GOなし、1バッチ）。読取のみで、ビューは変更しない。一時テーブルを使う。
-- 出力: 集計だけ。氏名・自由記述・ユーザIDは出さない。ラベルは英数字。
-- 詳細: tools/update-method-simulation/README.md

USE GEMS_DM_S;
SET NOCOUNT ON;

-- 対象範囲（keijo_dateはyyyymmddの文字列。@toは含まない）。@companyをNULLにすると全社。
DECLARE @from varchar(8) = '20260401';
DECLARE @to   varchar(8) = '20261001';
DECLARE @company nvarchar(3) = NULL;

IF OBJECT_ID('tempdb..#g') IS NOT NULL DROP TABLE #g;

-- 締切の窓はV-06の結果（作業月の翌月に前月分の更新が続いた日）。win_toは含まない。9月分は断面の日まで。
-- 組ごとに、A行のupdate_dateと保存の時刻を比べる。A行のない組は保存としてだけ数える。
WITH win AS (
    SELECT * FROM (VALUES
        ('202604', CONVERT(datetime, '20260507', 112), CONVERT(datetime, '20260513', 112)),
        ('202605', CONVERT(datetime, '20260601', 112), CONVERT(datetime, '20260605', 112)),
        ('202606', CONVERT(datetime, '20260701', 112), CONVERT(datetime, '20260704', 112)),
        ('202607', CONVERT(datetime, '20260803', 112), CONVERT(datetime, '20260807', 112)),
        ('202608', CONVERT(datetime, '20260901', 112), CONVERT(datetime, '20260905', 112)),
        ('202609', CONVERT(datetime, '20261001', 112), CONVERT(datetime, '20261002', 112))
    ) AS w (keijo_month, win_from, win_to)
), g AS (
    SELECT
        company_cd, user_id, keijo_date, shusei_dt,
        SUM(CASE WHEN shusei_kbn = 'A' THEN 1 ELSE 0 END) AS a_rows,
        SUM(CASE WHEN shusei_kbn = 'A' AND status IN ('1','2','3') THEN 1 ELSE 0 END) AS a_pending,
        MIN(CASE WHEN shusei_kbn = 'A' THEN update_date END) AS min_update,
        MAX(CASE WHEN shusei_kbn = 'A' THEN update_date END) AS max_update,
        SUM(CASE WHEN shusei_kbn = 'A' AND update_user <> insert_user THEN 1 ELSE 0 END) AS a_other_updater
    FROM dbo.V_T_OKS10
    WHERE keijo_date >= @from AND keijo_date < @to
      AND (@company IS NULL OR company_cd = @company)
    GROUP BY company_cd, user_id, keijo_date, shusei_dt
), s AS (
    SELECT
        g.*,
        LEAD(shusei_dt) OVER (PARTITION BY company_cd, user_id, keijo_date ORDER BY shusei_dt) AS next_save
    FROM g
)
SELECT
    s.company_cd,
    LEFT(s.keijo_date, 6) AS keijo_month,
    s.shusei_dt, s.max_update, s.user_id, s.keijo_date,
    CASE
        WHEN s.a_pending > 0 THEN 'PENDING_GROUP'
        WHEN s.next_save IS NULL THEN 'LATEST_APPROVED'
        ELSE 'PAST_APPROVED'
    END AS group_scope,
    CASE
        WHEN s.max_update < s.shusei_dt THEN 'UPDATE_BEFORE_SAVE'
        WHEN s.max_update = s.shusei_dt THEN 'UPDATE_AT_SAVE'
        ELSE 'UPDATE_AFTER_SAVE'
    END AS update_kind,
    CASE WHEN s.min_update = s.max_update THEN 'UNIFORM' ELSE 'SPLIT' END AS update_uniform,
    CASE
        WHEN s.next_save IS NULL THEN 'NO_NEXT_SAVE'
        WHEN s.max_update > s.next_save THEN 'AFTER_NEXT_SAVE'
        ELSE 'BEFORE_NEXT_SAVE'
    END AS next_save_kind,
    CASE
        WHEN s.max_update >= w.win_from AND s.max_update < w.win_to THEN 'IN_CLOSE_WINDOW'
        ELSE 'OUTSIDE_WINDOW'
    END AS window_kind,
    CASE WHEN s.a_other_updater > 0 THEN 'OTHER_USER' ELSE 'SAME_USER' END AS updater_kind,
    s.a_rows
INTO #g
FROM s
LEFT JOIN win AS w ON w.keijo_month = LEFT(s.keijo_date, 6)
WHERE s.a_rows > 0
OPTION (RECOMPILE);

-- 結果1: update_dateの性質
-- PAST_APPROVED で AFTER_NEXT_SAVE が多いと、次の保存の後で書き換えられた行が多く、承認時刻とは言えない。
-- IN_CLOSE_WINDOW が多いと、R-02は承認を締切まで遅く見て、維持を多く数える。
SELECT
    company_cd, group_scope, update_kind, update_uniform, next_save_kind, window_kind, updater_kind,
    COUNT(*) AS group_cnt,
    SUM(a_rows) AS a_rows,
    COUNT(DISTINCT CONCAT(user_id, '|', keijo_date)) AS shain_days
FROM #g
GROUP BY company_cd, group_scope, update_kind, update_uniform, next_save_kind, window_kind, updater_kind
ORDER BY company_cd, group_scope, update_kind, update_uniform, next_save_kind, window_kind, updater_kind
OPTION (RECOMPILE);

-- 結果2: 最新の承認済みの組の、保存から更新までの時間（会社×作業月）
-- 締切の窓に入った組は承認時刻が分からないので、in_close_window に分ける。
SELECT
    company_cd, keijo_month,
    COUNT(*) AS group_cnt,
    SUM(CASE WHEN window_kind = 'IN_CLOSE_WINDOW' THEN 1 ELSE 0 END) AS in_close_window,
    SUM(CASE WHEN update_kind <> 'UPDATE_AFTER_SAVE' THEN 1 ELSE 0 END) AS not_after_save,
    SUM(CASE WHEN window_kind = 'OUTSIDE_WINDOW' AND update_kind = 'UPDATE_AFTER_SAVE'
              AND DATEDIFF(MINUTE, shusei_dt, max_update) <= 60 THEN 1 ELSE 0 END) AS lag_le_1h,
    SUM(CASE WHEN window_kind = 'OUTSIDE_WINDOW' AND update_kind = 'UPDATE_AFTER_SAVE'
              AND DATEDIFF(MINUTE, shusei_dt, max_update) > 60
              AND DATEDIFF(MINUTE, shusei_dt, max_update) <= 1440 THEN 1 ELSE 0 END) AS lag_le_1d,
    SUM(CASE WHEN window_kind = 'OUTSIDE_WINDOW' AND update_kind = 'UPDATE_AFTER_SAVE'
              AND DATEDIFF(MINUTE, shusei_dt, max_update) > 1440
              AND DATEDIFF(MINUTE, shusei_dt, max_update) <= 4320 THEN 1 ELSE 0 END) AS lag_le_3d,
    SUM(CASE WHEN window_kind = 'OUTSIDE_WINDOW' AND update_kind = 'UPDATE_AFTER_SAVE'
              AND DATEDIFF(MINUTE, shusei_dt, max_update) > 4320
              AND DATEDIFF(MINUTE, shusei_dt, max_update) <= 10080 THEN 1 ELSE 0 END) AS lag_le_7d,
    SUM(CASE WHEN window_kind = 'OUTSIDE_WINDOW' AND update_kind = 'UPDATE_AFTER_SAVE'
              AND DATEDIFF(MINUTE, shusei_dt, max_update) > 10080 THEN 1 ELSE 0 END) AS lag_gt_7d
FROM #g
WHERE group_scope = 'LATEST_APPROVED'
GROUP BY company_cd, keijo_month
ORDER BY company_cd, keijo_month
OPTION (RECOMPILE);
