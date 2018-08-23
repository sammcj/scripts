\echo ''
\echo 'Database size'
SELECT pg_size_pretty(pg_database_size(current_database()));

\echo 'Table sizes'
SELECT relname
       AS
       "Table",
       Pg_size_pretty(Pg_total_relation_size(relid))
       AS "Size",
       Pg_size_pretty(Pg_total_relation_size(relid) - Pg_relation_size(relid))
       AS
       "External Size"
FROM   pg_catalog.pg_statio_user_tables
ORDER  BY Pg_total_relation_size(relid) DESC;

\echo ''
\echo 'Largest relations'
 SELECT nspname
       || '.'
       || relname                              AS "relation",
       Pg_size_pretty(Pg_relation_size(C.oid)) AS "size"
FROM   pg_class C
       LEFT JOIN pg_namespace N
              ON ( N.oid = C.relnamespace )
WHERE  nspname NOT IN ( 'pg_catalog', 'information_schema' )
ORDER  BY Pg_relation_size(C.oid) DESC
LIMIT  20;


\echo ''
\echo 'Cache hit rates (should not be less than 99%)'
SELECT SUM(heap_blks_read)                                               AS
       heap_read,
       SUM(heap_blks_hit)                                                AS
       heap_hit,
       ( SUM(heap_blks_hit) - SUM(heap_blks_read) ) / SUM(heap_blks_hit) AS
       ratio
FROM   pg_statio_user_tables;

\echo ''
\echo 'Table index usage rates (should not be less than 0.99)'
SELECT relname,
       100 * idx_scan / ( seq_scan + idx_scan ) percent_of_times_index_used,
       n_live_tup                               rows_in_table
FROM   pg_stat_user_tables
ORDER  BY n_live_tup DESC;

\echo ''
\echo 'How many indexes are in cache'
SELECT SUM(idx_blks_read)                                             AS
       idx_read,
       SUM(idx_blks_hit)                                              AS idx_hit
       ,
       ( SUM(idx_blks_hit) - SUM(idx_blks_read) ) / SUM(idx_blks_hit) AS
       ratio
FROM   pg_statio_user_indexes;

\echo ''
\echo 'Break down of cache hits by table'
WITH all_tables
     AS (SELECT *
        FROM   (SELECT 'all' :: text                          AS table_name,
                        SUM(( Coalesce(heap_blks_read, 0)
                              + Coalesce(idx_blks_read, 0)
                              + Coalesce(toast_blks_read, 0)
                              + Coalesce(tidx_blks_read, 0) )) AS from_disk,
                        SUM(( Coalesce(heap_blks_hit, 0)
                              + Coalesce(idx_blks_hit, 0)
                              + Coalesce(toast_blks_hit, 0)
                              + Coalesce(tidx_blks_hit, 0) ))  AS from_cache
                 FROM   pg_statio_all_tables
                --> change to pg_statio_USER_tables if you want to check only user tables (excluding postgres's own tables)
                ) a
         WHERE  ( from_disk + from_cache ) > 0 -- discard tables without hits
        ),
     TABLES
     AS (SELECT *
         FROM   (SELECT relname                             AS table_name,
                        (( Coalesce(heap_blks_read, 0)
                           + Coalesce(idx_blks_read, 0)
                           + Coalesce(toast_blks_read, 0)
                           + Coalesce(tidx_blks_read, 0) )) AS from_disk,
                        (( Coalesce(heap_blks_hit, 0)
                           + Coalesce(idx_blks_hit, 0)
                           + Coalesce(toast_blks_hit, 0)
                           + Coalesce(tidx_blks_hit, 0) ))  AS from_cache
                 FROM   pg_statio_all_tables
                --> change to pg_statio_USER_tables if you want to check only user tables (excluding postgres's own tables)
                ) a
         WHERE  ( from_disk + from_cache ) > 0 -- discard tables without hits
        )
SELECT table_name                 AS "table name",
       from_disk                  AS "disk hits",
       Round(( from_disk :: NUMERIC / ( from_disk + from_cache ) :: NUMERIC ) *
             100.0,
       2)                         AS "% disk hits",
       Round(( from_cache :: NUMERIC / ( from_disk + from_cache ) :: NUMERIC ) *
             100.0,
       2)                         AS "% cache hits",
       ( from_disk + from_cache ) AS "total hits"
FROM   (SELECT *
        FROM   all_tables
        UNION ALL
        SELECT *
        FROM   TABLES) a
ORDER  BY ( CASE
              WHEN table_name = 'all' THEN 0
              ELSE 1
            END ),
          from_disk DESC;
