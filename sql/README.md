# Restoring GHTorrent backups

The GHTorrent database dump comes in CSV files, one per database table. This is
to avoid expensive FK checks and index creation that comes by default
in the MySQL dump process. To restore the database as a whole,
do the following:

**WARNING**: The following process will delete an existing database if you
use the same database name (or if you use the default database name).

### Download the GHTorrent database dump

You can find all downloads at the [GHTorrent downloads page](http://ghtorrent.org/downloads.html). 
To download a dump, replace `ghtorrent-yyyy-mm-dd` in the code snippets below
with one of the available downloads on that page.

```bash
wget http://ghtorrent.org/downloads/ghtorrent-yyyy-mm-dd.tar.gz
tar zxvf ghtorrent-yyyy-mm-dd.tar.gz
```

If you have a reliable internet connection you can avoid the overhead of
storing the compressed file.

```bash
curl http://ghtorrent.org/downloads/ghtorrent-yyyy-mm-dd.tar.gz |
tar zxvf -
```
## Restoring to MySQL database
The GHTorrent database CSV files are compatible with both MySQL and PostgreSQL database. To load the CSV files into PostgreSQL database, go through [Restoring to PostgreSQL database](#restoring-to-postgresql-database).
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
cd  ghtorrent-yyyy-mm-dd
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
mv users-private-yyyy-mm-dd.csv users_private.csv
wget https://raw.githubusercontent.com/gousiosg/github-mirror/master/sql/ght-add-private
chmod +x ght-add-private
./ght-add-private -u ghtorrentuser -d ghtorrent_restore -p ghtorrentpassword .
```

### Protect the database's integrity
To protect the database from accidental modifications,
consider revoking all modification permissions from the user you created.

```sql
revoke all privileges on ghtorrent_restore.* from 'ghtorrentuser'@'localhost';
grant select on ghtorrent_restore.* to 'ghtorrentuser'@'*';
flush privileges;
```

### Configuring MySQL to restore fast

GHTorrent is a very big dataset that could bring even handomely configured servers
down to their knees. The default configuration options for MySQL (at least on
Debian/Ubuntu) are good for normal operation, but are too safe for fast restores.

In general, MyISAM restores are much faster, so if you would only want to
use MySQL for quering, you should probably use MyISAM. In this case, just
disabling the binary log should be fast enough.

```sql
skip-log-bin
```

If you would prefer InnoDB, we have found that the following config options
significantly increase the restoration speed.

```sql
innodb-doublewrite=OFF
innodb-fast-shutdown=0
innodb_flush_method = noflush
innodb_buffer_pool_size = 32GB '''or 80% of the server's RAM
skip-log-bin
```

Remember to set those back to defaults; _the configuration above will lead
to certain data loss in case of an unclear shutdown_.

## <a name="restoring-to-postgresql-database"></a>Restoring to PostgreSQL database
### Create a PostgreSQL user
Create a PostgreSQL user with permissions to create new schemata, for example:

```sql
CREATE DATABASE ghtorrent_restore;
CREATE USER ghtorrentuser WITH PASSWORD 'ghtorrentpassword';
GRANT ALL PRIVILEGES ON DATABASE "ghtorrent_restore" to ghtorrentuser;
ALTER USER ghtorrentuser WITH SUPERUSER;
```
### Run the restore process

The run the `ght-restore-pg` script like this (replace the `ghtorrentuser`
and `ghtorrentpassword` with the actual values you specified above):

```bash
cd  ghtorrent-yyyy-mm-dd
./ght-restore-pg -u ghtorrentuser -d ghtorrent_restore -p ghtorrentpassword .
```

### Restoring individual tables
If you want to restore CSV files individually, you first need to create
the schema using the 'schema.sql' file. Then, login to the PostgreSQL command
promtp and do the following (the example will just load the `users` table):

```sql
ghtorrent_restore=# COPY users FROM '/full/path/to/users.csv';
```

The `ORDER` file defines the order the CSV files should be imported, if you want
to avoid FK missing conflicts.

You can then create the corresponding indexes and foreign keys from the `pg_indexes_and_foreign_keys` file and reset the sequences from the `pg_reset_sequences` file.

### Restoring user private data

As of May 2016, the distributed data dump for the `users` table does not contain
privacy-sensitive information (specifically, real names and emails). Those
can be obtained seperately using [this page](http://ghtorrent.org/pers-data.html).

To restore the user private data in the `users` table, run the following
commands:

```bash
mv users-private-yyyy-mm-dd.csv.gz users_private.csv.gz
wget https://raw.githubusercontent.com/gousiosg/github-mirror/master/sql/ght-add-private-pg
wget https://raw.githubusercontent.com/gousiosg/github-mirror/master/sql/pg_users_private.sql
chmod +x ght-add-private
./ght-add-private-pg -u ghtorrentuser -d ghtorrent_restore -p ghtorrentpassword .
```
