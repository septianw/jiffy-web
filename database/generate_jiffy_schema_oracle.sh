#!/bin/sh

usage() 
{
  echo "Usage: generate_jiffy_schema.sh [config]"
}

if [ $# != 1 ]
then
  usage
  exit
else
  CONFIG=$1
fi

OUT1=create_jiffy_tablespace.sql
OUT2=create_jiffy_users.sql
OUT3=create_jiffy_schema.sql
OUT4=create_jiffy_manage_tables_proc.sql
OUT5=call_jiffy_manage_tables.sql
OUT6=create_jiffy_event.sql

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

JIFFY_USERNAME=$(get JIFFY_USERNAME)
JIFFY_PASS=$(get JIFFY_PASS)
JIFFY_LOADER_USERNAME=$(get JIFFY_LOADER_USERNAME)
JIFFY_LOADER_PASS=$(get JIFFY_LOADER_PASS)
JIFFY_READER_USERNAME=$(get JIFFY_READER_USERNAME)
JIFFY_READER_PASS=$(get JIFFY_READER_PASS)
TEMPORARY_TABLESPACE=$(get TEMPORARY_TABLESPACE)

EMAIL_FROM=$(get EMAIL_FROM)
EMAIL_TO=$(get EMAIL_TO)

echo ""
echo ""
echo "You have enter the following setttings:"
echo ""
echo "DATABASE=$DATABASE"
echo "JIFFY_USERNAME=$JIFFY_USERNAME" 
echo "JIFFY_PASS=$JIFFY_PASS"
echo "JIFFY_LOADER_USERNAME=$JIFFY_LOADER_USERNAME"
echo "JIFFY_LOADER_PASS=$JIFFY_LOADER_PASS"
echo "JIFFY_READER_USERNAME=$JIFFY_READER_USERNAME"
echo "JIFFY_READER_PASS=$JIFFY_READER_PASS"
echo ""
echo "Press enter to confirm your setting "
read dummy

#
# Begin creating schema
#

echo "CREATE TABLESPACE ${DATA_TABLESPACE} datafile '${DATA_FILENAME}' size ${DATA_FILESIZE} EXTENT MANAGEMENT LOCAL SEGMENT SPACE MANAGEMENT AUTO;
CREATE TABLESPACE ${INDEX_TABLESPACE} datafile '${INDEX_FILENAME}' size ${INDEX_FILESIZE} EXTENT MANAGEMENT LOCAL SEGMENT SPACE MANAGEMENT AUTO;
" > $OUT1

echo "-- Create Users
CREATE USER ${JIFFY_USERNAME} identified by ${JIFFY_PASS} DEFAULT TABLESPACE ${DATA_TABLESPACE} TEMPORARY TABLESPACE ${TEMPORARY_TABLESPACE} QUOTA UNLIMITED ON ${DATA_TABLESPACE}; 
GRANT create session, resource, create table, create view to ${JIFFY_USERNAME};

CREATE USER ${JIFFY_LOADER_USERNAME} identified by ${JIFFY_LOADER_PASS} DEFAULT TABLESPACE ${DATA_TABLESPACE} temporary tablespace ${TEMPORARY_TABLESPACE};
GRANT create session, resource to ${JIFFY_LOADER_USERNAME};

CREATE USER ${JIFFY_READER_USERNAME} identified by ${JIFFY_READER_PASS} DEFAULT TABLESPACE ${DATA_TABLESPACE} temporary tablespace ${TEMPORARY_TABLESPACE};
GRANT create session to ${JIFFY_READER_USERNAME};
" > $OUT2

echo "
CONNECT ${JIFFY_USERNAME}/${JIFFY_PASS};
--
--  TABLE OWNER ${JIFFY_USERNAME}
--
DROP TABLE MEASUREMENT_TYPES;
CREATE TABLE MEASUREMENT_TYPES
(
  CODE          VARCHAR2(20)    NOT NULL,
  NAME          VARCHAR2(100)   NOT NULL,
  DESCRIPTION   VARCHAR2(255),
  CONSTRAINT MEASUREMENT_TYPES_PK PRIMARY KEY
  (
    CODE
  ) USING INDEX TABLESPACE ${INDEX_TABLESPACE}
)
;

GRANT SELECT, UPDATE, INSERT ON ${JIFFY_USERNAME}.MEASUREMENT_TYPES TO ${JIFFY_LOADER_USERNAME};
GRANT SELECT ON ${JIFFY_USERNAME}.MEASUREMENT_TYPES TO ${JIFFY_READER_USERNAME};

INSERT INTO MEASUREMENT_TYPES
(CODE, NAME, DESCRIPTION)
VALUES ('DOMReady', 'On DOM Ready Event', 'Browser reports that DOM creation has been completed');

INSERT INTO MEASUREMENT_TYPES
(CODE, NAME, DESCRIPTION)
VALUES ('load', 'On Page Load Event', 'Browser reports body load has been complete');

INSERT INTO MEASUREMENT_TYPES
(CODE, NAME, DESCRIPTION)
VALUES ('unload', 'On Page Unload Event', 'Browser reports that the page unload has been completed');

INSERT INTO MEASUREMENT_TYPES
(CODE, NAME, DESCRIPTION)
VALUES ('searchDone', 'Principle Form Accepts Focus', 'Whitepages Search Form submit button receives forced onFocus event');

INSERT INTO MEASUREMENT_TYPES
(CODE, NAME, DESCRIPTION)
VALUES ('rsiDone', 'RSI JS Executed', 'Research Science third party javascript received and applied');

INSERT INTO MEASUREMENT_TYPES
(CODE, NAME, DESCRIPTION)
VALUES ('bannerDone', 'Top Banner Ad DOM object ready', 'Whitepages Top Banner DIV is an active DOM object');

CREATE SEQUENCE measurement_seq INCREMENT BY 1 START WITH 1;
" > $OUT3

echo "CONNECT ${JIFFY_USERNAME}/${JIFFY_PASS};
create or replace procedure jiffy_manage_tables(start_date varchar2, end_date varchar2)
as
  numofdays   number;
  crstr       varchar2(18000);
  l_mailhost  varchar2(64) := 'mail';
  l_from      varchar2(64) := '${EMAIL_FROM}';
  l_to        varchar2(64) := '${EMAIL_TO}';
  l_mail_conn UTL_SMTP.connection;
  l_subject   varchar2(100);
  l_message   varchar2(18000);
  l_crlf      constant varchar2(2) := chr(13) || chr(10);
  l_hostname  varchar2(100);
  l_bdate     varchar2(30);
  l_edate     varchar2(30);
  l_year      varchar2(4);

begin
  dbms_output.enable(1000000);
  select to_number(to_char(to_date(end_date || to_char(to_number(to_char(sysdate,'YYYY'))+1),'MMDDYYYY'),'J')) - 
         to_number(to_char(to_date(start_date || to_char(sysdate,'YYYY'),'MMDDYYYY'),'J')) 
    into numofdays 
  from dual;

  dbms_output.put_line('NUMOFDAYS ' || numofdays);

  select to_char(to_date(start_date || to_char(to_number(to_char(sysdate,'YYYY'))),'MMDDYYYY'),'J') into l_bdate from dual;
  select to_char(to_date(end_date || to_char(to_number(to_char(sysdate,'YYYY'))+1),'MMDDYYYY'),'J') into l_edate from dual;

  l_mail_conn := UTL_SMTP.open_connection(l_mailhost, 25);
  UTL_SMTP.helo(l_mail_conn, l_mailhost);
  UTL_SMTP.mail(l_mail_conn, l_from);
  UTL_SMTP.rcpt(l_mail_conn, l_to);
  l_subject := 'Subject: ' || l_hostname || ' : Caliper Table Creation Log' || l_crlf;
  l_message := 'Jiffy table creation program started.' || l_crlf ||
               'This program will create tables between the following dates ' || l_bdate ||' and '|| l_edate || l_crlf || l_crlf ||
               'The following tables have been created ' || l_crlf || l_crlf;

  begin
    

    for rec in (select to_char(to_date(start_date || to_char(sysdate,'YYYY'),'MMDDYYYY')+rownum-1,'YYYYMMDD') datestr
              from (select * from dual connect by level <= numofdays)
             )
    loop

      crstr := 'CREATE TABLE MEASUREMENT_' || rec.datestr ||
               '( ' ||
               ' UUID              VARCHAR2(32) NOT NULL,' ||
               ' MEASUREMENT_CODE  VARCHAR2(20) NOT NULL,' ||
               ' SEQ               NUMBER NOT NULL,' ||
               ' PAGE_NAME         VARCHAR2(255),' ||
               ' ELAPSED_TIME      NUMBER(7),' ||
               ' CLIENT_IP         CHAR(15),' ||
               ' USER_AGENT        VARCHAR2(255),' ||
               ' BROWSER           VARCHAR2(255),' ||
               ' OS                VARCHAR2(255),' ||
               ' SERVER            VARCHAR2(255),' ||
               ' SERVER_TIME       TIMESTAMP,' ||
               ' USER_CAT1         VARCHAR2(255),' ||
               ' USER_CAT2         VARCHAR2(255),' ||
               ' CONSTRAINT MEASUREMENT_' || rec.datestr || '_PK PRIMARY KEY' ||
               ' ( UUID, MEASUREMENT_CODE ) USING INDEX TABLESPACE ${INDEX_TABLESPACE}' ||
               ')';
    execute immediate crstr;

    crstr :=  'CREATE OR REPLACE TRIGGER m_seq_' || rec.datestr ||
              ' BEFORE INSERT ON measurement_' || rec.datestr ||
              ' FOR EACH ROW' ||
              ' BEGIN' ||
              '     SELECT measurement_seq.nextval INTO :new.seq FROM DUAL;' ||
              ' END';
    execute immediate crstr;
            
    crstr := 'CREATE INDEX IDX_MEA_' || rec.datestr || '_STIME_PNAME' ||
             ' ON MEASUREMENT_' || rec.datestr || '(SERVER_TIME, PAGE_NAME)';
    execute immediate crstr;

    crstr := 'CREATE UNIQUE INDEX IDX_MEA_' || rec.datestr || '_SEQ' ||
             ' ON MEASUREMENT_' || rec.datestr || '(SEQ)';
    execute immediate crstr;

    crstr := 'GRANT SELECT, UPDATE, INSERT ON MEASUREMENT_' || rec.datestr || ' TO ${JIFFY_LOADER_USERNAME}';
    execute immediate crstr;

    crstr := 'GRANT SELECT ON MEASUREMENT_' || rec.datestr || ' TO ${JIFFY_READER_USERNAME}';
    execute immediate crstr;

    l_message := l_message ||  'MEASUREMENT_' || rec.datestr || l_crlf;


    end loop;

    EXCEPTION
      WHEN OTHERS THEN
        l_subject := 'Subject: ERROR : Jiffy Table Creation Log' || l_crlf;
        l_message := '***** ERROR ****' || l_crlf || l_crlf ||
                     'The following errors were encountered during table creation: ' || l_crlf ||
                     SQLERRM || l_crlf || l_crlf || '***** ERROR ****' || l_crlf || l_crlf || l_message;
  end;

  -- 
  -- Create View
  -- 
  begin

    --
    -- create view
    --
    select to_char(sysdate,'YYYY') into l_year from dual;

    crstr := '';
    for trec in ( select decode(rownum,1,'create or replace VIEW MEASUREMENT_VIEW as select * from ' || table_name,
                                         '  union all select * from ' || table_name) sqlst
                  from user_tables where table_name like 'MEASUREMENT_' || l_year || '%')
    loop
      crstr := crstr || trec.sqlst;
    end loop;
    execute immediate crstr;

    crstr := 'GRANT SELECT ON MEASUREMENT_VIEW TO ${JIFFY_READER_USERNAME}';
    execute immediate crstr;

    l_message := l_message ||  'MEASUREMENT_VIEW created.' || l_crlf;

    EXCEPTION
      WHEN OTHERS THEN
        l_subject := 'Subject: ERROR : Jiffy Table Creation Log' || l_crlf;
        l_message := '***** ERROR ****' || l_crlf || l_crlf ||
                     'The following errors were encountered during table creation: ' || l_crlf ||
                     SQLERRM || l_crlf || l_crlf || '***** ERROR ****' || l_crlf || l_crlf || l_message;

  end;

  l_message := l_subject || l_message;
  UTL_SMTP.data(l_mail_conn, l_message);
  UTL_SMTP.quit(l_mail_conn);

end;
/" > $OUT4

echo "CONNECT ${JIFFY_USERNAME}/${JIFFY_PASS};
exec jiffy_manage_tables('0101','0131');
" > $OUT5

echo "CONNECT ${JIFFY_USERNAME}/${JIFFY_PASS};
declare
  v_jobnum number;
begin
  dbms_job.submit(v_jobnum, 'begin jiffy_manage_tables(''0201'',''0131''); end;', to_date(to_char(to_number(to_char(sysdate,'YYYY'))+1) || '0101 00:05:00','YYYYMMDD HH24:MI:SS'),'sysdate + interval ''1'' year');
end;
/" > $OUT6

echo ""
echo "****************************"
echo "* Generation Done"
echo "****************************"
echo ""
echo "Run the following scripts from your SQL prompt"
echo "  SQL> @$OUT1"
echo "  SQL> @$OUT2"
echo "  SQL> @$OUT3"
echo "  SQL> @$OUT4"
echo "  SQL> @$OUT5"
echo "  SQL> @$OUT6"
