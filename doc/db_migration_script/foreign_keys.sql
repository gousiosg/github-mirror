\timing
ALTER TABLE ONLY commit_comments ADD CONSTRAINT commit_comments_commit_id_fkey FOREIGN KEY (commit_id) REFERENCES commits(id);
ALTER TABLE ONLY commit_comments ADD CONSTRAINT commit_comments_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id);

ALTER TABLE ONLY commit_parents ADD CONSTRAINT commit_parents_commit_id_fkey FOREIGN KEY (commit_id) REFERENCES commits(id);
ALTER TABLE ONLY commit_parents ADD CONSTRAINT commit_parents_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES commits(id);

ALTER TABLE ONLY commits ADD CONSTRAINT commits_author_id_fkey FOREIGN KEY (author_id) REFERENCES users(id);
ALTER TABLE ONLY commits ADD CONSTRAINT commits_committer_id_fkey FOREIGN KEY (committer_id) REFERENCES users(id);
ALTER TABLE ONLY commits ADD CONSTRAINT commits_project_id_fkey FOREIGN KEY (project_id) REFERENCES projects(id);

ALTER TABLE ONLY followers ADD CONSTRAINT followers_follower_id_fkey FOREIGN KEY (follower_id) REFERENCES users(id);
ALTER TABLE ONLY followers ADD CONSTRAINT followers_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id);

ALTER TABLE ONLY issue_comments ADD CONSTRAINT issue_comments_issue_id_fkey FOREIGN KEY (issue_id) REFERENCES issues(id);
ALTER TABLE ONLY issue_comments ADD CONSTRAINT issue_comments_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id);

ALTER TABLE ONLY issue_events ADD CONSTRAINT issue_events_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES users(id);
ALTER TABLE ONLY issue_events ADD CONSTRAINT issue_events_issue_id_fkey FOREIGN KEY (issue_id) REFERENCES issues(id);

ALTER TABLE ONLY issue_labels ADD CONSTRAINT issue_labels_issue_id_fkey FOREIGN KEY (issue_id) REFERENCES issues(id);
ALTER TABLE ONLY issue_labels ADD CONSTRAINT issue_labels_label_id_fkey FOREIGN KEY (label_id) REFERENCES repo_labels(id);

ALTER TABLE ONLY issues ADD CONSTRAINT issues_assignee_id_fkey FOREIGN KEY (assignee_id) REFERENCES users(id);
ALTER TABLE ONLY issues ADD CONSTRAINT issues_pull_request_id_fkey FOREIGN KEY (pull_request_id) REFERENCES pull_requests(id);
ALTER TABLE ONLY issues ADD CONSTRAINT issues_repo_id_fkey FOREIGN KEY (repo_id) REFERENCES projects(id);
ALTER TABLE ONLY issues ADD CONSTRAINT issues_reporter_id_fkey FOREIGN KEY (reporter_id) REFERENCES users(id);

ALTER TABLE ONLY organization_members ADD CONSTRAINT organization_members_org_id_fkey FOREIGN KEY (org_id) REFERENCES users(id);
ALTER TABLE ONLY organization_members ADD CONSTRAINT organization_members_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id);

ALTER TABLE ONLY project_commits ADD CONSTRAINT project_commits_commit_id_fkey FOREIGN KEY (commit_id) REFERENCES commits(id);
ALTER TABLE ONLY project_commits ADD CONSTRAINT project_commits_project_id_fkey FOREIGN KEY (project_id) REFERENCES projects(id);

ALTER TABLE ONLY project_languages ADD CONSTRAINT project_languages_project_id_fkey FOREIGN KEY (project_id) REFERENCES projects(id);

ALTER TABLE ONLY project_members ADD CONSTRAINT project_members_repo_id_fkey FOREIGN KEY (repo_id) REFERENCES projects(id);
ALTER TABLE ONLY project_members ADD CONSTRAINT project_members_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id);

ALTER TABLE ONLY project_topics ADD CONSTRAINT project_topics_project_id_fkey FOREIGN KEY (project_id) REFERENCES projects(id);

ALTER TABLE ONLY projects ADD CONSTRAINT projects_forked_commit_id_fkey FOREIGN KEY (forked_commit_id) REFERENCES commits(id);
ALTER TABLE ONLY projects ADD CONSTRAINT projects_forked_from_fkey FOREIGN KEY (forked_from) REFERENCES projects(id);
ALTER TABLE ONLY projects ADD CONSTRAINT projects_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES users(id);

ALTER TABLE ONLY pull_request_comments ADD CONSTRAINT pull_request_comments_commit_id_fkey FOREIGN KEY (commit_id) REFERENCES commits(id);
ALTER TABLE ONLY pull_request_comments ADD CONSTRAINT pull_request_comments_pull_request_id_fkey FOREIGN KEY (pull_request_id) REFERENCES pull_requests(id);
ALTER TABLE ONLY pull_request_comments ADD CONSTRAINT pull_request_comments_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id);

ALTER TABLE ONLY pull_request_commits ADD CONSTRAINT pull_request_commits_commit_id_fkey FOREIGN KEY (commit_id) REFERENCES commits(id);
ALTER TABLE ONLY pull_request_commits ADD CONSTRAINT pull_request_commits_pull_request_id_fkey FOREIGN KEY (pull_request_id) REFERENCES pull_requests(id);

ALTER TABLE ONLY pull_request_history ADD CONSTRAINT pull_request_history_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES users(id);
ALTER TABLE ONLY pull_request_history ADD CONSTRAINT pull_request_history_pull_request_id_fkey FOREIGN KEY (pull_request_id) REFERENCES pull_requests(id);

ALTER TABLE ONLY pull_requests ADD CONSTRAINT pull_requests_base_commit_id_fkey FOREIGN KEY (base_commit_id) REFERENCES commits(id);
ALTER TABLE ONLY pull_requests ADD CONSTRAINT pull_requests_base_repo_id_fkey FOREIGN KEY (base_repo_id) REFERENCES projects(id);
ALTER TABLE ONLY pull_requests ADD CONSTRAINT pull_requests_head_commit_id_fkey FOREIGN KEY (head_commit_id) REFERENCES commits(id);
ALTER TABLE ONLY pull_requests ADD CONSTRAINT pull_requests_head_repo_id_fkey FOREIGN KEY (head_repo_id) REFERENCES projects(id);

ALTER TABLE ONLY repo_labels ADD CONSTRAINT repo_labels_repo_id_fkey FOREIGN KEY (repo_id) REFERENCES projects(id);

ALTER TABLE ONLY repo_milestones ADD CONSTRAINT repo_milestones_repo_id_fkey FOREIGN KEY (repo_id) REFERENCES projects(id);

ALTER TABLE ONLY watchers ADD CONSTRAINT watchers_repo_id_fkey FOREIGN KEY (repo_id) REFERENCES projects(id);
ALTER TABLE ONLY watchers ADD CONSTRAINT watchers_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id);
\timing
