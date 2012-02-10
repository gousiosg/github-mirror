github-mirror: Mirror and process the Github event steam
=========================================================

A collection of scripts used to mirror the Github event stream, for 
research purposes.

The scripts rely on the following software to work:

* MongoDB > 2.0
* RabbitMQ > 2.0 (actually, any AMQP v0.9 implementation should work)

The scripts are written in Ruby (tested with 1.8). To install the required
library dependencies, do the following:

<code>
sudo gem install amqp mongo
</code>

#### Running 

Copy `config.yaml.tmpl` to `config.yaml`. Edit the MongoDB and AMQP 
configuration options accordingly. The scripts require accounts with permissions
to create queues and exchanges in the AMQP queue and databases and collections in
MongoDB respectively.

To mirror Github's commit stream

* `mirror_events.rb` periodically polls Github's event queue (`https://api.github.com/events`), stores all new events in the `events` collection in MongoDB and
posts them to the `github` exchange in RabbitMQ

* `data_retrieval.rb` creates queues that route posted events to processor
functions, which in turn use the appropriate Github API call to retrieve the
linked contents.

You can run both scripts concurrently on more than one hosts, for resilience
and performance reasons. To catch up with Github's event stream, it is enough
to run `mirror_events.rb` on one host. To collect all data pointed by each
event, one instance of `data_retrieval.rb` is not enough. Both scripts employ
throttling mechanisms to keep API usage whithin the limits imposed by Github
(currently 5000 reqs/hr).

#### Authors

Georgios Gousios <gousiosg@gmail.com>

Diomidis Spinellis

#### License

[2-clause BSD](http://www.opensource.org/licenses/bsd-license.php)

