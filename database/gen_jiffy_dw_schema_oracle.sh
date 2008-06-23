#  Copyright 2008 Whitepages.com, Inc. See License.txt for more information.

#!/bin/sh

usage() 
{
  echo "Usage: gen_jiffy_dw_schema_oracle.sh [config]"
  echo "  DDL to create data warehouse star schema for jiffy rollup reporting"
}

if [ $# != 1 ]
then
  usage
  exit
else
  CONFIG=$1
fi

OUT1=create_jiffy_dw_schema.sql
OUT2=create_jiffy_rollup_package.sql

get()
{
  grep "$1" $CONFIG | cut -d= -f2
}

# get Oracle configurations
DATA_TABLESPACE=$(get DATA_TABLESPACE)
DATA_FILENAME=$(get DATA_FILENAME)
DATA_FILESIZE=$(get DATA_FILESIZE)
INDEX_TABLESPACE=$(get INDEX_TABLESPACE)
INDEX_FILENAME=$(get INDEX_FILENAME)
INDEX_FILESIZE=$(get INDEX_FILESIZE)
USE_BITMAP_INDEX=$(get USE_BITMAP_INDEX)

JIFFY_USERNAME=$(get JIFFY_USERNAME)
JIFFY_PASS=$(get JIFFY_PASS)
JIFFY_LOADER_USERNAME=$(get JIFFY_LOADER_USERNAME)
JIFFY_LOADER_PASS=$(get JIFFY_LOADER_PASS)
JIFFY_READER_USERNAME=$(get JIFFY_READER_USERNAME)
JIFFY_READER_PASS=$(get JIFFY_READER_PASS)
TEMPORARY_TABLESPACE=$(get TEMPORARY_TABLESPACE)
CONNECTSTRING=$(get CONNECTSTRING)

EMAIL_FROM=$(get EMAIL_FROM)
EMAIL_TO=$(get EMAIL_TO)

echo ""
echo ""
echo "You have enter the following setttings:"
echo ""
echo "DATABASE=$DATABASE"
echo "JIFFY_USERNAME=$JIFFY_USERNAME" 
echo "JIFFY_PASS=$JIFFY_PASS"
echo "CONNECTSTRING=$CONNECTSTRING"
echo "USE_BITMAP_INDEX=$USE_BITMAP_INDEX"
echo ""
echo "Press enter to confirm your setting "
#read dummy

#
# Begin creating schema
#

echo "
CONNECT ${JIFFY_USERNAME}/${JIFFY_PASS}@${CONNECTSTRING};
--
--  TABLE OWNER ${JIFFY_USERNAME}
--
BEGIN EXECUTE IMMEDIATE 'DROP TABLE measurement_facts';
    EXCEPTION WHEN OTHERS THEN NULL; END;
/   
CREATE TABLE measurement_facts
(
    d_time_id       DATE    NOT NULL,   -- DATETIME is a natural unique key and easily indexed
    d_code_id       NUMBER  NOT NULL,
    d_page_id       NUMBER  NOT NULL,
    d_cat1_id       NUMBER  NULL, -- awaiting support for this dimension
    d_cat2_id       NUMBER  NULL, -- awaiting support for this dimension
    d_os_id         NUMBER  NULL, -- awaiting support for this dimension
    d_browser_id    NUMBER  NULL, -- awaiting support for this dimension
    et_count        NUMBER,
    et_sum          NUMBER,
    et_sum_squares  NUMBER,
    -- et_mean and et_std are functionall derived from sum, count, and sum of squares
    et_min          NUMBER,
    et_max          NUMBER,
    CONSTRAINT measurement_facts_pk PRIMARY KEY
    (
        d_time_id,
        d_code_id,
        d_page_id,
        d_cat1_id,
        d_cat2_id,
        d_os_id,
        d_browser_id
    ) USING INDEX TABLESPACE ${INDEX_TABLESPACE}
);

GRANT SELECT, UPDATE, INSERT ON measurement_facts TO ${JIFFY_LOADER_USERNAME};
GRANT SELECT ON measurement_facts TO ${JIFFY_READER_USERNAME};

-- create indexes on facts for each dimension
-- time dimension is too fine grained to use bitmaps space efficiently
CREATE INDEX mf_time_ix
    ON measurement_facts (d_time_id)
    TABLESPACE ${INDEX_TABLESPACE};
CREATE ${USE_BITMAP_INDEX} INDEX mf_code_ix
    ON measurement_facts (d_code_id)
    TABLESPACE ${INDEX_TABLESPACE};
CREATE ${USE_BITMAP_INDEX} INDEX mf_page_ix
    ON measurement_facts (d_page_id)
    TABLESPACE ${INDEX_TABLESPACE};
CREATE ${USE_BITMAP_INDEX} INDEX mf_cat1_ix
    ON measurement_facts (d_cat1_id)
    TABLESPACE ${INDEX_TABLESPACE};
CREATE ${USE_BITMAP_INDEX} INDEX mf_cat2_ix
    ON measurement_facts (d_cat2_id)
    TABLESPACE ${INDEX_TABLESPACE};
CREATE ${USE_BITMAP_INDEX} INDEX mf_os_ix
    ON measurement_facts (d_os_id)
    TABLESPACE ${INDEX_TABLESPACE};
CREATE ${USE_BITMAP_INDEX} INDEX mf_browser_ix
    ON measurement_facts (d_browser_id)
    TABLESPACE ${INDEX_TABLESPACE};

-- sequences for dimension ids
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE code_id_seq';
    EXCEPTION WHEN OTHERS THEN NULL; END;
/
CREATE SEQUENCE code_id_seq INCREMENT BY 1 START WITH 1;

BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE page_id_seq';
    EXCEPTION WHEN OTHERS THEN NULL; END;
/
CREATE SEQUENCE page_id_seq INCREMENT BY 1 START WITH 1;

BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE cat1_id_seq';
    EXCEPTION WHEN OTHERS THEN NULL; END;
/
CREATE SEQUENCE cat1_id_seq INCREMENT BY 1 START WITH 1;

BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE cat2_id_seq';
    EXCEPTION WHEN OTHERS THEN NULL; END;
/
CREATE SEQUENCE cat2_id_seq INCREMENT BY 1 START WITH 1;

BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE os_id_seq';
    EXCEPTION WHEN OTHERS THEN NULL; END;
/
CREATE SEQUENCE os_id_seq INCREMENT BY 1 START WITH 1;

BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE browser_id_seq';
    EXCEPTION WHEN OTHERS THEN NULL; END;
/
CREATE SEQUENCE browser_id_seq INCREMENT BY 1 START WITH 1;

-- time dimension
BEGIN EXECUTE IMMEDIATE 'DROP TABLE d_time';
    EXCEPTION WHEN OTHERS THEN NULL; END;
/
CREATE TABLE d_time (
    time_id     DATE         NOT NULL,   -- key is time TRUNCed to smallest interval (1 minute)
    -- foo_dt is time_id TRUNCed to foo interval
    yyyy        NUMBER(4)    NOT NULL,
    yyyy_dt     DATE         NOT NULL,
    mm          NUMBER(2)    NOT NULL, -- [1..12]
    mm_dt       DATE         NOT NULL,
    mon         VARCHAR2(3)  NOT NULL, -- [Jan..Dec]
    month       VARCHAR2(10) NOT NULL, -- [January..December]
    dd          NUMBER(2)    NOT NULL, -- [1..31]
    dd_dt       DATE         NOT NULL,
    hr          NUMBER(2)    NOT NULL, -- [00..23]
    hr_dt       DATE         NOT NULL,
    mi          NUMBER(2)    NOT NULL, -- [00..59]
    -- mi_dt is the same as time_id
    qtr         NUMBER(1)    NOT NULL, -- [1..4]
    qtr_dt      DATE         NOT NULL,
    iwk         NUMBER(2)    NOT NULL, -- [1..52]
    iwk_dt      DATE         NOT NULL,
    day_of_wk   NUMBER(1)    NOT NULL, -- [1..7]
    day_abbrv   VARCHAR2(3)  NOT NULL, -- [Sun..Sat]
    day_name    VARCHAR2(10) NOT NULL, -- [Sunday..Saturday]
    -- day/time characteristic periods
    weekend     NUMBER(1)    NOT NULL, -- 1=>true
    holiday     NUMBER(1)    NOT NULL, -- 1=>true
    morning     NUMBER(1)    NOT NULL, -- 1=>6am..noon
    afternoon   NUMBER(1)    NOT NULL, -- 1=>noon..6pm
    evening     NUMBER(1)    NOT NULL, -- 1=>6pm..midnight
    night       NUMBER(1)    NOT NULL, -- 1=>midnight..6am
    worktime    NUMBER(1)    NOT NULL, -- 1=>8am..5pm
    -- time intervals
    mi5         number(3)    NOT NULL, -- index of 5minute intervals in day [0..287]
    mi5_dt      DATE         NOT NULL,
    mi10        number(3)    NOT NULL, -- index of 10minute intervals in day [0..143]
    mi10_dt     DATE         NOT NULL,
    mi15        number(2)    NOT NULL, -- index of 15minute intervals in day [0..95]
    mi15_dt     DATE         NOT NULL,
    mi30        number(2)    NOT NULL, -- index of 30minute intervals in day [0..47]
    mi30_dt     DATE         NOT NULL,
    hr2         number(2)    NOT NULL, -- index of 2hour intervals in day [0..11]
    hr2_dt      DATE         NOT NULL,
    hr3         number(1)    NOT NULL, -- index of 3hour intervals in day [0..7]
    hr3_dt      DATE         NOT NULL,
    hr6         number(1)    NOT NULL, -- index of 6hour intervals in day [0..3]
    hr6_dt      DATE         NOT NULL,
    hr12        number(1)    NOT NULL, -- index of 6hour intervals in day [0..1]
    hr12_dt     DATE         NOT NULL,
    CONSTRAINT d_time_pk PRIMARY KEY
    (
        time_id
    ) USING INDEX TABLESPACE ${INDEX_TABLESPACE}
);

CREATE ${USE_BITMAP_INDEX} INDEX dt_yyyy_ix ON d_time (yyyy) TABLESPACE ${INDEX_TABLESPACE};
CREATE INDEX dt_yyyy_dt_ix ON d_time (yyyy_dt) TABLESPACE ${INDEX_TABLESPACE};
CREATE ${USE_BITMAP_INDEX} INDEX dt_mm_ix ON d_time (mm) TABLESPACE ${INDEX_TABLESPACE};
CREATE INDEX dt_mm_dt_ix ON d_time (mm_dt) TABLESPACE ${INDEX_TABLESPACE};
CREATE ${USE_BITMAP_INDEX} INDEX dt_mon_ix ON d_time (mon) TABLESPACE ${INDEX_TABLESPACE};
CREATE ${USE_BITMAP_INDEX} INDEX dt_month_ix ON d_time (month) TABLESPACE ${INDEX_TABLESPACE};
CREATE ${USE_BITMAP_INDEX} INDEX dt_dd_ix ON d_time (dd) TABLESPACE ${INDEX_TABLESPACE};
CREATE INDEX dt_dd_dt_ix ON d_time (dd_dt) TABLESPACE ${INDEX_TABLESPACE};
CREATE ${USE_BITMAP_INDEX} INDEX dt_hr_ix ON d_time (hr) TABLESPACE ${INDEX_TABLESPACE};
CREATE INDEX dt_hr_dt_ix ON d_time (hr_dt) TABLESPACE ${INDEX_TABLESPACE};
CREATE INDEX dt_mi_ix ON d_time (mi) TABLESPACE ${INDEX_TABLESPACE};
CREATE ${USE_BITMAP_INDEX} INDEX dt_qtr_ix ON d_time (qtr) TABLESPACE ${INDEX_TABLESPACE};
CREATE INDEX dt_qtr_dt_ix ON d_time (qtr_dt) TABLESPACE ${INDEX_TABLESPACE};
CREATE INDEX dt_iwk_ix ON d_time (iwk) TABLESPACE ${INDEX_TABLESPACE};
CREATE INDEX dt_iwk_dt_ix ON d_time (iwk_dt) TABLESPACE ${INDEX_TABLESPACE};
CREATE ${USE_BITMAP_INDEX} INDEX dt_day_of_wk_ix ON d_time (day_of_wk) TABLESPACE ${INDEX_TABLESPACE};
CREATE ${USE_BITMAP_INDEX} INDEX dt_day_abbrv_ix ON d_time (day_abbrv) TABLESPACE ${INDEX_TABLESPACE};
CREATE ${USE_BITMAP_INDEX} INDEX dt_day_name_ix ON d_time (day_name) TABLESPACE ${INDEX_TABLESPACE};
CREATE ${USE_BITMAP_INDEX} INDEX dt_weekend_ix ON d_time (weekend) TABLESPACE ${INDEX_TABLESPACE};
CREATE ${USE_BITMAP_INDEX} INDEX dt_holiday_ix ON d_time (holiday) TABLESPACE ${INDEX_TABLESPACE};
CREATE ${USE_BITMAP_INDEX} INDEX dt_morning_ix ON d_time (morning) TABLESPACE ${INDEX_TABLESPACE};
CREATE ${USE_BITMAP_INDEX} INDEX dt_afternoon_ix ON d_time (afternoon) TABLESPACE ${INDEX_TABLESPACE};
CREATE ${USE_BITMAP_INDEX} INDEX dt_evening_ix ON d_time (evening) TABLESPACE ${INDEX_TABLESPACE};
CREATE ${USE_BITMAP_INDEX} INDEX dt_night_ix ON d_time (night) TABLESPACE ${INDEX_TABLESPACE};
CREATE ${USE_BITMAP_INDEX} INDEX dt_worktime_ix ON d_time (worktime) TABLESPACE ${INDEX_TABLESPACE};
CREATE INDEX dt_mi5_ix ON d_time (mi5) TABLESPACE ${INDEX_TABLESPACE};
CREATE INDEX dt_mi5_dt_ix ON d_time (mi5_dt) TABLESPACE ${INDEX_TABLESPACE};
CREATE INDEX dt_mi10_ix ON d_time (mi10) TABLESPACE ${INDEX_TABLESPACE};
CREATE INDEX dt_mi10_dt_ix ON d_time (mi10_dt) TABLESPACE ${INDEX_TABLESPACE};
CREATE INDEX dt_mi15_ix ON d_time (mi15) TABLESPACE ${INDEX_TABLESPACE};
CREATE INDEX dt_mi15_dt_ix ON d_time (mi15_dt) TABLESPACE ${INDEX_TABLESPACE};
CREATE INDEX dt_mi30_ix ON d_time (mi30) TABLESPACE ${INDEX_TABLESPACE};
CREATE INDEX dt_mi30_dt_ix ON d_time (mi30_dt) TABLESPACE ${INDEX_TABLESPACE};
CREATE ${USE_BITMAP_INDEX} INDEX dt_hr2_ix ON d_time (hr2) TABLESPACE ${INDEX_TABLESPACE};
CREATE INDEX dt_hr2_dt_ix ON d_time (hr2_dt) TABLESPACE ${INDEX_TABLESPACE};
CREATE ${USE_BITMAP_INDEX} INDEX dt_hr3_ix ON d_time (hr3) TABLESPACE ${INDEX_TABLESPACE};
CREATE INDEX dt_hr3_dt_ix ON d_time (hr3_dt) TABLESPACE ${INDEX_TABLESPACE};
CREATE ${USE_BITMAP_INDEX} INDEX dt_hr6_ix ON d_time (hr6) TABLESPACE ${INDEX_TABLESPACE};
CREATE INDEX dt_hr6_dt_ix ON d_time (hr6_dt) TABLESPACE ${INDEX_TABLESPACE};
CREATE ${USE_BITMAP_INDEX} INDEX dt_hr12_ix ON d_time (hr12) TABLESPACE ${INDEX_TABLESPACE};
CREATE INDEX dt_hr12_dt_ix ON d_time (hr12_dt) TABLESPACE ${INDEX_TABLESPACE};

-- trigger will automatically calc and populate all the supported interval fields from time_id
CREATE OR REPLACE TRIGGER compute_time_dim
    BEFORE INSERT ON d_time
    FOR EACH ROW
    DECLARE
        base_dt DATE;
        beg_dt  DATE;
        miod    INTEGER; -- minute of day
        hrod    INTEGER; -- hour of day
    BEGIN
        -- time basis
        SELECT TRUNC(:new.time_id,'MI') INTO base_dt FROM DUAL;
        SELECT base_dt INTO :new.time_id FROM DUAL;
        SELECT TRUNC(base_dt) INTO beg_dt FROM DUAL; -- begining of day
        SELECT TRUNC( TO_NUMBER(TO_CHAR(base_dt,'SSSSS')) / 60 ) INTO miod FROM DUAL; -- minute of day
        SELECT TO_NUMBER(TO_CHAR(base_dt,'HH24')) INTO hrod FROM DUAL; -- hour of day

        -- years
        SELECT TRUNC(base_dt,'yyyy') INTO :new.yyyy_dt FROM DUAL;
        SELECT EXTRACT(YEAR from base_dt) INTO :new.yyyy FROM DUAL;

        -- months
        SELECT TRUNC(base_dt,'mm') INTO :new.mm_dt FROM DUAL;
        SELECT EXTRACT(MONTH from base_dt) INTO :new.mm FROM DUAL;
        SELECT TO_CHAR(base_dt,'Mon') INTO :new.mon FROM DUAL;
        SELECT TO_CHAR(base_dt,'Month') INTO :new.month FROM DUAL;

        -- days
        SELECT TRUNC(base_dt,'dd') INTO :new.dd_dt FROM DUAL;
        SELECT EXTRACT(DAY from base_dt) INTO :new.dd FROM DUAL;

        -- week days
        SELECT TO_NUMBER(TO_CHAR(base_dt,'D')) INTO :new.day_of_wk FROM DUAL;
        SELECT TO_CHAR(base_dt,'Day') INTO :new.day_name FROM DUAL;
        SELECT SUBSTR(TO_CHAR(base_dt,'Day'),1,3) INTO :new.day_abbrv FROM DUAL;
        SELECT DECODE(TO_NUMBER(TO_CHAR(base_dt,'D')),1,1,7,1,0) INTO :new.weekend FROM DUAL;

        -- hours
        SELECT TRUNC(base_dt,'HH24') INTO :new.hr_dt FROM DUAL;
        SELECT TO_NUMBER(TO_CHAR(base_dt,'HH24')) INTO :new.hr FROM DUAL;
        SELECT DECODE( TRUNC(TO_NUMBER(TO_CHAR(base_dt,'HH24'))/6), 0, 1, 0) INTO :new.night FROM DUAL;
        SELECT DECODE( TRUNC(TO_NUMBER(TO_CHAR(base_dt,'HH24'))/6), 1, 1, 0) INTO :new.morning FROM DUAL;
        SELECT DECODE( TRUNC(TO_NUMBER(TO_CHAR(base_dt,'HH24'))/6), 2, 1, 0) INTO :new.afternoon FROM DUAL;
        SELECT DECODE( TRUNC(TO_NUMBER(TO_CHAR(base_dt,'HH24'))/6), 3, 1, 0) INTO :new.evening FROM DUAL;
        SELECT CASE WHEN TO_NUMBER(TO_CHAR(base_dt,'HH24')) >= 8
                     AND TO_NUMBER(TO_CHAR(base_dt,'HH24')) <= 17
               THEN 1 ELSE 0 END INTO :new.worktime FROM DUAL;
        SELECT TRUNC(hrod/2) INTO :new.hr2 FROM DUAL;
        SELECT TRUNC(beg_dt + (TRUNC(hrod/2)*2/24), 'HH24') INTO :new.hr2_dt FROM DUAL;
        SELECT TRUNC(hrod/3) INTO :new.hr3 FROM DUAL;
        SELECT TRUNC(beg_dt + (TRUNC(hrod/3)*3/24), 'HH24') INTO :new.hr3_dt FROM DUAL;
        SELECT TRUNC(hrod/6) INTO :new.hr6 FROM DUAL;
        SELECT TRUNC(beg_dt + (TRUNC(hrod/6)*6/24), 'HH24') INTO :new.hr6_dt FROM DUAL;
        SELECT TRUNC(hrod/12) INTO :new.hr12 FROM DUAL;
        SELECT TRUNC(beg_dt + (TRUNC(hrod/12)*12/24), 'HH24') INTO :new.hr12_dt FROM DUAL;

        -- minutes
        SELECT TO_NUMBER(TO_CHAR(base_dt,'MI')) INTO :new.mi FROM DUAL;
        SELECT TRUNC(miod/5) INTO :new.mi5 FROM DUAL;
        SELECT TRUNC(beg_dt + (TRUNC(miod/5)*5/(24*60)), 'MI') INTO :new.mi5_dt FROM DUAL;
        SELECT TRUNC(miod/10) INTO :new.mi10 FROM DUAL;
        SELECT TRUNC(beg_dt + (TRUNC(miod/10)*10/(24*60)), 'MI') INTO :new.mi10_dt FROM DUAL;
        SELECT TRUNC(miod/15) INTO :new.mi15 FROM DUAL;
        SELECT TRUNC(beg_dt + (TRUNC(miod/15)*15/(24*60)), 'MI') INTO :new.mi15_dt FROM DUAL;
        SELECT TRUNC(miod/30) INTO :new.mi30 FROM DUAL;
        SELECT TRUNC(beg_dt + (TRUNC(miod/30)*30/(24*60)), 'MI') INTO :new.mi30_dt FROM DUAL;

        -- quarters
        SELECT TRUNC(base_dt,'Q') INTO :new.qtr_dt FROM DUAL;
        SELECT TO_NUMBER(TO_CHAR(base_dt,'Q')) INTO :new.qtr FROM DUAL;

        -- weeks
        SELECT TRUNC(base_dt,'IW') INTO :new.iwk_dt FROM DUAL;
        SELECT TO_NUMBER(TO_CHAR(base_dt,'IW')) INTO :new.iwk FROM DUAL;

        --TODO: holiday needs work
        SELECT 0 INTO :new.holiday FROM DUAL;

    END;
/
GRANT SELECT, UPDATE, INSERT ON d_time TO ${JIFFY_LOADER_USERNAME};
GRANT SELECT ON d_time TO ${JIFFY_READER_USERNAME};
/

-- page dimension
BEGIN EXECUTE IMMEDIATE 'DROP TABLE d_page';
    EXCEPTION WHEN OTHERS THEN NULL; END;
/
CREATE TABLE d_page (
    page_id     NUMBER          NOT NULL,
    page_name   VARCHAR2(255)   NULL,
    page_group1 VARCHAR2(255)   NULL,
    page_group2 VARCHAR2(255)   NULL,
    CONSTRAINT d_page_pk PRIMARY KEY
    (
        page_id
    ) USING INDEX TABLESPACE ${INDEX_TABLESPACE}
);
CREATE UNIQUE INDEX dp_name_ix
    ON d_page (page_name)
    TABLESPACE ${INDEX_TABLESPACE};
CREATE INDEX dp_group1_ix
    ON d_page (page_group1)
    TABLESPACE ${INDEX_TABLESPACE};
CREATE INDEX dp_group2_ix
    ON d_page (page_group2)
    TABLESPACE ${INDEX_TABLESPACE};

CREATE OR REPLACE TRIGGER dp_seq_id
    BEFORE INSERT ON d_page 
    FOR EACH ROW
    BEGIN
        IF :new.page_id IS NULL THEN
            SELECT page_id_seq.nextval INTO :new.page_id FROM DUAL;
        END IF;
    END;
/
GRANT SELECT, UPDATE, INSERT ON d_page TO ${JIFFY_LOADER_USERNAME};
GRANT SELECT ON d_page TO ${JIFFY_READER_USERNAME};
/

-- code dimension
BEGIN EXECUTE IMMEDIATE 'DROP TABLE d_code';
    EXCEPTION WHEN OTHERS THEN NULL; END;
/
CREATE TABLE d_code (
    code_id     NUMBER          NOT NULL,
    code        VARCHAR2(20)    NOT NULL,
    code_group1 VARCHAR2(255)   NULL,
    code_group2 VARCHAR2(255)   NULL,
    CONSTRAINT d_code_pk PRIMARY KEY
    (
        code_id
    ) USING INDEX TABLESPACE ${INDEX_TABLESPACE}
);
CREATE UNIQUE INDEX dc_name_ix
    ON d_code (code)
    TABLESPACE ${INDEX_TABLESPACE};
CREATE INDEX dc_group1_ix
    ON d_code (code_group1)
    TABLESPACE ${INDEX_TABLESPACE};
CREATE INDEX dc_group2_ix
    ON d_code (code_group2)
    TABLESPACE ${INDEX_TABLESPACE};

CREATE OR REPLACE TRIGGER dc_seq_id
    BEFORE INSERT ON d_code 
    FOR EACH ROW
    BEGIN
        IF :new.code_id IS NULL THEN
            SELECT code_id_seq.nextval INTO :new.code_id FROM DUAL;
        END IF;
    END;
/
GRANT SELECT, UPDATE, INSERT ON d_code TO ${JIFFY_LOADER_USERNAME};
GRANT SELECT ON d_code TO ${JIFFY_READER_USERNAME};
/

-- singleton table to store last detail processed
BEGIN EXECUTE IMMEDIATE 'DROP TABLE measurement_last_seq';
    EXCEPTION WHEN OTHERS THEN NULL; END;
/   
CREATE TABLE measurement_last_seq
(
    last_seq    NUMBER
);
INSERT INTO measurement_last_seq (last_seq) VALUES (0);

GRANT SELECT, UPDATE, INSERT ON measurement_last_seq TO ${JIFFY_LOADER_USERNAME};
GRANT SELECT ON measurement_last_seq TO ${JIFFY_READER_USERNAME};
/


-- temporary staging table for fact + dimension consruction
BEGIN EXECUTE IMMEDIATE 'DROP TABLE measurement_facts_stage';
    EXCEPTION WHEN OTHERS THEN NULL; END;
/   
CREATE TABLE measurement_facts_stage
(
    d_time_id       DATE    NOT NULL,   -- DATETIME is a natural unique key and easily indexed
    d_code_id       NUMBER  NULL,
    d_code          VARCHAR2(20) NOT NULL,
    d_page_id       NUMBER  NULL,
    d_page          VARCHAR2(255) NULL,
    d_cat1_id       NUMBER  NULL, -- awaiting support for this dimension
    d_cat1          VARCHAR2(255) NULL,
    d_cat2_id       NUMBER  NULL, -- awaiting support for this dimension
    d_cat2          VARCHAR2(255) NULL,
    d_os_id         NUMBER  NULL, -- awaiting support for this dimension
    d_os            VARCHAR2(255) NULL,
    d_browser_id    NUMBER  NULL, -- awaiting support for this dimension
    d_browser       VARCHAR2(255) NULL,
    et_count        NUMBER,
    et_sum          NUMBER,
    et_sum_squares  NUMBER,
    -- et_mean and et_std are functionally derived from sum, count, and sum of squares
    et_min          NUMBER,
    et_max          NUMBER,
    CONSTRAINT measurement_facts_stage_pk PRIMARY KEY
    (
        d_time_id,
        d_code,
        d_page,
        d_cat1,
        d_cat2,
        d_os,
        d_browser
    ) USING INDEX TABLESPACE ${INDEX_TABLESPACE}
);

GRANT SELECT, UPDATE, INSERT ON measurement_facts_stage TO ${JIFFY_LOADER_USERNAME};
GRANT SELECT ON measurement_facts_stage TO ${JIFFY_READER_USERNAME};
/

-- roll-up detailed log along the finiest time interval (1mi)
CREATE OR REPLACE VIEW jiffy_sum_detail_fine AS
SELECT
    TRUNC(server_time,'MI') stime
  , measurement_code
  , page_name
  , user_cat1
  , user_cat2
-- TODO: break user agent into OS/BROWSER dimension
--  , user_agent
  , NULL as os
  , NULL as browser
  , COUNT(elapsed_time) et_count
  , SUM(elapsed_time) et_sum
  , SUM(elapsed_time*elapsed_time) et_sum_squares
  , MIN(elapsed_time) et_min
  , MAX(elapsed_time) et_max
FROM measurement_view
GROUP BY
    TRUNC(server_time,'MI')
  , measurement_code
  , page_name
  , user_cat1
  , user_cat2
--  , user_agent
;

GRANT SELECT, UPDATE, INSERT ON jiffy_sum_detail_fine TO ${JIFFY_LOADER_USERNAME};
GRANT SELECT ON jiffy_sum_detail_fine TO ${JIFFY_READER_USERNAME};
/

" > $OUT1

echo "
CONNECT ${JIFFY_USERNAME}/${JIFFY_PASS}@${CONNECTSTRING};

CREATE OR REPLACE PACKAGE roll_up
IS
    FUNCTION next_minute(dt IN d_time.time_id%TYPE) RETURN d_time.time_id%TYPE;
    PROCEDURE extend_time_dim(beg_in IN d_time.time_id%TYPE, end_in IN d_time.time_id%TYPE);
    PROCEDURE roll_up_partition(part_in IN VARCHAR2, beg_in IN NUMBER, end_in IN NUMBER)
    PROCEDURE roll_up_range(beg_in IN NUMBER, end_in IN NUMBER);
    PROCEDURE roll_up_new;
END roll_up;
/
show errors

CREATE OR REPLACE PACKAGE BODY roll_up
IS
    HOURS_PER_DAY   INTEGER := 24;
    MINUTES_PER_DAY INTEGER := (HOURS_PER_DAY * 60);
    SECS_PER_DAY    INTEGER := (MINUTES_PER_DAY * 60);

    -- keeps size of each range roll-up to easily manageable chunks
    MAX_DETAILS_PER_ROLLUP INTEGER := 1000000;

    FUNCTION next_minute(dt IN d_time.time_id%TYPE) RETURN d_time.time_id%TYPE
    IS
        next_mi d_time.time_id%TYPE;
    BEGIN
        select round(dt+1/MINUTES_PER_DAY,'MI') into next_mi from dual;
        RETURN next_mi;
    END next_minute;

    PROCEDURE extend_time_dim(beg_in IN d_time.time_id%TYPE, end_in IN d_time.time_id%TYPE)
    IS
        dt      d_time.time_id%TYPE;
        beg_dt  d_time.time_id%TYPE;
        end_dt  d_time.time_id%TYPE;
    BEGIN
        -- fix range bounds
        select TRUNC(beg_in,'MI') into beg_dt from dual;
        select TRUNC(end_in,'MI') into end_dt from dual;
        select max(time_id)       into dt     from d_time;
        if beg_dt is null then
            if dt is null then
                raise_application_error(-20000, 'null begin date for extend_time_dim');
            else
                beg_dt := next_minute(dt);  -- start at next minute after current high
            end if;
        end if;
        if end_dt is null then
            -- default will extend to end of next day
            select trunc(beg_dt+1.99,'DD') into end_dt from dual;
        end if;
        
        -- loop, inserting d_time records for minute intervals
        dt := beg_dt;
        while dt < end_dt
        loop
            insert into d_time(time_id) values (dt);
            dt := next_minute(dt);
        end loop;
        commit;
    END extend_time_dim;
    
    PROCEDURE roll_up_partition(part_in IN VARCHAR2, beg_in IN NUMBER, end_in IN NUMBER)
    IS
    BEGIN
        dbms_output.put_line('part_in=' || to_char(part_in));
    END roll_up_range;

    PROCEDURE roll_up_range(beg_in IN NUMBER, end_in IN NUMBER)
    IS
    BEGIN
        dbms_output.put_line('beg=' || to_char(beg_in));
    END roll_up_range;
    
    PROCEDURE roll_up_new
    IS
        last    NUMBER;
        high     NUMBER;
    BEGIN
        select last_seq into last from measurement_last_seq;
        select max(seq) into high from measurement_view where seq >= last;
        rollup_range(last,high);
        update measurement_last_seq set last_seq = high+1;
        commit;
    END roll_up_new;

END roll_up;
/
show errors
" > $OUT2

echo ""
echo "****************************"
echo "* Generation Done"
echo "****************************"
echo ""
echo "Run the following scripts from your SQL prompt"
echo "  $ sqlplus /nolog @$OUT1"
echo "  $ sqlplus /nolog @$OUT2"
