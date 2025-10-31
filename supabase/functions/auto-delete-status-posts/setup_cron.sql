-- Cron設定SQL
-- タスク6.2: Edge Functionの定期実行設定

-- =====================================================
-- pg_cron拡張の有効化
-- =====================================================
-- Supabaseでは通常既に有効化されていますが、念のため実行
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- =====================================================
-- 既存のCronジョブを削除（存在する場合）
-- =====================================================
SELECT cron.unschedule('auto-delete-status-posts-hourly')
WHERE EXISTS (
    SELECT 1 FROM cron.job WHERE jobname = 'auto-delete-status-posts-hourly'
);

-- =====================================================
-- Cronジョブの作成
-- =====================================================
-- 毎時00分に実行（例: 10:00, 11:00, 12:00...）
SELECT cron.schedule(
    'auto-delete-status-posts-hourly',  -- ジョブ名
    '0 * * * *',                         -- Cronスケジュール（毎時00分）
    $$
    SELECT
      net.http_post(
        url:='https://ikjxfoyfeliiovbwelyx.supabase.co/functions/v1/auto-delete-status-posts',
        headers:='{"Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imlranhmb3lmZWxpaW92YndlbHl4Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDAxMjk0NSwiZXhwIjoyMDc1NTg4OTQ1fQ.9HS9-3V5jMUtnkIbIuBDZdz1kDX7eXfuETO4ATGzhhc", "Content-Type": "application/json"}'::jsonb
      ) as request_id;
    $$
);

-- =====================================================
-- Cronジョブの確認
-- =====================================================
SELECT
    jobid,
    jobname,
    schedule,
    active,
    database
FROM cron.job
WHERE jobname = 'auto-delete-status-posts-hourly';

-- =====================================================
-- 直近のCronジョブ実行履歴を確認
-- =====================================================
SELECT
    runid,
    jobid,
    status,
    return_message,
    start_time,
    end_time
FROM cron.job_run_details
WHERE jobid = (
    SELECT jobid FROM cron.job WHERE jobname = 'auto-delete-status-posts-hourly'
)
ORDER BY start_time DESC
LIMIT 10;

-- =====================================================
-- 注意事項
-- =====================================================
-- 1. Supabase無料プランではpg_cronが利用できない場合があります
-- 2. その場合は以下の代替案を検討してください:
--    - Supabase Dashboard → Database → Cron Jobs で設定
--    - GitHub Actionsで定期実行
--    - Vercel Cronで定期実行
--    - 外部Cronサービス（cron-job.org等）で定期実行
--
-- 3. Service Role Keyは上記SQLに含まれていますが、
--    本番環境では環境変数として管理することを推奨します

-- =====================================================
-- テスト実行（手動でCronジョブを即座に実行）
-- =====================================================
-- 以下のSQLを実行すると、Cronスケジュールを待たずに即座にEdge Functionを実行できます
/*
SELECT
  net.http_post(
    url:='https://ikjxfoyfeliiovbwelyx.supabase.co/functions/v1/auto-delete-status-posts',
    headers:='{"Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imlranhmb3lmZWxpaW92YndlbHl4Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDAxMjk0NSwiZXhwIjoyMDc1NTg4OTQ1fQ.9HS9-3V5jMUtnkIbIuBDZdz1kDX7eXfuETO4ATGzhhc", "Content-Type": "application/json"}'::jsonb
  ) as request_id;
*/

-- =====================================================
-- Cronジョブの削除（必要に応じて）
-- =====================================================
/*
SELECT cron.unschedule('auto-delete-status-posts-hourly');
*/
