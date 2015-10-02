## Restoring GHTorrent backups

The GHTorrent MySQL comes in CSV files, one per database table. This is
to avoid expensive FK checks and index creation that comes by default
in the MySQL dump process. To restore the database as a whole,
do the following:

**WARNING**: The following process will delete an existing database if you
use the same database name (or if you use the default database name).

### Download the MySQL dump

```bash
wget http://ghtorrent.org/downloads/mysql.latest.tar.gz
tar zxvf mysql.latest.tar.gz
```

### Create a MySQL user
Create a MySQL user with permissions to create new schemata, for example:

```sql
create user ghtorrentuser@'localhost' identified by 'ghtorrentpassword';
create user ghtorrentuser@'*' identified by 'ghtorrentpassword';
create database ghtorrent_restore;
grant all privileges on ghtorrent_restore.* to 'ghtorrentuser'@'localhost';
grant all privileges on ghtorrent_restore.* to 'ghtorrentuser'@'*';
```
### Run the restore process

The run the `ght-restore-mysql` script like this (replace the `ghtorrentuser`
and `ghtorrentpassword` with the actual values you specified above):

```bash
cd dump
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
