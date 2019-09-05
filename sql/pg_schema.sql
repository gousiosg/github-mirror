SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;

DROP SEQUENCE IF EXISTS commit_comments_id_seq CASCADE;
CREATE SEQUENCE commit_comments_id_seq INCREMENT BY 1
                                  NO MAXVALUE NO MINVALUE CACHE 1;
SELECT pg_catalog.setval('commit_comments_id_seq', 1, true);

-- Table: commit_comments
DROP TABLE IF EXISTS "commit_comments" CASCADE;
CREATE TABLE "commit_comments" (
  "id" integer DEFAULT nextval('commit_comments_id_seq'::regclass) NOT NULL,
  "commit_id" integer NOT NULL,
  "user_id" integer NOT NULL,
  "body" text,
  "line" integer,
  "position" integer,
  "comment_id" integer NOT NULL,
  "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
)
WITHOUT OIDS;

-- Table: commit_parents
DROP TABLE IF EXISTS "commit_parents" CASCADE;
CREATE TABLE "commit_parents" (
  "commit_id" integer NOT NULL,
  "parent_id" integer NOT NULL
)
WITHOUT OIDS;

DROP SEQUENCE IF EXISTS commits_id_seq CASCADE;
CREATE SEQUENCE commits_id_seq INCREMENT BY 1
                                  NO MAXVALUE NO MINVALUE CACHE 1;
SELECT pg_catalog.setval('commits_id_seq', 1, true);

-- Table: commits
DROP TABLE IF EXISTS "commits" CASCADE;
CREATE TABLE "commits" (
  "id" integer DEFAULT nextval('commits_id_seq'::regclass) NOT NULL,
  "sha" character varying(40),
  "author_id" integer,
  "committer_id" integer,
  "project_id" integer,
  "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
)
WITHOUT OIDS;

-- Table: followers
DROP TABLE IF EXISTS "followers" CASCADE;
CREATE TABLE "followers" (
  "follower_id" integer NOT NULL,
  "user_id" integer NOT NULL,
  "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
)
WITHOUT OIDS;

-- Table: issue_comments
DROP TABLE IF EXISTS "issue_comments" CASCADE;
CREATE TABLE "issue_comments" (
  "issue_id" integer NOT NULL,
  "user_id" integer NOT NULL,
  "comment_id" text NOT NULL,
  "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
)
WITHOUT OIDS;

-- Table: issue_events
DROP TABLE IF EXISTS "issue_events" CASCADE;
CREATE TABLE "issue_events" (
  "event_id" text NOT NULL,
  "issue_id" integer NOT NULL,
  "actor_id" integer NOT NULL,
  "action" character varying(255) NOT NULL,
  "action_specific" character varying(50),
  "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
)
WITHOUT OIDS;

-- Table: issue_labels
DROP TABLE IF EXISTS "issue_labels" CASCADE;
CREATE TABLE "issue_labels" (
  "label_id" integer NOT NULL,
  "issue_id" integer NOT NULL
)
WITHOUT OIDS;

DROP SEQUENCE IF EXISTS issues_id_seq CASCADE;
CREATE SEQUENCE issues_id_seq INCREMENT BY 1
                                  NO MAXVALUE NO MINVALUE CACHE 1;
SELECT pg_catalog.setval('issues_id_seq', 1, true);

-- Table: issues
DROP TABLE IF EXISTS "issues" CASCADE;
CREATE TABLE "issues" (
  "id" integer DEFAULT nextval('issues_id_seq'::regclass) NOT NULL,
  "repo_id" integer,
  "reporter_id" integer,
  "assignee_id" integer,
  "pull_request" boolean NOT NULL,
  "pull_request_id" integer,
  "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
  "issue_id" integer NOT NULL
)
WITHOUT OIDS;

-- Table: organization_members
DROP TABLE IF EXISTS "organization_members" CASCADE;
CREATE TABLE "organization_members" (
  "org_id" integer NOT NULL,
  "user_id" integer NOT NULL,
  "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
)
WITHOUT OIDS;

-- Table: project_commits
DROP TABLE IF EXISTS "project_commits" CASCADE;
CREATE TABLE "project_commits" (
  "project_id" integer DEFAULT 0 NOT NULL,
  "commit_id" integer DEFAULT 0 NOT NULL
)
WITHOUT OIDS;

-- Table: project_languages
DROP TABLE IF EXISTS "project_languages" CASCADE;
CREATE TABLE "project_languages" (
  "project_id" integer NOT NULL,
  "language" character varying(255),
  "bytes" integer,
  "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
)
WITHOUT OIDS;

-- Table: project_members
DROP TABLE IF EXISTS "project_members" CASCADE;
CREATE TABLE "project_members" (
  "repo_id" integer NOT NULL,
  "user_id" integer NOT NULL,
  "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
  "ext_ref_id" character varying(24) DEFAULT '0'::character varying NOT NULL
)
WITHOUT OIDS;

-- Table: project_topics
DROP TABLE IF EXISTS "project_topics" CASCADE;
CREATE TABLE "project_topics" (
  "project_id" integer NOT NULL,
  "topic_name" character varying(255) NOT NULL,
  "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
  "deleted" boolean DEFAULT false NOT NULL
)
WITHOUT OIDS;

DROP SEQUENCE IF EXISTS projects_id_seq CASCADE;
CREATE SEQUENCE projects_id_seq INCREMENT BY 1
                                  NO MAXVALUE NO MINVALUE CACHE 1;
SELECT pg_catalog.setval('projects_id_seq', 1, true);

-- Table: projects
DROP TABLE IF EXISTS "projects" CASCADE;
CREATE TABLE "projects" (
  "id" integer DEFAULT nextval('projects_id_seq'::regclass) NOT NULL,
  "url" character varying(255),
  "owner_id" integer,
  "name" character varying(255) NOT NULL,
  "description" text,
  "language" character varying(255),
  "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
  "forked_from" integer,
  "deleted" boolean DEFAULT false NOT NULL,
  "updated_at" timestamp without time zone DEFAULT '1970-01-01 05:30:01' NOT NULL,
  "forked_commit_id" integer
)
WITHOUT OIDS;

-- Table: pull_request_comments
DROP TABLE IF EXISTS "pull_request_comments" CASCADE;
CREATE TABLE "pull_request_comments" (
  "pull_request_id" integer NOT NULL,
  "user_id" integer NOT NULL,
  "comment_id" text NOT NULL,
  "position" integer,
  "body" text,
  "commit_id" integer NOT NULL,
  "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
)
WITHOUT OIDS;

-- Table: pull_request_commits
DROP TABLE IF EXISTS "pull_request_commits" CASCADE;
CREATE TABLE "pull_request_commits" (
  "pull_request_id" integer NOT NULL,
  "commit_id" integer NOT NULL
)
WITHOUT OIDS;

DROP SEQUENCE IF EXISTS pull_request_history_id_seq CASCADE;
CREATE SEQUENCE pull_request_history_id_seq INCREMENT BY 1
                                  NO MAXVALUE NO MINVALUE CACHE 1;
SELECT pg_catalog.setval('pull_request_history_id_seq', 1, true);

-- Table: pull_request_history
DROP TABLE IF EXISTS "pull_request_history" CASCADE;
CREATE TABLE "pull_request_history" (
  "id" integer DEFAULT nextval('pull_request_history_id_seq'::regclass) NOT NULL,
  "pull_request_id" integer NOT NULL,
  "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
  "action" character varying(255) NOT NULL,
  "actor_id" integer
)
WITHOUT OIDS;

DROP SEQUENCE IF EXISTS pull_requests_id_seq CASCADE;
CREATE SEQUENCE pull_requests_id_seq INCREMENT BY 1
                                  NO MAXVALUE NO MINVALUE CACHE 1;
SELECT pg_catalog.setval('pull_requests_id_seq', 1, true);

-- Table: pull_requests
DROP TABLE IF EXISTS "pull_requests" CASCADE;
CREATE TABLE "pull_requests" (
  "id" integer DEFAULT nextval('pull_requests_id_seq'::regclass) NOT NULL,
  "head_repo_id" integer,
  "base_repo_id" integer NOT NULL,
  "head_commit_id" integer,
  "base_commit_id" integer NOT NULL,
  "pullreq_id" integer NOT NULL,
  "intra_branch" boolean NOT NULL
)
WITHOUT OIDS;

DROP SEQUENCE IF EXISTS repo_labels_id_seq CASCADE;
CREATE SEQUENCE repo_labels_id_seq INCREMENT BY 1
                                  NO MAXVALUE NO MINVALUE CACHE 1;
SELECT pg_catalog.setval('repo_labels_id_seq', 1, true);

-- Table: repo_labels
DROP TABLE IF EXISTS "repo_labels" CASCADE;
CREATE TABLE "repo_labels" (
  "id" integer DEFAULT nextval('repo_labels_id_seq'::regclass) NOT NULL,
  "repo_id" integer,
  "name" character varying(26) NOT NULL
)
WITHOUT OIDS;

DROP SEQUENCE IF EXISTS repo_milestones_id_seq CASCADE;
CREATE SEQUENCE repo_milestones_id_seq INCREMENT BY 1
                                  NO MAXVALUE NO MINVALUE CACHE 1;
SELECT pg_catalog.setval('repo_milestones_id_seq', 1, true);

-- Table: repo_milestones
DROP TABLE IF EXISTS "repo_milestones" CASCADE;
CREATE TABLE "repo_milestones" (
  "id" integer DEFAULT nextval('repo_milestones_id_seq'::regclass) NOT NULL,
  "repo_id" integer,
  "name" character varying(24) NOT NULL
)
WITHOUT OIDS;

-- Table: schema_info
DROP TABLE IF EXISTS "schema_info" CASCADE;
CREATE TABLE "schema_info" (
  "version" integer DEFAULT 0 NOT NULL
)
WITHOUT OIDS;

DROP SEQUENCE IF EXISTS users_id_seq CASCADE;
CREATE SEQUENCE users_id_seq INCREMENT BY 1
                                  NO MAXVALUE NO MINVALUE CACHE 1;
SELECT pg_catalog.setval('users_id_seq', 1, true);

-- Table: users
DROP TABLE IF EXISTS "users" CASCADE;
CREATE TABLE "users" (
  "id" integer DEFAULT nextval('users_id_seq'::regclass) NOT NULL,
  "login" character varying(255) NOT NULL,
  "company" character varying(255),
  "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
  "type" character varying(255) DEFAULT 'USR'::character varying NOT NULL,
  "fake" boolean DEFAULT false NOT NULL,
  "deleted" boolean DEFAULT false NOT NULL,
  "long" numeric(11, 8),
  "lat" numeric(10, 8),
  "country_code" character(3),
  "state" character varying(255),
  "city" character varying(255),
  "location" text
)
WITHOUT OIDS;

-- Table: watchers
DROP TABLE IF EXISTS "watchers" CASCADE;
CREATE TABLE "watchers" (
  "repo_id" integer NOT NULL,
  "user_id" integer NOT NULL,
  "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
)
WITHOUT OIDS;
ALTER TABLE "commit_comments" ADD CONSTRAINT "commit_comments_id_pkey" PRIMARY KEY(id);
ALTER TABLE "commits" ADD CONSTRAINT "commits_id_pkey" PRIMARY KEY(id);
ALTER TABLE "followers" ADD CONSTRAINT "followers_follower_id_user_id_pkey" PRIMARY KEY(follower_id, user_id);
ALTER TABLE "issue_labels" ADD CONSTRAINT "issue_labels_issue_id_label_id_pkey" PRIMARY KEY(issue_id, label_id);
ALTER TABLE "issues" ADD CONSTRAINT "issues_id_pkey" PRIMARY KEY(id);
ALTER TABLE "organization_members" ADD CONSTRAINT "organization_members_org_id_user_id_pkey" PRIMARY KEY(org_id, user_id);
ALTER TABLE "project_members" ADD CONSTRAINT "project_members_repo_id_user_id_pkey" PRIMARY KEY(repo_id, user_id);
ALTER TABLE "project_topics" ADD CONSTRAINT "project_topics_project_id_topic_name_pkey" PRIMARY KEY(project_id, topic_name);
ALTER TABLE "projects" ADD CONSTRAINT "projects_id_pkey" PRIMARY KEY(id);
ALTER TABLE "pull_request_commits" ADD CONSTRAINT "pull_request_commits_pull_request_id_commit_id_pkey" PRIMARY KEY(pull_request_id, commit_id);
ALTER TABLE "pull_request_history" ADD CONSTRAINT "pull_request_history_id_pkey" PRIMARY KEY(id);
ALTER TABLE "pull_requests" ADD CONSTRAINT "pull_requests_id_pkey" PRIMARY KEY(id);
ALTER TABLE "repo_labels" ADD CONSTRAINT "repo_labels_id_pkey" PRIMARY KEY(id);
ALTER TABLE "repo_milestones" ADD CONSTRAINT "repo_milestones_id_pkey" PRIMARY KEY(id);
ALTER TABLE "users" ADD CONSTRAINT "users_id_pkey" PRIMARY KEY(id);
ALTER TABLE "watchers" ADD CONSTRAINT "watchers_repo_id_user_id_pkey" PRIMARY KEY(repo_id, user_id);
