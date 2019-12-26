-- Table: users_private
DROP TABLE IF EXISTS users_private;

CREATE TABLE users_private (
  login character varying(255) NOT NULL,
  name text,
  email text
);
ALTER TABLE ONLY users_private ADD CONSTRAINT users_private_pkey PRIMARY KEY (login);

COPY users_private FROM 'USERS_PRIVATE_FILE' WITH (FORMAT 'csv', QUOTE E'"', ESCAPE '\', NULL '\N', ENCODING 'UTF8');

CREATE UNIQUE INDEX users_private_login ON users_private (login ASC);

-- Table: users_new
DROP SEQUENCE IF EXISTS users_new_id_seq CASCADE;
CREATE SEQUENCE users_new_id_seq INCREMENT BY 1
                                  NO MAXVALUE NO MINVALUE CACHE 1;
SELECT pg_catalog.setval('users_new_id_seq', 1, true);

DROP TABLE IF EXISTS users_new;

CREATE TABLE users_new (
  id integer DEFAULT nextval('users_new_id_seq'::regclass) NOT NULL,
  login character varying(255) NOT NULL,
  name character varying(255),
  company character varying(255),
  email character varying(255),
  created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
  type character varying(255) NOT NULL DEFAULT 'USR',
  fake boolean DEFAULT false NOT NULL,
  deleted boolean DEFAULT false NOT NULL,
  long numeric(11, 8),
  lat numeric(10, 8),
  country_code character(3),
  state character varying(255),
  city character varying(255),
  location character varying(255) DEFAULT NULL
);
ALTER TABLE ONLY users_new ADD CONSTRAINT users_new_pkey PRIMARY KEY (id);

INSERT INTO users_new (
  SELECT
    users.id as id,
    users.login as login,
    users_private.name as name,
    users.company as company,
    users_private.email as email,    
    users.created_at as created_at,
    users.type as type,
    users.fake as fake,
    users.deleted as deleted,
    users.long as long,
    users.lat as lat,
    users.country_code as country_code,
    users.state as state,
    users.city as city,
    users.location as location
  FROM users LEFT JOIN users_private ON
  users.login = users_private.login
);

CREATE UNIQUE INDEX users_new_login ON users_new (login ASC);

ALTER TABLE users RENAME TO users_old;
ALTER TABLE users_new RENAME TO users;

ALTER TABLE "commit_comments" DROP CONSTRAINT commit_comments_user_id_fkey;
ALTER TABLE "commit_comments" ADD FOREIGN KEY ("user_id") REFERENCES "users"(id);

ALTER TABLE "commits" DROP CONSTRAINT commits_author_id_fkey;
ALTER TABLE "commits" ADD FOREIGN KEY ("author_id") REFERENCES "users"(id);

ALTER TABLE "commits" DROP CONSTRAINT commits_committer_id_fkey;
ALTER TABLE "commits" ADD FOREIGN KEY ("committer_id") REFERENCES "users"(id);

ALTER TABLE "followers" DROP CONSTRAINT followers_follower_id_fkey;
ALTER TABLE "followers" ADD FOREIGN KEY ("follower_id") REFERENCES "users"(id);

ALTER TABLE "followers" DROP CONSTRAINT followers_user_id_fkey;
ALTER TABLE "followers" ADD FOREIGN KEY ("user_id") REFERENCES "users"(id);

ALTER TABLE "issue_comments" DROP CONSTRAINT issue_comments_user_id_fkey;
ALTER TABLE "issue_comments" ADD FOREIGN KEY ("user_id") REFERENCES "users"(id);

ALTER TABLE "issue_events" DROP CONSTRAINT issue_events_actor_id_fkey;
ALTER TABLE "issue_events" ADD FOREIGN KEY ("actor_id") REFERENCES "users"(id);

ALTER TABLE "issues" DROP CONSTRAINT issues_reporter_id_fkey;
ALTER TABLE "issues" ADD FOREIGN KEY ("reporter_id") REFERENCES "users"(id);

ALTER TABLE "issues" DROP CONSTRAINT issues_assignee_id_fkey;
ALTER TABLE "issues" ADD FOREIGN KEY ("assignee_id") REFERENCES "users"(id);

ALTER TABLE "organization_members" DROP CONSTRAINT organization_members_org_id_fkey;
ALTER TABLE "organization_members" ADD FOREIGN KEY ("org_id") REFERENCES "users"(id);

ALTER TABLE "organization_members" DROP CONSTRAINT organization_members_user_id_fkey;
ALTER TABLE "organization_members" ADD FOREIGN KEY ("user_id") REFERENCES "users"(id);

ALTER TABLE "project_members" DROP CONSTRAINT project_members_user_id_fkey;
ALTER TABLE "project_members" ADD FOREIGN KEY ("user_id") REFERENCES "users"(id);

ALTER TABLE "projects" DROP CONSTRAINT projects_owner_id_fkey;
ALTER TABLE "projects" ADD FOREIGN KEY ("owner_id") REFERENCES "users"(id);

ALTER TABLE "pull_request_comments" DROP CONSTRAINT pull_request_comments_user_id_fkey;
ALTER TABLE "pull_request_comments" ADD FOREIGN KEY ("user_id") REFERENCES "users"(id);

ALTER TABLE "pull_request_history" DROP CONSTRAINT pull_request_history_actor_id_fkey;
ALTER TABLE "pull_request_history" ADD FOREIGN KEY ("actor_id") REFERENCES "users"(id);

ALTER TABLE "watchers" DROP CONSTRAINT watchers_user_id_fkey;
ALTER TABLE "watchers" ADD FOREIGN KEY ("user_id") REFERENCES "users"(id);

DROP TABLE users_old;
DROP TABLE users_private;
