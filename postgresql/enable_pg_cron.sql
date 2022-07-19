-- Enable and setup pg_cron to perform daily vacuums.
-- Must be run against the postgres database - not the application database.
-- $Q$ behaves the same $$ resulting in a single quote see https://www.postgresql.org/docs/current/sql-syntax-lexical.html#SQL-SYNTAX-DOLLAR-QUOTING

DO $Q$ BEGIN
  IF (SELECT count(*) FROM pg_available_extensions WHERE name='pg_cron') > 0 THEN
      CREATE EXTENSION IF NOT EXISTS pg_cron;
      GRANT USAGE ON SCHEMA cron TO postgres;

      SELECT
        cron.schedule(
          'Daily Vacuum', -- name of the cron job
          '15 09 * * *', -- 9:15AM UTC == 7:15PM AEST every day
        $$ VACUUM FREEZE ANALYZE kis_fsu_ms $$
        );

      -- Job to clean up old job logs
      SELECT
        cron.schedule(
          'Cleanup pg_cron logs',
          '15 09 * * *',
        $$ DELETE FROM events WHERE event_time < now() - interval '14 days' $$
          );

  END IF;
END $Q$;
