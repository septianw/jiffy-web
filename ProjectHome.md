## Jiffy Overview ##

Jiffy is an end-to-end real-world web page instrumentation and measurement suite. The first beta was released on 6/23/2008, as announced at [O'Reilly Velocity 2008](http://en.oreilly.com/velocity2008/public/schedule/detail/4404). Here's a [a copy of the slides](http://code.whitepages.com/talks/Velocity%20-%20Introducing%20Jiffy%20-%202008-06-23.pdf) and [here's the video](http://blip.tv/file/1018527).

Jiffy was built and is maintained by the [WhitePages.com](http://www.whitepages.com/) team.

Jiffy allows developers to

  * measure individual pieces of page rendering (script load, AJAX execution, page load, etc.) on every client
  * report those measurements and other metadata to a web server
  * aggregate web server logs into a database
  * generate reports

Additionally, using the [Jiffy extension for Firebug](http://billwscott.com/jiffyext/) built by Bill Scott from Netflix, developers can see and test Jiffy-based measurements.

## Jiffy Components ##

The system consists of the following components:

  * Jiffy.js, the Javascript library used for generating measurements; it's tested across IE6 & 7, FF2 & 3, and Safari 3. [Documentation here](http://code.google.com/p/jiffy-web/wiki/Jiffy_js).
  * Apache proxy (httpd.conf) [configuration](http://code.google.com/p/jiffy-web/source/browse/trunk/ingestor/jiffy.httpd.conf) for logging Jiffy posts
  * An ingestor (written in Perl) which runs on the Apache server and posts logs to a database through DBI. [Documentation here](http://code.google.com/p/jiffy-web/wiki/Data_Ingestor), plus a SampleJiffyLog.
  * Working DDLs for [Oracle XE](http://www.oracle.com/technology/products/database/xe/index.html) and higher. [Documentation here](http://code.google.com/p/jiffy-web/wiki/Database). We haven't (yet) provided DDL's for other databases, but the database model described in the documentation has been tested in a MySQL installation.
  * Reporting rollup code for Oracle (MySQL to come)
  * A [reporting UI](ReportingUI.md) using the Yahoo! User Interface library

![http://jiffy-web.googlecode.com/svn/Jiffy.png](http://jiffy-web.googlecode.com/svn/Jiffy.png)

## Using Jiffy ##

You can use Jiffy end-to-end by

  * including Jiffy.js in your pages and instrumenting them with the appropriate mark and measure calls
  * Making the configuration changes needed to your proxy
  * Adding the ingestor as a cron job on your web servers, with appropriate connection strings
  * Setting up the data model
  * Editing the reporting configuration and deploying the reporting tools

More simply, you can combine Jiffy and the Firebug add-in to view Mark & Measure results for a single developer client.

Note that there are a fair number of dependencies across the system, assuming that you can set up a fairly heterogeneous environment. Obviously much of the code and config is easily ported to single systems, and we may later combine parts.

  * Apache 2.X for the proxy config (untested in previous versions, but it will probably work)
  * Perl 5.8 or later for the ingestor
  * Oracle XE and higher
  * PHP >5.2.0 or PECL json: >= 1.2.0 for the reporting tools, plus online access to the Yahoo! User Interface Library (which you could copy and serve in-house)

To use Jiffy, checkout the source from the Source tab above. You'll need an svn client.

## Contacting Us ##

We're currently supporting the project through the [jiffy-web Google Group](http://groups.google.com/group/jiffy-web): please send questions, problems, etc. there.

## Join the Project! ##

There's still plenty of work to do to improve Jiffy, including

  * More database options (we really need a MySQL port)
  * Improvements to reporting tools
  * A means to glue jiffy.js to your automated test suite
  * Documentation and use-case improvement
  * Aggregated log parsing (rather than per-web-server log parsing) as an option

We're still figuring out the plan for accepting patches - for now we're going to use the Google Group for everything.