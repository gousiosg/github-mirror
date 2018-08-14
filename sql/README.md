## Restoring GHTorrent backups

The GHTorrent PostgreSQL comes in compressed CSV files, one per database table. This is
to avoid expensive FK checks and index creation. To restore the database as a whole,
do the following:

**WARNING**: The following process will delete tables of an existing database if you
use the same database name (or if you use the default database name).

### Download the PostgreSQL dump

You can find all downloads at the [GHTorrent downloads page](http://ghtorrent.org/downloads.html). 
To download a dump, replace `pg-yyyy-mm-dd` in the code snippets below
with one of the available downloads on that page.

```bash
wget http://ghtorrent.org/downloads/pg-yyyy-mm-dd.tar.gz
tar zxvf pg-yyyy-mm-dd.tar.gz
```

If you have a reliable internet connection you can avoid the overhead of
storing the compressed file.

```bash
curl http://ghtorrent.org/downloads/pg-yyyy-mm-dd.tar.gz |
tar zxvf -
```

### Create a PostgreSQL user
Create a PostgreSQL user with permissions to create new schemata, for example:

```sql
CREATE DATABASE ghtorrent_restore;
CREATE USER ghtorrentuser WITH PASSWORD 'ghtorrentpassword';
GRANT ALL PRIVILEGES ON DATABASE "ghtorrent_restore" to ghtorrentuser;
```
### Run the restore process

The run the `ght-restore-pg` script like this (replace the `ghtorrentuser`
and `ghtorrentpassword` with the actual values you specified above):

```bash
cd  pg-yyyy-mm-dd
./ght-restore-pg -u ghtorrentuser -d ghtorrent_restore -p ghtorrentpassword .
```

### Restoring individual tables
If you want to restore CSV files individually, you first need to create
the schema using the 'schema.sql' file. Then, login to the PostgreSQL command
promtp and do the following (the example will just load the `users` table):

```sql
ghtorrent_restore=# COPY users FROM PROGRAM 'zcat < /full/path/to/users.csv.gz';
```

The `ORDER` file defines the order the CSV files should be imported, if you want
to avoid FK missing conflicts.

You can then create the corresponding indexes and foreign keys from the `indexes_and_foreign_keys` file.

### Restoring user private data

As of May 2016, the distributed data dump for the `users` table does not contain
privacy-sensitive information (specifically, real names and emails). Those
can be obtained seperately using [this page](http://ghtorrent.org/pers-data.html).

To restore the user private data in the `users` table, run the following
commands:

```bash
mv users-private-yyyy-mm-dd.csv.gz users_private.csv.gz
wget https://raw.githubusercontent.com/gousiosg/github-mirror/master/sql/ght-add-private
wget https://raw.githubusercontent.com/gousiosg/github-mirror/master/sql/users_private.sql
chmod +x ght-add-private
./ght-add-private -u ghtorrentuser -d ghtorrent_restore -p ghtorrentpassword .
```
