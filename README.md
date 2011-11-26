github-mirror: Mirror and process the Github commit steam
=========================================================

A collection of scripts used to mirror the Github commit stream, initially
developed to study the dynamics of small commits and project co-ordination.

The scripts rely on the following software to work:

* MongoDB > 2.0
* RabbitMQ > 2.0 (actually, any AMQP v0.9 implementation should work)

The scripts are written in Ruby (tested with 1.8). To install the required
library dependencies, do the following:

<code>
sudo gem install amqp hpricot mongo
</code>


#### Author

Georgios Gousios <gousiosg@gmail.com>

#### License

[2-clause BSD](http://www.opensource.org/licenses/bsd-license.php)

