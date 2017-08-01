## Restoring GHTorrent backups

The GHTorrent MySQL comes in CSV files, one per database table. This is
to avoid expensive FK checks and index creation that comes by default
in the MySQL dump process. To restore the database as a whole,
do the following:

**WARNING**: The following process will delete an existing database if you
use the same database name (or if you use the default database name).

### Download the MySQL dump

You can find all downloads at the [GHTorrent downloads page](http://ghtorrent.org/downloads.html). 
To download a dump, replace `mysql-yyyy-mm-dd` in the code snippets below
with one of the available downloads on that page.

```bash
wget http://ghtorrent.org/downloads/mysql-yyyy-mm-dd.tar.gz
tar zxvf mysql-yyyy-mm-dd.tar.gz
```

If you have a reliable internet connection you can avoid the overhead of
storing the compressed file.

```bash
curl http://ghtorrent.org/downloads/mysql-yyyy-mm-dd.tar.gz |
tar zxvf -
```

### Create a MySQL user
Create a MySQL user with permissions to create new schemata, for example:

```sql
create user ghtorrentuser@'localhost' identified by 'ghtorrentpassword';
create user ghtorrentuser@'*' identified by 'ghtorrentpassword';
create database ghtorrent_restore;
grant all privileges on ghtorrent_restore.* to 'ghtorrentuser'@'localhost';
grant all privileges on ghtorrent_restore.* to 'ghtorrentuser'@'*';
grant file on *.* to 'ghtorrentuser'@'localhost';
```
### Run the restore process

The run the `ght-restore-mysql` script like this (replace the `ghtorrentuser`
and `ghtorrentpassword` with the actual values you specified above):

```bash
cd  mysql-yyyy-mm-dd
./ght-restore-mysql -u ghtorrentuser -d ghtorrent_restore -p ghtorrentpassword .
```

### Restoring individual tables
If you want to restore CSV files individually, you first need to create
the schema using the 'schema.sql' file. Then, login to the MySQL command
promtp and do the following (the example will just load the `users` table):

```sql
mysql> SET foreign_key_checks = 0;
mysql> LOAD DATA INFILE '/full/path/to/users.csv' INTO TABLE users FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"' LINES TERMINATED BY '\n'
```

The `ORDER` file defines the order the CSV files should be imported, if you want
to avoid FK missing conflicts.

You can then create the corresponding indexes from the `indexes.sql` file.

### Restoring user private data

As of May 2016, the distributed data dump for the `users` table does not contain
privacy-sensitive information (specifically, real names and emails). Those
can be obtained seperately using [this page](http://ghtorrent.org/pers-data.html).

To restore the user private data in the `users` table, run the following
commands:

```bash
gunzip users-private-yyyy-mm-dd.gz
wget https://raw.githubusercontent.com/gousiosg/github-mirror/master/sql/ght-add-private
chmod +x ght-add-private
./ght-add-private -u ghtorrentuser -d ghtorrent_restore -p ghtorrentpassword .
```
