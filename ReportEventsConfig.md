A JavaScript file holds the event configuration to determine which events are reported, their settings, and layout attributes.

The configuration is in the form of a JSON object with the following three attributes:

  1. lineColor - the color of the lines on the graph
  1. buttonText - the text used on the checkbox button
  1. inSeries - a boolean value indicating that the data should be shown on the initial page load

If the event shows in the configuration it is available to the chart whether or not its inSeries value is true or false

Example config:

```
var Jiffy = {
    Config: {
        Events: {
            load: {
                inSeries: true,
                lineColor: 0x0000cc,
                buttonText: 'Page Load'
            },
            rsiDone: {
                inSeries: false,
                lineColor: 0x00cc00,
                buttonText: 'RSI Load'
            },
            veDone: {
                inSeries: false,
                lineColor: 0xcc0000,
                buttonText: 'VE Load'
            }
        }
    }
};
```