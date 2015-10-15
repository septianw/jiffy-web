> Jiffy.js file is the core Javascript library for instrumenting your pages.


---


# Mark & Measure #

Mark and Measure are the fundamental concepts around building page measurements.

  * **Mark** names a moment in time. (Time is current client time as captured by Javascript.)
  * **Measure** returns the elapsed time between now and the previous named mark.

Each measure is then combined with some metadata and then either posted immediately back to the web server or held for a bulk post at the end of measure processing.

Here's an example timing the loading and execution of a Javascript call:

```
<script type="text/javascript">
  Jiffy.mark("slowThirdPartyStart");
</script>

<script type="text/javascript" src="http://www.slowsite.com/slow.js"></script>

<script type="text/javascript">
  Jiffy.measure("slowThirdPartyDone", "slowThirdPartyStart");
</script>
```

All measures are captured into a JSON object that can be accessed through the public method Jiffy.getMeasures() The return is a JSON object with a sample layout which looks like the following:

```
{
  "PageStart": { et: 2676, m: [
     {et:2676, evt:"load", rt:1213159816044}
   ]},
  "onLoad": { et: 74, m: [
     {et:7,  evt:"carouselcreated", rt:1213159818722},
     {et:67, evt:"finishedonLoad",  rt:1213159818729}
   ]}
}
```


---



# Jiffy Parameters #
JiffyParams is a globally scoped hash. Including these parameters are optional.

  * **jsStart**: This is the start time, which we report in each measurement, and is used for default browser measurements. Because this is when Jiffy starts timing, you want this to be as far at the top of the page as possible. If Jiffy.js is loaded at the top of the page and you don't need to override any of the parameters below, you don't need this call; if you aren't loading Jiffy.js at the top of the page, you want to include this at the top. If you do set jsStart through this hash, the hash must be called **before** Jiffy.js is loaded.

  * **uid**: This is a unique ID that will be used in reporting to link all measures together as a single page. If you don't provide a uid, we'll create a random one using Javascript's Math.random(). (For non-crypto uses and with little concern about occasional overlap, Math.random() is fine, but overall Math.random()'s entropy is questionable: [you can read more here](http://objectmix.com/javascript/120715-math-random-algorithm.html).)

  * **pname**: The name of the page you are measuring. This is used for reporting. If you don't provide a pname, Jiffy will pass the current window.location (generally the URL unless you override).

example:

```
<script type="text/javascript">
  var JiffyParams = {
     jsStart: (new Date()).getTime(),
     uid: <xsl:value-of select="/page/settings/random" />,
     pname: '<xsl:value-of select="$pagename" />'
  }
</script>
```


# Jiffy Options #

Jiffy.js sets some options, overridable in your own content with a globally scoped hash named JiffyOptions. These are usually set sitewide.

  * **USE\_JIFFY** - record and log measures

  * **ISBULKLOAD** - use the bulk load function which gathers all marks and measures and sends them as one request on the OnLoad event.

  * **BROWSER\_EVENTS** - built in browser events that will be measured automatically if listed in this hash. Examples include load, unload, & DOMReady. Note that there is some interaction between these two options: since ISBULKLOAD posts the measures on the OnLoad event and unload happens after load, the unload event (if included) will always post as a separate measure.

  * **SOFT\_ERRORS** - Allows you to view try statement errors by displaying them in an alert.


example:
```
<script type="text/javascript">
  JiffyOptions = {
    USE_JIFFY:true,
    ISBULKLOAD: true,
    BROWSER_EVENTS: {"unload":window,"load":window},
    SOFT_ERRORS: false
  };
</script>
```


---


# Jiffy Batch & Realtime logging #

There are two different methods, batch and realtime, that can be used to send data to the Apache log.

**Batch**

Batch will take all measures that are captured before page load (including the load event) and post them in one single AJAX call to the server. The URL format for this is
```
yourURL.com/rx?uid=xxxxxxx,st=xxxxx,pn=somename,ets=slowJS:12,evenslowerJS:190
```

**Realtime**

Realtime will take measures as they are happening and send them as the calls to Jiffy.measure happen. This will allow you to get data as it is happening, and in the case where someone may drop off before the page load event is executed, you still get some data from the client. The format is the same except that ets will only contain one element.
```
yourURL.com/rx?uid=xxxxxxx,st=xxxxx,pn=somename,ets=slowJS:12
```
In each case,
  * **uid** - Unique session id for the page, either automatically created or overridden as above.
  * **st** - start time of the page, set by the jsStart() call.
  * **pn** - page name, either window.location() or overridden as above.
  * **ets** - Elapsed times serialized. Each element in this object is the name of the measure and its elapsed time, e.g. `slowJS(measure name):12(elapsed time)`



