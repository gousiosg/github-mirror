--
-- PostgreSQL database dump
--

-- Dumped from database version 9.6.9
-- Dumped by pg_dump version 9.6.9

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: commit_comments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE commit_comments (
    id bigint NOT NULL,
    commit_id integer NOT NULL,
    user_id integer NOT NULL,
    body character varying(256),
    line integer,
    "position" integer,
    comment_id integer NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: commit_comments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE commit_comments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: commit_comments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE commit_comments_id_seq OWNED BY commit_comments.id;


--
-- Name: commit_parents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE commit_parents (
    commit_id integer NOT NULL,
    parent_id integer NOT NULL
);


--
-- Name: commits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE commits (
    id bigint NOT NULL,
    sha character varying(40),
    author_id integer,
    committer_id integer,
    project_id integer,
    created_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: commits_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE commits_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: commits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE commits_id_seq OWNED BY commits.id;


--
-- Name: followers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE followers (
    follower_id integer NOT NULL,
    user_id integer NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: issue_comments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE issue_comments (
    issue_id integer NOT NULL,
    user_id integer NOT NULL,
    comment_id text NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: issue_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE issue_events (
    event_id text NOT NULL,
    issue_id integer NOT NULL,
    actor_id integer NOT NULL,
    action character varying(255) NOT NULL,
    action_specific character varying(50),
    created_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: issue_labels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE issue_labels (
    label_id integer NOT NULL,
    issue_id integer NOT NULL
);


--
-- Name: issues; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE issues (
    id bigint NOT NULL,
    repo_id integer,
    reporter_id integer,
    assignee_id integer,
    pull_request boolean NOT NULL,
    pull_request_id integer,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    issue_id integer NOT NULL
);


--
-- Name: issues_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE issues_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: issues_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE issues_id_seq OWNED BY issues.id;


--
-- Name: organization_members; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE organization_members (
    org_id integer NOT NULL,
    user_id integer NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: project_commits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE project_commits (
    project_id integer DEFAULT 0 NOT NULL,
    commit_id integer DEFAULT 0 NOT NULL
);


--
-- Name: project_languages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE project_languages (
    project_id integer NOT NULL,
    language character varying(255),
    bytes integer,
    created_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: project_members; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE project_members (
    repo_id integer NOT NULL,
    user_id integer NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    ext_ref_id character varying(24) DEFAULT '0'::character varying NOT NULL
);


--
-- Name: project_topics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE project_topics (
    project_id integer NOT NULL,
    topic_name character varying(255) NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    deleted boolean DEFAULT false NOT NULL
);


--
-- Name: projects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE projects (
    id bigint NOT NULL,
    url character varying(255),
    owner_id integer,
    name character varying(255) NOT NULL,
    description character varying(255),
    language character varying(255),
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    forked_from integer,
    deleted boolean DEFAULT false NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    forked_commit_id integer
);


--
-- Name: projects_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE projects_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: projects_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE projects_id_seq OWNED BY projects.id;


--
-- Name: pull_request_comments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE pull_request_comments (
    pull_request_id integer NOT NULL,
    user_id integer NOT NULL,
    comment_id text NOT NULL,
    "position" integer,
    body character varying(256),
    commit_id integer NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: pull_request_commits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE pull_request_commits (
    pull_request_id integer NOT NULL,
    commit_id integer NOT NULL
);


--
-- Name: pull_request_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE pull_request_history (
    id bigint NOT NULL,
    pull_request_id integer NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    action character varying(255) NOT NULL,
    actor_id integer
);


--
-- Name: pull_request_history_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE pull_request_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pull_request_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE pull_request_history_id_seq OWNED BY pull_request_history.id;


--
-- Name: pull_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE pull_requests (
    id bigint NOT NULL,
    head_repo_id integer,
    base_repo_id integer NOT NULL,
    head_commit_id integer,
    base_commit_id integer NOT NULL,
    pullreq_id integer NOT NULL,
    intra_branch boolean NOT NULL
);


--
-- Name: pull_requests_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE pull_requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pull_requests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE pull_requests_id_seq OWNED BY pull_requests.id;


--
-- Name: repo_labels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE repo_labels (
    id bigint NOT NULL,
    repo_id integer,
    name character varying(24) NOT NULL
);


--
-- Name: repo_labels_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE repo_labels_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: repo_labels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE repo_labels_id_seq OWNED BY repo_labels.id;


--
-- Name: repo_milestones; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE repo_milestones (
    id bigint NOT NULL,
    repo_id integer,
    name character varying(24) NOT NULL
);


--
-- Name: repo_milestones_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE repo_milestones_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: repo_milestones_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE repo_milestones_id_seq OWNED BY repo_milestones.id;


--
-- Name: schema_info; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE schema_info (
    version integer DEFAULT 0 NOT NULL
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE users (
    id bigint NOT NULL,
    login character varying(255) NOT NULL,
    name character varying(255),
    company character varying(255),
    email character varying(255),
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    type character varying(255) DEFAULT 'USR'::character varying NOT NULL,
    fake boolean DEFAULT false NOT NULL,
    deleted boolean DEFAULT false NOT NULL,
    long numeric(11,8),
    lat numeric(10,8),
    country_code character(3),
    state character varying(255),
    city character varying(255),
    location character varying(255)
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE users_id_seq OWNED BY users.id;


--
-- Name: watchers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE watchers (
    repo_id integer NOT NULL,
    user_id integer NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: commit_comments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY commit_comments ALTER COLUMN id SET DEFAULT nextval('commit_comments_id_seq'::regclass);


--
-- Name: commits id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY commits ALTER COLUMN id SET DEFAULT nextval('commits_id_seq'::regclass);


--
-- Name: issues id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY issues ALTER COLUMN id SET DEFAULT nextval('issues_id_seq'::regclass);


--
-- Name: projects id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY projects ALTER COLUMN id SET DEFAULT nextval('projects_id_seq'::regclass);


--
-- Name: pull_request_history id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY pull_request_history ALTER COLUMN id SET DEFAULT nextval('pull_request_history_id_seq'::regclass);


--
-- Name: pull_requests id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY pull_requests ALTER COLUMN id SET DEFAULT nextval('pull_requests_id_seq'::regclass);


--
-- Name: repo_labels id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY repo_labels ALTER COLUMN id SET DEFAULT nextval('repo_labels_id_seq'::regclass);


--
-- Name: repo_milestones id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY repo_milestones ALTER COLUMN id SET DEFAULT nextval('repo_milestones_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY users ALTER COLUMN id SET DEFAULT nextval('users_id_seq'::regclass);

--
-- PostgreSQL database dump complete
--
