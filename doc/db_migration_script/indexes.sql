\timing
ALTER TABLE ONLY commit_comments ADD CONSTRAINT commit_comments_comment_id_key UNIQUE (comment_id);
ALTER TABLE ONLY commits ADD CONSTRAINT commits_sha_key UNIQUE (sha);
ALTER TABLE ONLY pull_requests ADD CONSTRAINT pull_requests_pullreq_id_base_repo_id_key UNIQUE (pullreq_id, base_repo_id);
ALTER TABLE ONLY users ADD CONSTRAINT users_login_key UNIQUE (login);

CREATE INDEX index_issue_labels_on_label_id ON issue_labels USING btree (label_id);

CREATE INDEX index_projects_on_name ON projects USING btree (name);
CREATE INDEX index_projects_on_owner_id ON projects USING btree (owner_id);
CREATE INDEX index_projects_on_forked_from ON projects USING btree (forked_from);

CREATE INDEX index_follower_on_user_id ON followers USING btree (user_id);
CREATE INDEX index_followers_on_follower_id ON followers USING btree (follower_id);

CREATE INDEX index_project_commits_on_project_id ON project_commits USING btree (project_id);
CREATE INDEX index_project_commits_on_commit_id ON project_commits USING btree (commit_id);

CREATE INDEX index_project_languages_on_project_id ON project_languages USING btree (project_id);

CREATE INDEX index_pull_request_history_on_pull_request_id ON pull_request_history USING btree (pull_request_id);

CREATE INDEX index_watchers_on_user_id ON watchers USING btree (user_id);
\timing
