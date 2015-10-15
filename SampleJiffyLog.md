# Sample Jiffy Log File #

We've included a sample file of real Jiffy data to test the Data\_Ingestor (or any similar code you need to write). The sample is [jiffy.log.example](http://code.google.com/p/jiffy-web/source/browse/trunk/examples/jiffy.log.example) in the ingestor directory.

This is real data from WhitePages.com (with queries with addresses and phone numbers removed). This sample shows three different measurements: page load, page unload, and a single simple Jiffy event, similar to the one in the [sample from the slide deck](http://code.whitepages.com/talks/Velocity%20-%20Introducing%20Jiffy%20-%202008-06-23.pdf).

Each row contains

  * IP
  * Server Time
  * Jiffy request: note that we override both uid and pn to our own internal values, as described in [Jiffy\_js](http://code.google.com/p/jiffy-web/wiki/Jiffy_js)
  * Return code: note that the ingestor only processes 200's
  * URL: note that the ingestor cuts this at 255 characters
  * User Agent
  * Full Domain Name (ignored by the ingestor today)