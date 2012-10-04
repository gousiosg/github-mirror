ghtorrent: Mirror and process the Github event steam
=========================================================

A collection of scripts used to mirror the Github event stream, for 
research purposes. The scripts are distributed as a Gem (`ghtorrent`),
but they can also be run by checking out this repository.

GHTorrent relies on the following software to work:

* MongoDB > 2.0
* RabbitMQ >= 2.7
* An SQL database compatible with [Sequel](http://sequel.rubyforge.org/rdoc/files/doc/opening_databases_rdoc.html). 
GHTorrent is tested mainly with MySQL, so your mileage may vary if you are using other databases.

GHTorrent is written in Ruby (tested with 1.9 and JRuby). To install 
it as a Gem do:

<code>
sudo gem install ghtorrent 
</code>

Depending on which SQL database you want to use, install the appropriate
dependency gem. GHTorrent already installs the `sqlite3` gem (if it fails,
install the development package for `sqlite3` for your system).

<code>
sudo gem install mysql2 #or postgres
</code>

#### Configuring

Copy the contents of the 
[config.yaml.tmpl](https://github.com/gousiosg/github-mirror/blob/master/config.yaml.tmpl)
file to a file in your home directory. All provided scripts accept the `-c`
option, which you can use to pass the location of the configuration file as
a parameter.

Edit the MongoDB and AMQP configuration options accordingly. The scripts
require accounts with permissions to create queues and exchanges in the AMQP
queue, collections in MongoDB and tables in the selected SQL database,
respectively.

To prepare MongoDB:

<pre>
$ mongo admin
> db.addUser('github', 'github')
> use github
> db.addUser('github', 'github')
</pre>

To prepare RabbitMQ:

<pre>
$ rabbitmqctl add_user github
$ rabbitmqctl set_permissions -p / github ".*" ".*" ".*"

# The following will enable the RabbitMQ web admin for the github user
# Not necessary to have, but good to debug and diagnose problems
$ rabbitmq-plugins enable rabbitmq_management
$ rabbitmqctl set_user_tags github administrator
</pre>

To prepare MySQL:

<pre>
$ mysql -u root -p
mysql> create user 'github'@'localhost' identified by 'github';
mysql> create database github;
mysql> GRANT ALL PRIVILEGES ON github.* to github@'localhost';
mysql> flush privileges;
</pre>

You can find more information of how you can setup a cluster of machines
to retrieve data in parallel on the [Wiki](https://github.com/gousiosg/github-mirror/wiki/Setting-up-a-mirroring-cluster).

### Running

To retrieve data with GHTorrent: 

* `ght-mirror-events.rb` periodically polls Github's event
queue (`https://api.github.com/events`), stores all new events in the
`events` collection in MongoDB and posts them to the `github` exchange in
RabbitMQ.

* `ght-data_retrieval.rb` creates queues that route posted events to processor
functions, which in turn use the appropriate Github API call to retrieve the
linked contents, extract metadata to store in the SQL database and store the
retrieved data in the appropriate collection in Mongo, to avoid further API
calls. Data in the SQL database contain pointers (the MongoDB key) to the
"raw" data in MongoDB.

Both scripts can be run concurrently on more than one hosts, for resilience
and performance reasons. To catch up with Github's event stream, it is
usually enough to run `ght-mirror-events` on one host. To collect all data
pointed by each event, one instance of `ght-data-retrieval` is not enough.
Both scripts employ throttling mechanisms to keep API usage whithin the
limits imposed by Github (currently 5000 reqs/hr).

#### Data

You can find torrents for retrieving data on the 
[Available Torrents](https://github.com/gousiosg/github-mirror/wiki/Available-Torrents) page. You need two sets of data:

* Raw events: Github's [event stream](https://api.github.com/events). These
are the roots for mirroring operations. The `ght-data-retrieval` crawler starts
from an event and goes deep into the rabbit hole.
* SQL dumps+Linked data: Data dumps from the SQL database and the corresponding
MongoDB entities.


*At the moment, GHTorrent is in the process of redesigning its data storage
schema. Consequently, it does not distribute SQL dumps or linked data raw data.
The distribution service will come back shortly.*

#### Reporting bugs

Please use the [Issue
Tracker](https://github.com/gousiosg/github-mirror/issues) for reporting bugs
and feature requests.

Patches, bug fixes etc are welcome. Please fork the repository and create
a pull request when done fixing/implementing the new feature.

#### Citation information

If you find GHTorrent and the accompanying datasets useful in your research,
please consider citing the following paper:

> Georgios Gousios and Diomidis Spinellis, "GHTorrent: GitHub’s data from a firehose," in _MSR '12: Proceedings of the 9th Working Conference on Mining Software Repositories_, June 2-–3, 2012. Zurich, Switzerland.

#### Authors

[Georgios Gousios](http://istlab.dmst.aueb.gr/~george) <gousiosg@gmail.com>

[Diomidis Spinellis](http://www.dmst.aueb.gr/dds) <dds@aueb.gr>

#### License

[2-clause BSD](http://www.opensource.org/licenses/bsd-license.php)

