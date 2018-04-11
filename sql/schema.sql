SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;
SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;
SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='TRADITIONAL,ALLOW_INVALID_DATES';
SET @OLD_TIME_ZONE=@@session.time_zone;

DROP SCHEMA IF EXISTS `ghtorrent` ;
CREATE SCHEMA IF NOT EXISTS `ghtorrent` DEFAULT CHARACTER SET utf8 ;
USE `ghtorrent` ;

-- -----------------------------------------------------
-- Table `ghtorrent`.`users`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `ghtorrent`.`users` ;

CREATE TABLE IF NOT EXISTS `ghtorrent`.`users` (
  `id` INT(11) NOT NULL AUTO_INCREMENT COMMENT '',
  `login` VARCHAR(255) NOT NULL COMMENT '',
  `company` VARCHAR(255) NULL DEFAULT NULL COMMENT '',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '',
  `type` VARCHAR(255) NOT NULL DEFAULT 'USR' COMMENT '',
  `fake` TINYINT(1) NOT NULL DEFAULT '0' COMMENT '',
  `deleted` TINYINT(1) NOT NULL DEFAULT '0' COMMENT '',
  `long` DECIMAL(11,8) COMMENT '',
  `lat` DECIMAL(10,8) COMMENT '',
  `country_code` CHAR(3) COMMENT '',
  `state` VARCHAR(255) COMMENT '',
  `city` VARCHAR(255) COMMENT '',
  `location` VARCHAR(255) NULL DEFAULT NULL COMMENT '',
  PRIMARY KEY (`id`)  COMMENT '')
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8;

-- -----------------------------------------------------
-- Table `ghtorrent`.`projects`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `ghtorrent`.`projects` ;

SET time_zone='+0:00';
CREATE TABLE IF NOT EXISTS `ghtorrent`.`projects` (
  `id` INT(11) NOT NULL AUTO_INCREMENT COMMENT '',
  `url` VARCHAR(255) NULL DEFAULT NULL COMMENT '',
  `owner_id` INT(11) NULL DEFAULT NULL COMMENT '',
  `name` VARCHAR(255) NOT NULL COMMENT '',
  `description` VARCHAR(255) NULL DEFAULT NULL COMMENT '',
  `language` VARCHAR(255) NULL DEFAULT NULL COMMENT '',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '',
  `forked_from` INT(11) NULL DEFAULT NULL COMMENT '',
  `deleted` TINYINT(1) NOT NULL DEFAULT '0' COMMENT '',
  `updated_at` TIMESTAMP NOT NULL DEFAULT '1970-01-01 00:00:01' COMMENT '',
  PRIMARY KEY (`id`)  COMMENT '',
  CONSTRAINT `projects_ibfk_1`
    FOREIGN KEY (`owner_id`)
    REFERENCES `ghtorrent`.`users` (`id`),
  CONSTRAINT `projects_ibfk_2`
    FOREIGN KEY (`forked_from`)
    REFERENCES `ghtorrent`.`projects` (`id`))
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8;
SET time_zone=@OLD_TIME_ZONE;

-- -----------------------------------------------------
-- Table `ghtorrent`.`commits`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `ghtorrent`.`commits` ;

CREATE TABLE IF NOT EXISTS `ghtorrent`.`commits` (
  `id` INT(11) NOT NULL AUTO_INCREMENT COMMENT '',
  `sha` VARCHAR(40) NULL DEFAULT NULL COMMENT '',
  `author_id` INT(11) NULL DEFAULT NULL COMMENT '',
  `committer_id` INT(11) NULL DEFAULT NULL COMMENT '',
  `project_id` INT(11) NULL DEFAULT NULL COMMENT '',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '',
  PRIMARY KEY (`id`)  COMMENT '',
  CONSTRAINT `commits_ibfk_1`
    FOREIGN KEY (`author_id`)
    REFERENCES `ghtorrent`.`users` (`id`),
  CONSTRAINT `commits_ibfk_2`
    FOREIGN KEY (`committer_id`)
    REFERENCES `ghtorrent`.`users` (`id`),
  CONSTRAINT `commits_ibfk_3`
    FOREIGN KEY (`project_id`)
    REFERENCES `ghtorrent`.`projects` (`id`))
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8;

-- -----------------------------------------------------
-- Table `ghtorrent`.`commit_comments`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `ghtorrent`.`commit_comments` ;

CREATE TABLE IF NOT EXISTS `ghtorrent`.`commit_comments` (
  `id` INT(11) NOT NULL AUTO_INCREMENT COMMENT '',
  `commit_id` INT(11) NOT NULL COMMENT '',
  `user_id` INT(11) NOT NULL COMMENT '',
  `body` VARCHAR(256) NULL DEFAULT NULL COMMENT '',
  `line` INT(11) NULL DEFAULT NULL COMMENT '',
  `position` INT(11) NULL DEFAULT NULL COMMENT '',
  `comment_id` INT(11) NOT NULL COMMENT '',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '',
  PRIMARY KEY (`id`)  COMMENT '',
  CONSTRAINT `commit_comments_ibfk_1`
    FOREIGN KEY (`commit_id`)
    REFERENCES `ghtorrent`.`commits` (`id`),
  CONSTRAINT `commit_comments_ibfk_2`
    FOREIGN KEY (`user_id`)
    REFERENCES `ghtorrent`.`users` (`id`))
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8;

-- -----------------------------------------------------
-- Table `ghtorrent`.`commit_parents`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `ghtorrent`.`commit_parents` ;

CREATE TABLE IF NOT EXISTS `ghtorrent`.`commit_parents` (
  `commit_id` INT(11) NOT NULL COMMENT '',
  `parent_id` INT(11) NOT NULL COMMENT '',
  CONSTRAINT `commit_parents_ibfk_1`
    FOREIGN KEY (`commit_id`)
    REFERENCES `ghtorrent`.`commits` (`id`),
  CONSTRAINT `commit_parents_ibfk_2`
    FOREIGN KEY (`parent_id`)
    REFERENCES `ghtorrent`.`commits` (`id`))
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8;

-- -----------------------------------------------------
-- Table `ghtorrent`.`followers`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `ghtorrent`.`followers` ;

CREATE TABLE IF NOT EXISTS `ghtorrent`.`followers` (
  `follower_id` INT(11) NOT NULL COMMENT '',
  `user_id` INT(11) NOT NULL COMMENT '',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '',
  PRIMARY KEY (`follower_id`, `user_id`)  COMMENT '',
  CONSTRAINT `follower_fk1`
    FOREIGN KEY (`follower_id`)
    REFERENCES `ghtorrent`.`users` (`id`),
  CONSTRAINT `follower_fk2`
    FOREIGN KEY (`user_id`)
    REFERENCES `ghtorrent`.`users` (`id`))
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8;

-- -----------------------------------------------------
-- Table `ghtorrent`.`pull_requests`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `ghtorrent`.`pull_requests` ;

CREATE TABLE IF NOT EXISTS `ghtorrent`.`pull_requests` (
  `id` INT(11) NOT NULL AUTO_INCREMENT COMMENT '',
  `head_repo_id` INT(11) NULL DEFAULT NULL COMMENT '',
  `base_repo_id` INT(11) NOT NULL COMMENT '',
  `head_commit_id` INT(11) NULL DEFAULT NULL COMMENT '',
  `base_commit_id` INT(11) NOT NULL COMMENT '',
  `pullreq_id` INT(11) NOT NULL COMMENT '',
  `intra_branch` TINYINT(1) NOT NULL COMMENT '',
  PRIMARY KEY (`id`)  COMMENT '',
  CONSTRAINT `pull_requests_ibfk_1`
    FOREIGN KEY (`head_repo_id`)
    REFERENCES `ghtorrent`.`projects` (`id`),
  CONSTRAINT `pull_requests_ibfk_2`
    FOREIGN KEY (`base_repo_id`)
    REFERENCES `ghtorrent`.`projects` (`id`),
  CONSTRAINT `pull_requests_ibfk_3`
    FOREIGN KEY (`head_commit_id`)
    REFERENCES `ghtorrent`.`commits` (`id`),
  CONSTRAINT `pull_requests_ibfk_4`
    FOREIGN KEY (`base_commit_id`)
    REFERENCES `ghtorrent`.`commits` (`id`))
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8;

-- -----------------------------------------------------
-- Table `ghtorrent`.`issues`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `ghtorrent`.`issues` ;

CREATE TABLE IF NOT EXISTS `ghtorrent`.`issues` (
  `id` INT(11) NOT NULL AUTO_INCREMENT COMMENT '',
  `repo_id` INT(11) NULL DEFAULT NULL COMMENT '',
  `reporter_id` INT(11) NULL DEFAULT NULL COMMENT '',
  `assignee_id` INT(11) NULL DEFAULT NULL COMMENT '',
  `pull_request` TINYINT(1) NOT NULL COMMENT '',
  `pull_request_id` INT(11) NULL DEFAULT NULL COMMENT '',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '',
  `issue_id` INT(11) NOT NULL COMMENT '',
  PRIMARY KEY (`id`)  COMMENT '',
  CONSTRAINT `issues_ibfk_1`
    FOREIGN KEY (`repo_id`)
    REFERENCES `ghtorrent`.`projects` (`id`),
  CONSTRAINT `issues_ibfk_2`
    FOREIGN KEY (`reporter_id`)
    REFERENCES `ghtorrent`.`users` (`id`),
  CONSTRAINT `issues_ibfk_3`
    FOREIGN KEY (`assignee_id`)
    REFERENCES `ghtorrent`.`users` (`id`),
  CONSTRAINT `issues_ibfk_4`
    FOREIGN KEY (`pull_request_id`)
    REFERENCES `ghtorrent`.`pull_requests` (`id`))
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8;

-- -----------------------------------------------------
-- Table `ghtorrent`.`issue_comments`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `ghtorrent`.`issue_comments` ;

CREATE TABLE IF NOT EXISTS `ghtorrent`.`issue_comments` (
  `issue_id` INT(11) NOT NULL COMMENT '',
  `user_id` INT(11) NOT NULL COMMENT '',
  `comment_id` MEDIUMTEXT NOT NULL COMMENT '',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '',
  CONSTRAINT `issue_comments_ibfk_1`
    FOREIGN KEY (`issue_id`)
    REFERENCES `ghtorrent`.`issues` (`id`),
  CONSTRAINT `issue_comments_ibfk_2`
    FOREIGN KEY (`user_id`)
    REFERENCES `ghtorrent`.`users` (`id`))
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8;

-- -----------------------------------------------------
-- Table `ghtorrent`.`issue_events`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `ghtorrent`.`issue_events` ;

CREATE TABLE IF NOT EXISTS `ghtorrent`.`issue_events` (
  `event_id` MEDIUMTEXT NOT NULL COMMENT '',
  `issue_id` INT(11) NOT NULL COMMENT '',
  `actor_id` INT(11) NOT NULL COMMENT '',
  `action` VARCHAR(255) NOT NULL COMMENT '',
  `action_specific` VARCHAR(50) NULL DEFAULT NULL COMMENT '',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '',
  CONSTRAINT `issue_events_ibfk_1`
    FOREIGN KEY (`issue_id`)
    REFERENCES `ghtorrent`.`issues` (`id`),
  CONSTRAINT `issue_events_ibfk_2`
    FOREIGN KEY (`actor_id`)
    REFERENCES `ghtorrent`.`users` (`id`))
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8;

-- -----------------------------------------------------
-- Table `ghtorrent`.`repo_labels`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `ghtorrent`.`repo_labels` ;

CREATE TABLE IF NOT EXISTS `ghtorrent`.`repo_labels` (
  `id` INT(11) NOT NULL AUTO_INCREMENT COMMENT '',
  `repo_id` INT(11) NULL DEFAULT NULL COMMENT '',
  `name` VARCHAR(24) NOT NULL COMMENT '',
  PRIMARY KEY (`id`)  COMMENT '',
  CONSTRAINT `repo_labels_ibfk_1`
    FOREIGN KEY (`repo_id`)
    REFERENCES `ghtorrent`.`projects` (`id`))
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8;

-- -----------------------------------------------------
-- Table `ghtorrent`.`issue_labels`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `ghtorrent`.`issue_labels` ;

CREATE TABLE IF NOT EXISTS `ghtorrent`.`issue_labels` (
  `label_id` INT(11) NOT NULL COMMENT '',
  `issue_id` INT(11) NOT NULL COMMENT '',
  PRIMARY KEY (`issue_id`, `label_id`)  COMMENT '',
  CONSTRAINT `issue_labels_ibfk_1`
    FOREIGN KEY (`label_id`)
    REFERENCES `ghtorrent`.`repo_labels` (`id`),
  CONSTRAINT `issue_labels_ibfk_2`
    FOREIGN KEY (`issue_id`)
    REFERENCES `ghtorrent`.`issues` (`id`))
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8;

-- -----------------------------------------------------
-- Table `ghtorrent`.`organization_members`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `ghtorrent`.`organization_members` ;

CREATE TABLE IF NOT EXISTS `ghtorrent`.`organization_members` (
  `org_id` INT(11) NOT NULL COMMENT '',
  `user_id` INT(11) NOT NULL COMMENT '',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '',
  PRIMARY KEY (`org_id`, `user_id`)  COMMENT '',
  CONSTRAINT `organization_members_ibfk_1`
    FOREIGN KEY (`org_id`)
    REFERENCES `ghtorrent`.`users` (`id`),
  CONSTRAINT `organization_members_ibfk_2`
    FOREIGN KEY (`user_id`)
    REFERENCES `ghtorrent`.`users` (`id`))
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8;

-- -----------------------------------------------------
-- Table `ghtorrent`.`project_commits`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `ghtorrent`.`project_commits` ;

CREATE TABLE IF NOT EXISTS `ghtorrent`.`project_commits` (
  `project_id` INT(11) NOT NULL DEFAULT '0' COMMENT '',
  `commit_id` INT(11) NOT NULL DEFAULT '0' COMMENT '',
  CONSTRAINT `project_commits_ibfk_1`
    FOREIGN KEY (`project_id`)
    REFERENCES `ghtorrent`.`projects` (`id`),
  CONSTRAINT `project_commits_ibfk_2`
    FOREIGN KEY (`commit_id`)
    REFERENCES `ghtorrent`.`commits` (`id`))
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8;

-- -----------------------------------------------------
-- Table `ghtorrent`.`project_members`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `ghtorrent`.`project_members` ;

CREATE TABLE IF NOT EXISTS `ghtorrent`.`project_members` (
  `repo_id` INT(11) NOT NULL COMMENT '',
  `user_id` INT(11) NOT NULL COMMENT '',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '',
  `ext_ref_id` VARCHAR(24) NOT NULL DEFAULT '0' COMMENT '',
  PRIMARY KEY (`repo_id`, `user_id`)  COMMENT '',
  CONSTRAINT `project_members_ibfk_1`
    FOREIGN KEY (`repo_id`)
    REFERENCES `ghtorrent`.`projects` (`id`),
  CONSTRAINT `project_members_ibfk_2`
    FOREIGN KEY (`user_id`)
    REFERENCES `ghtorrent`.`users` (`id`))
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8;

-- -----------------------------------------------------
-- Table `ghtorrent`.`project_languages`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `ghtorrent`.`project_languages` ;

CREATE TABLE IF NOT EXISTS `ghtorrent`.`project_languages` (
  `project_id` INT(11) NOT NULL COMMENT '',
  `language` VARCHAR(255) NULL DEFAULT NULL COMMENT '',
  `bytes` INT(11) COMMENT '',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '',
  CONSTRAINT `project_languages_ibfk_1`
    FOREIGN KEY (`project_id`)
    REFERENCES `ghtorrent`.`projects` (`id`))
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8;

-- -----------------------------------------------------
-- Table `ghtorrent`.`project_topics`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `ghtorrent`.`project_topics` ;

CREATE TABLE IF NOT EXISTS `ghtorrent`.`project_topics` (
  `project_id` INT(11) NOT NULL COMMENT '',
  `topic_name` VARCHAR(255) COMMENT '',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '',
  `deleted` TINYINT(1) NOT NULL DEFAULT '0' COMMENT '',
  PRIMARY KEY (`project_id`, `topic_name`)  COMMENT '',
  CONSTRAINT `project_topics_ibfk_1`
    FOREIGN KEY (`project_id`)
    REFERENCES `ghtorrent`.`projects` (`id`))
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8;

-- -----------------------------------------------------
-- Table `ghtorrent`.`pull_request_comments`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `ghtorrent`.`pull_request_comments` ;

CREATE TABLE IF NOT EXISTS `ghtorrent`.`pull_request_comments` (
  `pull_request_id` INT(11) NOT NULL COMMENT '',
  `user_id` INT(11) NOT NULL COMMENT '',
  `comment_id` MEDIUMTEXT NOT NULL COMMENT '',
  `position` INT(11) NULL DEFAULT NULL COMMENT '',
  `body` VARCHAR(256) NULL DEFAULT NULL COMMENT '',
  `commit_id` INT(11) NOT NULL COMMENT '',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '',
  CONSTRAINT `pull_request_comments_ibfk_1`
    FOREIGN KEY (`pull_request_id`)
    REFERENCES `ghtorrent`.`pull_requests` (`id`),
  CONSTRAINT `pull_request_comments_ibfk_2`
    FOREIGN KEY (`user_id`)
    REFERENCES `ghtorrent`.`users` (`id`),
  CONSTRAINT `pull_request_comments_ibfk_3`
    FOREIGN KEY (`commit_id`)
    REFERENCES `ghtorrent`.`commits` (`id`))
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8;

-- -----------------------------------------------------
-- Table `ghtorrent`.`pull_request_commits`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `ghtorrent`.`pull_request_commits` ;

CREATE TABLE IF NOT EXISTS `ghtorrent`.`pull_request_commits` (
  `pull_request_id` INT(11) NOT NULL COMMENT '',
  `commit_id` INT(11) NOT NULL COMMENT '',
  PRIMARY KEY (`pull_request_id`, `commit_id`)  COMMENT '',
  CONSTRAINT `pull_request_commits_ibfk_1`
    FOREIGN KEY (`pull_request_id`)
    REFERENCES `ghtorrent`.`pull_requests` (`id`),
  CONSTRAINT `pull_request_commits_ibfk_2`
    FOREIGN KEY (`commit_id`)
    REFERENCES `ghtorrent`.`commits` (`id`))
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8;

-- -----------------------------------------------------
-- Table `ghtorrent`.`pull_request_history`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `ghtorrent`.`pull_request_history` ;

CREATE TABLE IF NOT EXISTS `ghtorrent`.`pull_request_history` (
  `id` INT(11) NOT NULL AUTO_INCREMENT COMMENT '',
  `pull_request_id` INT(11) NOT NULL COMMENT '',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '',
  `action` VARCHAR(255) NOT NULL COMMENT '',
  `actor_id` INT(11) NULL DEFAULT NULL COMMENT '',
  PRIMARY KEY (`id`)  COMMENT '',
  CONSTRAINT `pull_request_history_ibfk_1`
    FOREIGN KEY (`pull_request_id`)
    REFERENCES `ghtorrent`.`pull_requests` (`id`),
  CONSTRAINT `pull_request_history_ibfk_2`
    FOREIGN KEY (`actor_id`)
    REFERENCES `ghtorrent`.`users` (`id`))
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8;

-- -----------------------------------------------------
-- Table `ghtorrent`.`repo_milestones`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `ghtorrent`.`repo_milestones` ;

CREATE TABLE IF NOT EXISTS `ghtorrent`.`repo_milestones` (
  `id` INT(11) NOT NULL AUTO_INCREMENT COMMENT '',
  `repo_id` INT(11) NULL DEFAULT NULL COMMENT '',
  `name` VARCHAR(24) NOT NULL COMMENT '',
  PRIMARY KEY (`id`)  COMMENT '',
  CONSTRAINT `repo_milestones_ibfk_1`
    FOREIGN KEY (`repo_id`)
    REFERENCES `ghtorrent`.`projects` (`id`))
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8;

-- -----------------------------------------------------
-- Table `ghtorrent`.`schema_info`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `ghtorrent`.`schema_info` ;

CREATE TABLE IF NOT EXISTS `ghtorrent`.`schema_info` (
  `version` INT(11) NOT NULL DEFAULT '0' COMMENT '')
ENGINE = MyISAM
DEFAULT CHARACTER SET = utf8;

-- -----------------------------------------------------
-- Table `ghtorrent`.`watchers`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `ghtorrent`.`watchers` ;

CREATE TABLE IF NOT EXISTS `ghtorrent`.`watchers` (
  `repo_id` INT(11) NOT NULL COMMENT '',
  `user_id` INT(11) NOT NULL COMMENT '',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '',
  PRIMARY KEY (`repo_id`, `user_id`)  COMMENT '',
  CONSTRAINT `watchers_ibfk_1`
    FOREIGN KEY (`repo_id`)
    REFERENCES `ghtorrent`.`projects` (`id`),
  CONSTRAINT `watchers_ibfk_2`
    FOREIGN KEY (`user_id`)
    REFERENCES `ghtorrent`.`users` (`id`))
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8;

SET SQL_MODE=@OLD_SQL_MODE;
SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;
SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS;
