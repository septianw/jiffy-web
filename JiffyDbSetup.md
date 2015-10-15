# Setting up Jiffy Database #

In the database folder there are two setup scripts (`gen_jiffy_base_schema_oracle.sh` and `gen_jiffy_dw_schema_oracle.sh`) and an example config file (`jiffy_oracle.cfg`) which drives them.

To setup a jiffy database, you will need administrator access to an [Oracle XE](http://www.oracle.com/technology/products/database/xe/index.html) (or higher) database. Edit the sample config file supplying appropriate values for each keyword.

EMAIL\_FROM and EMAIL\_TO controls the sending of the schema creation reports via email for the base schema creation.

The base logging tables are created by running `gen_jiffy_base_schema_oracle.sh` and then executing the created PL/SQL scripts via an administrative session with SQL\*Plus. This will set-up the partitioning tables and views, declares tables through January of the next year, and establishes a job to extend the partitioning for another year at each year roll over.

## Setting up data warehouse ##

Using the same config file, run
```
 $ gen_jiffy_dw_schema_oracle.sh
 $ sqlplus /nolog @create_jiffy_dw_schema.sql
 $ sqlplus /nolog @create_jiffy_rollup_package.sql
```

This will create the fact and dimension tables and a ROLLUP package with functionality for incrementally updating from the base measurement tables.