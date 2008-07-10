#!/usr/bin/env ruby
#

require "rubygems"
require "activerecord"
require "yaml"
require "getoptlong"

def load_config(filename)
  YAML.load_file(filename)
end

def new_context(config)
  "
   CREATE DATABASE #{config['database']};
   USE #{config['database']};

   CREATE USER '#{config['username']}'@'%' IDENTIFIED BY '#{config['password']}'; 
   GRANT SELECT, INSERT, CREATE, INDEX, TRIGGER ON #{config['database']} TO '#{config['username']}'@'%';

   CREATE USER '#{config['loader_username']}'@'%' IDENTIFIED BY '#{config['loader_password']}';
   GRANT SELECT, INSERT ON #{config['database']}.* TO '#{config['loader_username']}'@'%';

   CREATE USER '#{config['reader_username']}'@'%' IDENTIFIED BY '#{config['reader_password']}';
   GRANT SELECT ON #{config['database']}.* TO '#{config['reader_username']}'@'%';
   
   DROP TABLE MEASUREMENT_TYPES;
   CREATE TABLE MEASUREMENT_TYPES
   (
     CODE          VARCHAR(20)    NOT NULL,
     NAME          VARCHAR(100)   NOT NULL,
     DESCRIPTION   VARCHAR(2000),
     PRIMARY KEY(CODE)
   );

   GRANT SELECT, UPDATE, INSERT ON #{config['database']}.MEASUREMENT_TYPES TO '#{config['loader_username']}'@'%';
   GRANT SELECT ON #{config['database']}.MEASUREMENT_TYPES TO '#{config['reader_username']}'@'%';

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

   DROP TABLE MEASUREMENT_SEQ;
   CREATE TABLE MEASUREMENT_SEQ
   (
   	 SEQ       BIGINT NOT NULL AUTO_INCREMENT,
  	 PRIMARY KEY(SEQ)
   );
   
   FLUSH PRIVILEGES;
   "
end

def new_measurement_table(date, config)
 " 
   DROP TABLE MEASUREMENT_#{date};
   CREATE TABLE MEASUREMENT_#{date} (
          UUID VARCHAR(32) NOT NULL,
          MEASUREMENT_CODE VARCHAR(20) NOT NULL,
          SEQ BIGINT NOT NULL,
          PAGE_NAME VARCHAR(255),
          ELAPSED_TIME INT(7),
          CLIENT_IP CHAR(15),
          USER_AGENT VARCHAR(255),
          BROWSER VARCHAR(255),
          OS VARCHAR(255),
          SERVER VARCHAR(255),
          SERVER_TIME DATETIME,
          USER_CAT1 VARCHAR(255),
          USER_CAT2 VARCHAR(255),
          CONSTRAINT MEASUREMENT_#{date}_PK PRIMARY KEY ( UUID, MEASUREMENT_CODE )
   );

   CREATE INDEX IDX_MEA_#{date}
          ON MEASUREMENT_#{date} (SERVER_TIME, PAGE_NAME);

   CREATE UNIQUE INDEX IDX_MEA_#{date}_SEQ
          ON MEASUREMENT_#{date} (SEQ);

   GRANT SELECT, UPDATE, INSERT ON #{config['database']}.MEASUREMENT_#{date} TO '#{config['loader_username']}'@'%';

   GRANT SELECT ON #{config['database']}.MEASUREMENT_#{date} TO '#{config['reader_username']}'@'%';

   FLUSH PRIVILEGES;
   
   DELIMITER ,
   CREATE TRIGGER M_SEQ_#{date} BEFORE INSERT ON MEASUREMENT_#{date}
          FOR EACH ROW BEGIN
            INSERT INTO MEASUREMENT_SEQ SET SEQ=NULL;
            SET NEW.SEQ=LAST_INSERT_ID();
          END
   ,
   DELIMITER ;"
end

def new_measurement_merge_table(merge_tables, config)
  "
   DROP TABLE MEASUREMENT_VIEW;
   CREATE TABLE MEASUREMENT_VIEW (
          UUID VARCHAR(32) NOT NULL,
          MEASUREMENT_CODE VARCHAR(20) NOT NULL,
          SEQ BIGINT NOT NULL,
          PAGE_NAME VARCHAR(255),
          ELAPSED_TIME INT(7),
          CLIENT_IP CHAR(15),
          USER_AGENT VARCHAR(255),
          BROWSER VARCHAR(255),
          OS VARCHAR(255),
          SERVER VARCHAR(255),
          SERVER_TIME DATETIME,
          USER_CAT1 VARCHAR(255),
          USER_CAT2 VARCHAR(255),
          CONSTRAINT MEASUREMENT_VIEW_PK PRIMARY KEY ( UUID, MEASUREMENT_CODE )
   ) ENGINE=MERGE UNION=(#{merge_tables.join(',')}) INSERT_METHOD=NO;

   GRANT SELECT ON #{config['database']}.MEASUREMENT_VIEW TO '#{config['reader_username']}'@'%';
   FLUSH PRIVILEGES;
  "
end

def usage
  puts "
usage: #{$0} [-ho] -c <config> -s <YYYYMMDD> -e <YYYYMMDD>

 -h/--help          : this message
 -c/--config        : name of the YAML configuration file with database and user 
                      parameters (default is jiffy_db_config.yml)
 -o/--context-only  : skip generation of measurement tables
 -m/--measurement-only  : only generate measurement tables
 -s/--start-date    : starting day for measurement tables, formatted as YYYYMMDD
 -e/--end-date      : ending day for measurement tables, formatted as YYYYMMDD 
                      (must be later than start-date)
 "
  exit
end

opts = GetoptLong.new(
     [ '--help', '-h', GetoptLong::NO_ARGUMENT ],
     [ '--measurement-only', '-m', GetoptLong::NO_ARGUMENT ],
     [ '--context-only', '-o', GetoptLong::NO_ARGUMENT ],
     [ '--config', '-c', GetoptLong::REQUIRED_ARGUMENT ],
     [ '--start-date', '-s', GetoptLong::REQUIRED_ARGUMENT ],
     [ '--end-date', '-e', GetoptLong::REQUIRED_ARGUMENT ]
   )
config_file = "jiffy_db_config.yml"
start_date = nil
end_date = nil
context_only = false
measurement_only = false
opts.each do |opt, arg|
  case opt
  when '--help'
    usage
  when '--config'
    config_file = arg.to_s
  when '--start-date'
    start_date = Date.parse(arg.to_s)
  when '--end-date'
    end_date = Date.parse(arg.to_s)
  when '--context-only'
    context_only = true
  when '--measurement-only'
    measurement_only = true
  end
end

usage unless (start_date && (end_date - start_date > 0))

@config = load_config(config_file)
unless measurement_only
  puts new_context(@config)
end
unless context_only
  merge_tables = []
  start_date.upto(end_date) { |date| 
    puts new_measurement_table(date.strftime("%Y%m%d"), @config)
    merge_tables << "MEASUREMENT_#{date.strftime("%Y%m%d")}"
  }
  puts new_measurement_merge_table(merge_tables, @config)
end

