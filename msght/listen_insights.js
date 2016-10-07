"use strict"
/*
 * Script listen_insights.js - script that listens to the 'log' queue on a rabbitmq exchange and
 *    and logs all items to appInsights. This was created for events that are created by ght-webhook
 *    because of conflicting required versions of ruby between rabbitmq and application insights
 *
 * Input Parameters:
 *    -c: the path to the config file. If not used, 'config.yaml' is assumed
 *
 * Example use:
 *    node listen_insights.js -c config.yaml
 *
 * NOTE: This should be run on startup of the machine, as it is the logging for webhooks.
 */

var amqp              = require('amqp');
var appInsights       = require('applicationinsights');
var appInsightsClient = appInsights.getClient(process.env.APPINSIGHTS_INSTRUMENTATIONKEY);
var yaml              = require('js-yaml');
var fs                = require('fs');

var configFlag = '-c';
var configFile = 'config.yaml';

//Grab the input parameters
for(var argI = 0; argI < process.argv.length; argI++) {
    switch(process.argv[argI]) {
    case configFlag:
	configFile = process.argv[++argI];
	break;
    }
}

//parse yaml to grab configuration details
var config, amqpConfig;
try {
    config = yaml.safeLoad(fs.readFileSync(configFile, 'utf8'));
    amqpConfig = config['amqp'];
}
catch (e) { console.log(e); }

//Connect to amqp
var connection = amqp.createConnection({ host: amqpConfig['host'],
				         port: amqpConfig['port'],
				         login: amqpConfig['username'],
				         password: amqpConfig['password']});

//Function called when an error is thrown on connection to amqp
connection.on('error', function(err) {
    console.log("Hit conenction error:");
    console.log(err);
});

//Function called when amqp is connected and ready
connection.on('ready', function() {
    connection.queue('LogMessages', function(q) {
	q.bind(amqpConfig['exchange'], "log");
	q.subscribe(receiveEvent);
    });
});

/*
 * Function receiveEvent - function that is called when a message on the queue has been dequeued and is ready to be
 *    logged in appInsights
 */
function receiveEvent(message, headers, deliveryInfo, messageObject) {
    var parts = String(message.data).split(' ');
    appInsightsClient.trackEvent("WEBHOOKS: Received Event", {Type: parts[0], ID: parts[1]});
}
