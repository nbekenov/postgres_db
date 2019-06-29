--list all tables
select * from information_schema.tables;

--list all table columns
SELECT column_name 
FROM information_schema.columns 
WHERE table_schema ='<schema_name>' AND table_name='table_name';

--get locks
---PG-10
select l.pid,pga.query_start,relname ,pga.usename,mode,granted,pga.query 
    from pg_locks  l
        join pg_class c
            on l.relation=c.oid
        join pg_stat_activity pga
            on pga.pid=l.pid
    where relname like '%<table_name>%';

---PG-9
select  pid, locktype, relation,relname, mode, granted,current_query 
    from pg_locks  l
        join pg_class c
            on l.relation=c.oid
        join pg_stat_activity pga
            on pga.procpid=l.pid
    where pga.current_query != '<IDLE>'  and  upper(c.relname)='<table_name>';

--Kill -9  the proccess
SELECT pg_terminate_backend(__pid__);

--get acount activity
select usename,datname,count(*) 
from pg_stat_activity group by usename,datname order by 3 desc;

--show queries that runing longer than 15 minutes
SELECT
  pid,
  now() - pg_stat_activity.query_start AS duration,
  query,
  state
FROM pg_stat_activity
WHERE (now() - pg_stat_activity.query_start) > interval '15 minutes';

-- show running queries
SELECT pid, age(clock_timestamp(), query_start), usename, query 
FROM pg_stat_activity 
WHERE query != '<IDLE>' AND query NOT ILIKE '%pg_stat_activity%' 
ORDER BY query_start desc;

--SIZE of the table with size of the index
    SELECT
    table_name,
    pg_size_pretty(table_size) AS table_size,
    pg_size_pretty(indexes_size) AS indexes_size,
    pg_size_pretty(total_size) AS total_size
FROM (
    SELECT
        table_name,
        pg_table_size(table_name) AS table_size,
        pg_indexes_size(table_name) AS indexes_size,
        pg_total_relation_size(table_name) AS total_size
    FROM (
        SELECT ('"' || table_schema || '"."' || table_name || '"') AS table_name
        FROM information_schema.tables
    ) AS all_tables
    ORDER BY total_size DESC
) AS pretty_sizes;

--Size of indexes separatley

SELECT idx.relname as table,
               idx.indexrelname as index,
               pg_total_relation_size( idx.indexrelname::text )/1024/1024/1024 as bytes,
               cls.relpages as pages,
               cls.reltuples as tuples,
               idx.idx_scan as scanned,
               idx.idx_tup_read as read,
               idx.idx_tup_fetch as fetched
          FROM pg_stat_user_indexes idx,
               pg_class cls ,
               pg_index
         WHERE cls.relname = idx.relname
           AND idx.indexrelid = pg_index.indexrelid
           AND pg_index.indisunique is not true
           AND pg_index.indisprimary is not true
           AND idx.indexrelname not ilike '%slony%'
           AND idx.indexrelname not like 'sl\_%'
        ORDER BY bytes desc;

--compare column types 
select dm_ci360.column_name, migr_tmp_type,dm_ci360_type 
from
    (select column_name, data_type as migr_tmp_type, character_maximum_length
        from INFORMATION_SCHEMA.COLUMNS
        where table_name = '<table_name>' and table_schema='<schema_name>'
    )schema_1
join
    (select column_name, data_type as dm_ci360_type, character_maximum_length
        from INFORMATION_SCHEMA.COLUMNS
        where table_name = '<table_name>' and table_schema='<schema_name>'
    )schema_2 
on schema_2.column_name=schema_1.column_name;

--show dependent objects
SELECT DISTINCT srcobj.oid AS src_oid
  , srcnsp.nspname AS src_schemaname
  , srcobj.relname AS src_objectname
  , tgtobj.oid AS dependent_viewoid
  , tgtnsp.nspname AS dependant_schemaname
  , tgtobj.relname AS dependant_objectname
FROM pg_class srcobj
  JOIN pg_depend srcdep ON srcobj.oid = srcdep.refobjid
  JOIN pg_depend tgtdep ON srcdep.objid = tgtdep.objid
  JOIN pg_class tgtobj ON tgtdep.refobjid = tgtobj.oid AND srcobj.oid <> tgtobj.oid
  LEFT JOIN pg_namespace srcnsp ON srcobj.relnamespace = srcnsp.oid
  LEFT JOIN pg_namespace tgtnsp ON tgtobj.relnamespace = tgtnsp.oid
WHERE tgtdep.deptype = 'i'::"char" AND tgtobj.relkind = 'v'::"char"
and srcobj.relname like '%redemptions_summary%';


--Create read user
CREATE ROLE read_access_role;
-- grant  access to existing tables
GRANT USAGE ON SCHEMA public TO read_access_role;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO read_access_role;
-- Grant access to future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO read_access_role;

-- create a new user and add him to role
CREATE USER read_user WITH PASSWORD 're@dus9r';
GRANT CONNECT ON DATABASE "CXTWH" TO read_user;

GRANT read_access_role to read_user;

--Permissions
ALTER DEFAULT PRIVILEGES 
    FOR ROLE some_role   -- Alternatively "FOR USER"
    IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO user_name;
--Here, some_role is a role that creates the tables, while user_name is the one who gets the privileges. Defining this, you have to be logged in as some_role or a member of it.



SELECT record FROM myrecords WHERE record ~ '[^0-9]';
--means that in the record field there should be at least one non-digit character (this is the meaning of the regex).

--If one looks for the records which would include digits and lower-case letter, then I would expect a regex like:
SELECT record FROM myrecords WHERE record ~ '[0-9a-z]';
--which would return all the records having at least one character which is a digit or lowercase letter.
--If you want to get the records which have no digits, then you would have to use the following regex:


SELECT record FROM myrecords WHERE record ~ '^[^0-9]+$';
--Here, the ^ character outside of square brackets means the beginning of the field, the $ character means the end of the field, and we require that all characters in between are non-digits. + indicates that there should be at least one such characters. If we would also allow empty strings, then the regex would look like ^[^0-9]*$.
