\timing
ALTER TABLE ONLY commit_comments ADD CONSTRAINT commit_comments_pkey PRIMARY KEY (id);
ALTER TABLE ONLY commit_parents ADD CONSTRAINT commit_parents_pkey PRIMARY KEY (commit_id, parent_id);
ALTER TABLE ONLY commits ADD CONSTRAINT commits_pkey PRIMARY KEY (id);
ALTER TABLE ONLY followers ADD CONSTRAINT followers_pkey PRIMARY KEY (user_id, follower_id);
ALTER TABLE ONLY issue_labels ADD CONSTRAINT issue_labels_pkey PRIMARY KEY (issue_id, label_id);
ALTER TABLE ONLY issues ADD CONSTRAINT issues_pkey PRIMARY KEY (id);
ALTER TABLE ONLY organization_members ADD CONSTRAINT organization_members_pkey PRIMARY KEY (org_id, user_id);
ALTER TABLE ONLY project_members ADD CONSTRAINT project_members_pkey PRIMARY KEY (repo_id, user_id);
ALTER TABLE ONLY project_topics ADD CONSTRAINT project_topics_pkey PRIMARY KEY (project_id, topic_name);
ALTER TABLE ONLY projects ADD CONSTRAINT projects_pkey PRIMARY KEY (id);
ALTER TABLE ONLY pull_request_commits ADD CONSTRAINT pull_request_commits_pkey PRIMARY KEY (pull_request_id, commit_id);
ALTER TABLE ONLY pull_request_history ADD CONSTRAINT pull_request_history_pkey PRIMARY KEY (id);
ALTER TABLE ONLY pull_requests ADD CONSTRAINT pull_requests_pkey PRIMARY KEY (id);
ALTER TABLE ONLY repo_labels ADD CONSTRAINT repo_labels_pkey PRIMARY KEY (id);
ALTER TABLE ONLY repo_milestones ADD CONSTRAINT repo_milestones_pkey PRIMARY KEY (id);
ALTER TABLE ONLY users ADD CONSTRAINT users_pkey PRIMARY KEY (id);
ALTER TABLE ONLY watchers ADD CONSTRAINT watchers_pkey PRIMARY KEY (repo_id, user_id);
\timing
