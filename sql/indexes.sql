CREATE UNIQUE INDEX `login` ON `ghtorrent`.`users` (`login` ASC)  COMMENT '';
CREATE UNIQUE INDEX `sha` ON `ghtorrent`.`commits` (`sha` ASC)  COMMENT '';
CREATE UNIQUE INDEX `comment_id` ON `ghtorrent`.`commit_comments` (`comment_id` ASC)  COMMENT '';
CREATE INDEX `follower_id` ON `ghtorrent`.`followers` (`follower_id` ASC) COMMENT '';
CREATE UNIQUE INDEX `pullreq_id` ON `ghtorrent`.`pull_requests` (`pullreq_id` ASC, `base_repo_id` ASC)  COMMENT '';
