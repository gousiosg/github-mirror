DROP TABLE IF EXISTS users_private;

CREATE TABLE users_private (
  login VARCHAR(255) NOT NULL,
  name VARCHAR(255),
  email VARCHAR(255),
  PRIMARY KEY (login))
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8;

SET foreign_key_checks = 0;
LOAD DATA INFILE 'USERS_PRIVATE_FILE' INTO TABLE users_private
CHARACTER SET UTF8 FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n';

CREATE UNIQUE INDEX login ON users_private (login ASC);

DROP TABLE IF EXISTS users_new;

CREATE TABLE users_new (
  id INT(11) NOT NULL AUTO_INCREMENT,
  login VARCHAR(255) NOT NULL,
  name VARCHAR(255),
  company VARCHAR(255) NULL DEFAULT NULL,
  location VARCHAR(255) NULL DEFAULT NULL,
  email VARCHAR(255),
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  type VARCHAR(255) NOT NULL DEFAULT 'USR',
  fake TINYINT(1) NOT NULL DEFAULT '0',
  deleted TINYINT(1) NOT NULL DEFAULT '0',
  `long` DECIMAL(11,8),
  lat DECIMAL(10,8),
  country_code CHAR(3),
  state VARCHAR(255),
  city VARCHAR(255),
  PRIMARY KEY (id) )
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8;

INSERT INTO users_new (
  SELECT
    users.id as id,
    users.login as login,
    users_private.name as name,
    users.company as company,
    users.location as location,
    users_private.email as email,
    users.created_at as created_at,
    users.type as type,
    users.fake as fake,
    users.deleted as deleted,
    users.`long` as `long`,
    users.lat as lat,
    users.country_code as country_code,
    users.state as state,
    users.city as city
  FROM users LEFT JOIN users_private ON
  users.login = users_private.login
);

CREATE UNIQUE INDEX login ON users_new (login ASC);

RENAME TABLE users TO users_old;

RENAME TABLE users_new TO users;

DROP TABLE users_old;
DROP TABLE users_private;
