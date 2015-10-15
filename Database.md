# Jiffy Database #

Logically Jiffy uses two database schemas, one for collecting the detailed jiffy measurements, the other to roll up these measures into a data warehouse dimensioned cube for reporting and analysis. By default both schemas exist in the same database instance and namespace, but could easily be separated.

See JiffyDbSetup for details on configuring the database.

## Measurement details ##

The principal data logged by jiffy is collected into MEASUREMENT table(s) containing tuple:

  * UID
  * MEASUREMENT\_CODE
  * SEQ
  * ELAPSED\_TIME
  * SERVER\_TIME
  * SERVER
  * PAGE\_NAME
  * CLIENT\_IP
  * USER\_AGENT
  * BROWSER
  * OS
  * USER\_CAT1
  * USER\_CAT2

UID,MEASUREMENT\_CODE form the primary key: UID uniquely identifies the page request associated with the measure and MEASUREMENT\_CODE identifies the type of measurement.

SEQ is an auto-incrementing sequence used to track which measurement details have already been digested into the datawarehouse roll-ups.

ELAPSED\_TIME records the measured time in millseconds.

BROWSER and OS are derived from USER\_AGENT. These are presently stubbed and will always be NULL until we implement a mapping function.

SERVER\_TIME is the time stamp from the logging server; SERVER is the hostname of the logging server.

PAGE\_NAME is the logical name of the measured page which may be set explicitly by the client side instrumentation, or will be the full URI of the request if not supplied.

USER\_CAT1 and USER\_CAT2 are optional columns for developers to add their custom fields. They're not yet supported by Jiffy.js - they're for future use only.


In addition there is a MEASUREMENT\_TYPES table allowing more descriptive annotations for measurement codes (CODE VARCHAR2(20), NAME VARCHAR2(100), DESCRIPTION VARCHAR2(2000)).

## Partitioning details ##

Jiffy was designed to accommodate measuring very high traffic web sites. The initial implementation partitions logs by day.

To accommodate future database portability (and avoid expensive licensing options), we do not use the built in partitioning mechanisms of Oracle, but instead make multiple tables of the form MEASUREMENT\_YYYYMMDD, and create a a master view MEASUREMENT\_VIEW which presents a union of the daily partitions.

The data ingestor program is cognizant of the partitioning and explicitly targets the appropriate table for insertion.

Likewise the roll-up mechanisms also comprehend the partitioning when needed for efficiency. In general, queries against the unifying view may be efficient if they include where clauses which target the available indices on SEQ, SERVER\_TIME, or GUID+MEASUREMENT\_CODE. Beware if not predicating on one of this fields as the Oracle query planner will degenerate to full table scans of the component partitions.


## Data warehouse ##

The reporting and analysis schema is composed of a star schema with a summary MEASUREMENT\_FACTS table which contains aggregated statistical results of the details grouped by several dimensions: TIME, CODE, PAGE for now; with intent to implement dimensioning for BROWSER, OS, and the two USER\_CATs soon.

The facts are aggregated at the smallest useful time interval, currently 1-minute.  This still produces a rather large set of data and expect it will be desirable to age roll-ups so only most recent activity (say a few days or weeks) is kept available at minute intervals, and older data my be re rolled to be retained at larger intervals (eg: hourly for recent months, daily for prior years) to reduce storage and query costs for aged data.

The roll-up facility will auto extend the dimension tables as new values are discovered.