Migrate the GHTorrent Database from MySQL to PostgreSQL
=======

Requirements:
-------------
1. PostgreSQL database.
2. Install [pgloader](https://github.com/dimitri/pgloader). Build it from sources instead of installing directly
    * Example: Building from sources on debian
      ```
      $ git clone https://github.com/dimitri/pgloader.git
      $ apt-get install sbcl unzip libsqlite3-dev make curl gawk freetds-dev libzip-dev
      $ cd /path/to/pgloader
      $ make DYNSIZE=8192 pgloader #(don't assign DYNSIZE more than your current RAM)
      ```

Create a PostgreSQL user:
-------------------
```
CREATE DATABASE dbname;
CREATE USER username WITH PASSWORD 'password';
ALTER USER username with SUPERUSER;
```

Database Migration Steps:
------------------------
1. Execute 'update_incorrect_datetime_value.sql' to update created_at of commits and issues tables in MySQL database where it's 0000-00-00 00:00:00. 
    ```
    $ mysql -h hostname -u user database < path/to/update_incorrect_datetime_value.sql
    ```
    Take the csv dump of commits, project_commits and issues tables from MySQL database. We will directly migrate the data for the other tables from MySQL database to PostgreSQL database.
    ```
    path/to/csv_data_dump -u ghtorrentuser -d ghtorrent_database -o '/path/to/output_dir'
    ```
2. Load the schema from the MySQL database to PostgreSQL database. This will not include creation of primary keys, indexes and foreign keys.
    ```
    pgloader$ PG_DB_URI=pgsql://user:password@host:port/database MYSQL_DB_URI=mysql://user:password@host/database SCHEMA_NAME=mysql_schema_name ./build/bin/pgloader --debug /path/to/schema.load
    ```
3. Migrate the data directly from MySQL database to PostgreSQL database. This will exclude commits, project_commits and issues. 
    ```
    pgloader$ PG_DB_URI=pgsql://user:password@host:port/database MYSQL_DB_URI=mysql://user:password@host/database SCHEMA_NAME=mysql_schema_name ./build/bin/pgloader --debug /path/to/data.load
    ```
4. Copy the data for tables commits, project_commits and issues directly from CSV files as these tables contains only integer fields and does not need any data transformation to make it compatible for PostgreSQL database. These tables are of bigger size and using pgloader will take more time.
    ```
    $ psql -U user -h host -d database -a -v data_directory='/path/to/csv_files_directory' -f /path/to/csv_data_copy.sql
    ```
5. Create primary keys, indexes and foreign keys from the primary_keys.sql, indexes.sql and foreign_keys.sql file.
    ```
    $ psql -U user -h host -d database -a -f /path/to/primary_keys.sql
    $ psql -U user -h host -d database -a -f /path/to/indexes.sql
    $ psql -U user -h host -d database -a -f /path/to/foreign_keys.sql
    ```
