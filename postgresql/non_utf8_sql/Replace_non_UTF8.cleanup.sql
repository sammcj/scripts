
DROP FUNCTION IF EXISTS remove_non_utf8(p_string VARCHAR, show_arg boolean);
DROP FUNCTION IF EXISTS process_non_utf8_at_column(p_table_name VARCHAR, p_column_name VARCHAR);
DROP FUNCTION IF EXISTS process_non_utf8_at_schema(p_my_schema VARCHAR);
DROP FUNCTION IF EXISTS search_for_non_utf8_columns(search_tables name[], search_schema name[], show_timestamps boolean);
