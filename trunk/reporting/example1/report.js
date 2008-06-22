(function() {
    var Dom = YAHOO.util.Dom,
        Event = YAHOO.util.Event;
	// Location of Flash file used for charts
    YAHOO.widget.Chart.SWFURL = "http://yui.yahooapis.com/2.5.2/build/charts/assets/charts.swf";
	// Primary Page Object
    var Page = {
        EventTypes: {
			handleSuccess: function(r) {
				this.list = YAHOO.lang.JSON.parse(r.responseText);
				return;
			},
			handleFailure: function(r) {
				return false;
			},
			getEventName: function(str) {
				return (this.list[str]) ? this.list[str]['NAME'] : str;
			},
			// Array of values which determine which lines show on the graph
			loadEvents: {
				load: true,
				rsiDone: false,
				veDone: false
			}
        },
        StatData: {
            handleSuccess: function(r) {
                this.rawdata = YAHOO.lang.JSON.parse(r.responseText);
                this.processData();
                return;
            },
            handleFailure: function(r) {
                return false;
            },
			// This method actually draws the chart as a result of an asynchronous data call
            processData: function() {
				this.data = [];
				// This ensures clean and clear data from the async call
				for ( var i=0,len=this.rawdata.rows.length;i<len;i++ ) {
					this.data.push(this.rawdata.rows[i]);
				}
                this.dataSource = new YAHOO.util.DataSource(this.data);
                this.dataSource.responseType = YAHOO.util.DataSource.TYPE_JSARRAY;
                this.dataSource.responseSchema = {
                    fields: [ "stime", "ftime", "load", "veDone", "rsiDone" ]
                };
                var yAxis = new YAHOO.widget.NumericAxis();
				// Statistcally load should be the longest, this should change
				// into a check on each measure to find the highest
                yAxis.maximum = this.findMaxByKey(this.data,'load');
                yAxis.majorUnit = 1000;
                yAxis.minorUnit = 250;
                yAxis.labelFunction = Page.formatYAxisLabel;
				// Chart creation
                Page.flashChart = new YAHOO.widget.LineChart('chartContainer',this.dataSource,{
                    series: this.buildSeries(),
                    xField: 'stime',
                    yAxis: yAxis,
                    style: {
						legend: {
							display: 'bottom'
						},
						animationEnabled: false,
                        yAxis: {
                            minorGridLines: { size: 0.250 },
                            majorGridLines: { size: 1 }
                        }
                    },
					dataTipFunction: Page.getDataTipText
                });
            },
			// Build the series data based upon the contents of the event types load data
			buildSeries: function() {
				var series = [];
				if ( Page.EventTypes.loadEvents.load ) {
					series.push({
						displayName: Page.EventTypes.getEventName('load'),
						yField: 'load',
						style: { color: 0x0000cc, size: 7 }
					});
				}
				if ( Page.EventTypes.loadEvents.veDone ) {
					series.push({
						displayName: Page.EventTypes.getEventName('veDone'),
						yField: 'veDone',
                        style: { color: 0xcc0000, size: 7 }
					});
				}
				if ( Page.EventTypes.loadEvents.rsiDone) {
					series.push({
                        displayName: Page.EventTypes.getEventName('rsiDone'),
                        yField: 'rsiDone',
                        style: { color: 0x00cc00, size: 7 }
					});
				}
				return series;
			},
			// Chart update method - rereads the form fields and performs an async call to get new data
            updateChart: function() {
                var postData = {
                    v: 'measures',
                    interval: Dom.get('txtInterval').value
                };
				var sdte = Dom.get('txtStartDate');
				if ( sdte.value!=='' ) {
					postData.start = sdte.value;
				} else {
					var d = new Date();
					sdte.value  = d.getFullYear() +'-';
					sdte.value += ((d.getMonth()+1)>9) ? (d.getMonth()+1) : '0' + (d.getMonth()+1);
					sdte.value += ((d.getDate()-1)>9) ? '-' + (d.getDate()-1) : '-0' + (d.getDate()-1);
				}
				var edte = Dom.get('txtEndDate');
				if ( edte.value!=='' ) {
					postData.end = edte.value;
				} else {
					edte.value = sdte.value;
				}
                YAHOO.util.Connect.asyncRequest('POST','report.php', {
                    success: Page.StatData.handleSuccess,
                    failure: Page.StatData.handleFailure,
                    scope: Page.StatData
                }, Page.serialize(postData));
				if ( (sdte.value == edte.value) ) {
					Dom.get('pageTitle').innerHTML = Page.prettyDate(sdte.value);
				} else {
					Dom.get('pageTitle').innerHTML = Page.prettyDate(sdte.value) + ' to ' + Page.prettyDate(edte.value);
				}
            },
			// walks an array to find the max of a value
			findMaxByKey: function(obj,key) {
				var a=0; var i;
				for (i=0;i<obj.length;i++) { a = Math.max(a,obj[i][key]); }
				var high = (Math.round(Math.ceil(a*1.1)/250))*250;
                return (high > 10000) ? high : 10000;
			}
        },
		formatYAxisLabel: function(val) {
			return YAHOO.util.Number.format(val/1000, {
				decimalPlaces: 3
			});
		},
		getDataTipText: function(item,idx,series) {
			var tiptext = series.displayName + "\n" + item.ftime;
			tiptext += "\n" + Page.formatYAxisLabel(item[series.yField]) + " seconds";
			return tiptext;
		},
		// used to create a url encodded string
        serialize: function(obj) {
            var str = '';
            if ( typeof(obj) == 'object' ) {
                for (key in obj) { str += escape(key)+'='+escape(obj[key])+'&'; }
            }
            return str.replace(/&$/,'');
        },
		// Regex to parse a common date format
		reDate: /(\d{4})-(\d{2})-(\d{2})/,
		// Make a date pretty
		prettyDate: function(str) {
			var aDt = Page.reDate.exec(str);
			return (aDt===null) ? str : Page.getMonthName(aDt[2]-1) + ' ' + parseInt(aDt[3]) + ', ' + aDt[1];
		},
		getMonthName: function(idx) {
			return [
				'January','February','March','April','May','June','July',
				'August','September','October','November','December'
			][idx];
		}
    };
	// Handles the selection of a date in the calendar popup, inserting the date into a text box
    function handleSelect(type,args,obj) {
        var dates=args[0];
        var date=dates[0];
        var yy=date[0];
        var mm=(date[1]>9)?date[1]:'0'+''+date[1];
        var dd=(date[2]>9)?date[2]:'0'+''+date[2];
        obj.textField.value=yy+'-'+mm+'-'+dd;
        obj.hide();
    }
	// Handles the selection of the interval menu button, populating the hidden field with data to be read
	// by updateChart
    function updateIntervalInput(type,args,obj) {
        Page.btnSelectInterval.set('label',obj.cfg.getProperty('text'));
        Dom.get('txtInterval').value=obj.value;
    }
	// Create the page layout frames
    Event.onDOMReady(function() {
        Page.layout = new YAHOO.widget.Layout({
            minWidth: 1000,
            units: [
                { position: 'top', header: 'Reporting', height: 50, body: 'top1', gutter: '5px' },
                { position: 'left', width: 200, body: 'left1', gutter: '2px 5px' },
                { position: 'center', body: 'center1', gutter: '2px 5px 2px 0px' }
            ]
        });
        Page.layout.render();
        Dom.setStyle(['left-content','center-content'],'visibility','visible');
    });
	// Create the start date calendar popup and text field
    Event.onContentReady('calStartContainer', function() {
		// Just need to get the event types array
		YAHOO.util.Connect.asyncRequest('POST','report.php', {
			success: Page.EventTypes.handleSuccess,
			failure: Page.EventTypes.handleFailure,
			scope: Page.EventTypes
		}, 'v=types');
		// Create an input for the start date
        Page.calStart = new YAHOO.widget.Calendar("calStart","calStartContainer",{title:"Select start date",close:true});
        Page.calStart.selectEvent.subscribe(handleSelect,Page.calStart,true);
        Page.calStart.render();
        Page.calStart.textField = Dom.get('txtStartDate');
        Event.addListener("txtStartDate","focus",Page.calStart.show,Page.calStart,true);
    });
	// Create the start date calendar popup and text field
    Event.onContentReady('calEndContainer', function() {
		// Create an input for the end date
        Page.calEnd = new YAHOO.widget.Calendar("calEnd","calEndContainer",{title:"Select end date",close:true});
        Page.calEnd.selectEvent.subscribe(handleSelect,Page.calEnd,true);
        Page.calEnd.render();
        Page.calEnd.textField = Dom.get('txtEndDate');
        Event.addListener("txtEndDate","focus",Page.calEnd.show,Page.calEnd,true);
    });
	// Draw the get report button
    Event.onContentReady('btnGetReportContainer', function() {
        Page.getReportButton = new YAHOO.widget.Button({
            id: 'btnGetReport',
            type: 'button',
            label: 'Get Report',
            container: 'btnGetReportContainer',
            onclick: { fn: Page.StatData.updateChart }
        });
    });
	// create the senter content by calling updateChart
    Event.onContentReady('center-content', function() {
        Page.StatData.updateChart();
    });
	// Buttons control which data is shown in the chart. By selecting a button an event triggers the updating
	// of the EventTypes.loadData and then calling updateChart
    Event.onContentReady('eventSelectContainer', function() {
		Page.btnEventLoad = new YAHOO.widget.Button({
			type: "checkbox",
			label: "Page Load",
			id: "btnEventLoad",
			name: "btnEventLoad",
			value: "load",
			container: "eventSelectContainer",
			checked: true
		});
		Page.btnEventLoad.subscribe('checkedChange', function(args) {
			Page.EventTypes.loadEvents['load'] = args.newValue;
			Page.StatData.updateChart();
		});
        Page.btnEventRSI = new YAHOO.widget.Button({
			type: "checkbox",
			label: "RSI Load",
			id: "btnEventRSI",
			name: "btnEventRSI",
			value: "rsiDone",
			container: "eventSelectContainer"
		});
		Page.btnEventRSI.subscribe('checkedChange', function(args) {
			Page.EventTypes.loadEvents['rsiDone'] = args.newValue;
			Page.StatData.updateChart();
		});
        Page.btnEventVE = new YAHOO.widget.Button({
			type: "checkbox",
			label: "VE Load",
			id: "btnEventVE",
			name: "btnEventVE",
			value: "veDone",
			container: "eventSelectContainer"
		});
		Page.btnEventVE.subscribe('checkedChange', function(args) {
			Page.EventTypes.loadEvents['veDone'] = args.newValue;
			Page.StatData.updateChart();
		});
    });
	// This container does not do anything yet, eventually this will allow the grouping of data over preset
	// periods of time.
    Event.onContentReady('intervalsContainer',function() {
        Page.btnSelectInterval = new YAHOO.widget.Button({
            id: 'btnSelectInterval',
            type: "split",
            label: "1 Hour",
            name: "btnSelectInterval",
            container: "intervalsContainer",
            selectedMenuItem: 1,
            menu: [
                { text: "1 Hour", value: '1h', onclick: { fn: updateIntervalInput } },
                { text: "2 Hour", value: '2h', onclick: { fn: updateIntervalInput } },
                { text: "4 Hour", value: '4h', onclick: { fn: updateIntervalInput } },
                { text: "8 Hour", value: '8h', onclick: { fn: updateIntervalInput } },
                { text: "1 Day",  value: '1d', onclick: { fn: updateIntervalInput } }
            ]
        });
    });
})();
