# Meaningful Reporting #

Measuring performance in near-time requires an efficient and extendible mechanism to be effective.  Reporting on the data should meet three primary requirements:

  1. Timely - The data should be available as quick as possible. If it takes too long to see what's going on, you will not be able to act responsibly.
  1. Multi-format - A report available from only one place cannot reach all those who need to know the data. The data needs to be available in multiple formats through multiple means.
  1. Plentiful - there should be enough data to draw definitive conclusions

# What we've completed #

There's some good example code that generates single dynamic report with a chart. This report supports graphing at matrix of objects measurements over time. A configuration file uses presets to define the events that are going to be shown on the graph.

# To Be Done #

  1. Porting reporting to different databases, right now it only works against an Oracle XE database instance.
  1. Enable interval reporting with database rollups. Currently only a 1 hour interval is available. The plan is to support intervals varying from minutes to days and years.
  1. Support non-contiguous time selections spanning days (eg: peak hours, weekdays, etc.)
  1. Additional server-side components.

# Current Files #

The current files in the reporting samples are:

  1. dbconn.inc.php - database connect settings
  1. report.php - server-side php script to pull data from the database
  1. report.html - the web page
  1. report.js - graphing engine
  1. [config.js](ReportEventsConfig.md) - file to configure events