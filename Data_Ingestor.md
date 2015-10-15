# Introduction #
The ingestor is written in Perl and currently requires one non-core module, DBI (DBI is licensed differently then Jiffy).  The ingestor was designed to be lightweight, only relying on functionality available in the core distribution, and is capable of processing several thousand lines a second without using a lot of CPU on your web servers.

The script can be run as a CRON job to ingest the Apache logs into the data store ([example](http://code.google.com/p/jiffy-web/source/browse/trunk/ingestor/jiffy.cron.example?r=60)). It is setup to accept and parse both the on demand measures and the bulk measures. The format for these two types of log entries look like the following:

**bulk:**
172.25.1.161 [13/Jun/2008:14:39:24 -0700] "?uid=13304334331213393192942&st=1213393192942&pn=PERS\_RESULTS\_1&ets=scriptDone:46,bannerDone:15,load:1625"

**on-demand:**
172.25.1.161 [13/Jun/2008:14:39:24 -0700] "?uid=13304334331213393192942&st=1213393192942&pn=PERS\_RESULTS\_1&ets=scriptDone:46"

## Usage ##
```
usage: ./performance_log_inserter.pl [-hVD] -l <file> -m <value> -W <value> -O|-M -c <client path> -H <host> -U <user> [-P <passwd>]

 -h		: this message
 -V		: verbose output
 -D		: debug mode (no database interaction)
 -l <file>	: file containing jiffy logs
 -m <value>     : maximum number of lines to process this time (default 100000)
 -O|-M		: use Oracle | MySQL (COMING SOON)
 -c <path>	: path to client (ie ORACLE_HOME)
 -A <file>	: file containing database auth (COMING SOON)
 -H		: database host (or tnsname if -O)
 -U		: database user
 -P		: database password
 -W             : time in seconds to silently allow previous job to run
```
## Notes ##

The ingestor is meant to run on the web servers configured to log Jiffy measurements and insert these logs into the partitioned detail records in the logging database. Jiffy can produce a lot of logs, depending on your traffic and the number of measurement probes. The ingestor keeps a small file where it records the inode and last byte processed on the log file, and uses this to capture new logs for insertion into the logging database at each run.

WhitePages.com has been successfully aggregating over 40M measures per day over a dozen web servers with the ingestor running at 1 minute intervals from a cron job and aggregating to a modest dual P4 Oracle server. During peak periods, the central database can get very busy and it's possible for a one minute insertion job to take longer then a minute. The -W flag specifies how long the inserter will let previous jobs hold the lock before complaining.

We have plans to support multiple databases, including MySQL and PostgreSQL, but the initial release only has full support for Oracle.

The ingestor has been tested with Perl v5.8.8 and likely works with any 5.8 version or later (but YMMV).