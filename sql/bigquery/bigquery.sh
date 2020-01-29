#!/usr/bin/env bash
# Load GHTorrent CSV data to Google BigQuery
# (c) 2016 Georgios Gousios

set -x

# Make sure that you have run the following at least once
# gcloud auth login

# Before using this script, create a project and set its project id
# (NOT its public name) to the following variable
PROJECT=ghtorrent-bq
DATASET_NAME=ght_2017_04_01

# Init a BigQuery dataset for $PROJECT
bq mk $DATASET_NAME

# Preprocess "CSV" data to make it CSV compliant
sed -e 's/,\\N/,/g; s/0000-00-00 00:00:00/1970-01-01 00:00:00/g' commits.csv > commits-not-null.csv
sed -e 's/,\\N/,/g' pull_request_history.csv  > pull_request_history-not-null.csv
sed -e 's/,\\N/,/g' issue_events.csv > issue_events-not-null.csv
sed -e 's/,\\N/,/g; s/0000-00-00 00:00:00/1970-01-01 00:00:00/g' issues.csv > issues-not-null.csv
sed -e 's/,\\N/,/g; s/\\"/""/g' pull_requests.csv > pull_requests-not-null.csv
./csvify.rb commit_comments.csv|pv |sed -e 's/,\\N/,/g; s/\\\\/\\ /g; s/\\"/""/g' > commit_comments-not-null.csv
./csvify.rb pull_request_comments.csv|pv |sed -e 's/,\\N/,/g; s/\\\\/\\ /g; s/\\"/""/g' > pull_request_comments-not-null.csv
./csvify.rb projects.csv|pv |sed -e 's/,\\N/,/g; s/\\\\/\\ /g; s/\\"/""/g; s/0000-00-00 00:00:00/1970-01-01 00:00:00/g' > projects-not-null.csv
./csvify.rb users.csv| sed -e 's/,\\N/,/g; s/\\\\/\\ /g; s/\\"/""/g; s/0000-00-00 00:00:00/1970-01-01 00:00:00/g' users.csv|pv  > users-not-null.csv

# Upload to Google Cloud Storage
gsutil mb -c nearline gs://ght
gsutil cp commit_comments-not-null.csv gs://ght/commit_comments.csv
gsutil cp pull_request_comments-not-null.csv gs://ght/pull_request_comments.csv
gsutil cp followers.csv gs://ght/followers.csv
gsutil cp organization_members.csv gs://ght/organization_members.csv
gsutil cp projects-not-null.csv gs://ght/projects.csv
gsutil cp project_members.csv gs://ght/project_members.csv
gsutil cp commits-not-null.csv gs://ght/commits.csv
gsutil cp commit_parents.csv gs://ght/commit_parents.csv
gsutil cp project_commits.csv gs://ght/project_commits.csv
gsutil cp pull_requests-not-null.csv gs://ght/pull_requests.csv
gsutil cp pull_request_history-not-null.csv gs://ght/pull_request_history.csv
gsutil cp pull_request_commits.csv gs://ght/pull_request_commits.csv
gsutil cp repo_labels.csv gs://ght/repo_labels.csv
gsutil cp repo_milestones.csv gs://ght/repo_milestones.csv
gsutil cp watchers.csv gs://ght/watchers.csv
gsutil cp issues-not-null.csv gs://ght/issues.csv
gsutil cp issue_labels.csv gs://ght/issue_labels.csv
gsutil cp issue_comments.csv gs://ght/issue_comments.csv
gsutil cp issue_events-not-null.csv gs://ght/issue_events.csv
gsutil cp project_languages.csv gs://ght/project_languages.csv
gsutil cp users-not-null.csv gs://ght/users.csv

# Import to BigQuery
bq load --max_bad_records 1000 --replace $PROJECT:$DATASET_NAME.project_commits gs://ght/project_commits.csv project_id:integer,commit_id:integer
bq load --max_bad_records 1000 --replace $PROJECT:$DATASET_NAME.commit_parents gs://ght/commit_parents.csv commit_id:integer,parent_id:integer
bq load --max_bad_records 1000 --replace $PROJECT:$DATASET_NAME.followers gs://ght/followers.csv user_id:integer,follower_id:integer,created_at:timestamp
bq load --max_bad_records 1000 --replace $PROJECT:$DATASET_NAME.project_languages gs://ght/project_languages.csv project_id:integer,language:string,bytes:integer,created_at:timestamp
bq load --max_bad_records 1000 --replace $PROJECT:$DATASET_NAME.project_members gs://ght/project_members.csv repo_id:integer,user_id:integer,created_at:timestamp,dont_use:string
bq load --max_bad_records 1000 --replace $PROJECT:$DATASET_NAME.organization_members gs://ght/organization_members.csv org_id:integer,user_id:integer,created_at:timestamp
bq load --max_bad_records 1000 --replace $PROJECT:$DATASET_NAME.watchers gs://ght/watchers.csv repo_id:integer,user_id:integer,created_at:timestamp
bq load --max_bad_records 1000 --replace $PROJECT:$DATASET_NAME.issue_comments gs://ght/issue_comments.csv issue_id:integer,user_id:integer,comment_id:integer,created_at:timestamp
bq load --max_bad_records 1000 --replace $PROJECT:$DATASET_NAME.repo_labels gs://ght/repo_labels.csv id:integer,repo_id:integer,name:string
bq load --max_bad_records 1000 --replace $PROJECT:$DATASET_NAME.issue_labels gs://ght/issue_labels.csv id:integer,repo_id:integer
bq load --max_bad_records 1000 --replace $PROJECT:$DATASET_NAME.pull_request_commits gs://ght/pull_request_commits.csv pull_request_id:integer,commit_id:integer
bq load --max_bad_records 1000 --replace $PROJECT:$DATASET_NAME.pull_request_history gs://ght/pull_request_history.csv id:integer,pull_request_id:integer,created_at:timestamp,action:string,actor_id:integer
bq load --max_bad_records 1000 --replace $PROJECT:$DATASET_NAME.issue_events gs://ght/issue_events.csv event_id:integer,issue_id:integer,actor_id:integer,action:string,action_specific:string,created_at:timestamp
bq load --max_bad_records 1000 --replace $PROJECT:$DATASET_NAME.issues gs://ght/issues.csv id:integer,repo_id:integer,reporter_id:integer,assignee_id:integer,pull_request:boolean,pull_request_id:integer,created_at:timestamp,issue_id:string
bq load --max_bad_records 1000 --replace $PROJECT:$DATASET_NAME.commits gs://ght/commits.csv id:integer,sha:string,author_id:integer,committer_id:integer,project_id:integer,created_at:timestamp
bq load --max_bad_records 1000 --replace $PROJECT:$DATASET_NAME.commit_comments gs://ght/commit_comments.csv id:integer,commit_id:integer,user_id:integer,body:string,line:integer,position:integer,comment_id:integer,created_at:timestamp
bq load --max_bad_records 1000 --replace $PROJECT:$DATASET_NAME.pull_request_comments gs://ght/pull_request_comments.csv pull_request_id:integer,user_id:integer,comment_id:string,position:integer,body:string,commit_id:integer,created_at:timestamp
bq load --max_bad_records 1000 --replace $PROJECT:$DATASET_NAME.pull_requests gs://ght/pull_requests.csv id:integer,head_repo_id:integer,base_repo_id:integer,head_commit_id:integer,base_commit_id:integer,pullreq_id:integer,intra_branch:boolean
bq load --max_bad_records 1000 --replace $PROJECT:$DATASET_NAME.projects gs://ght/projects.csv id:integer,url:string,owner_id:integer,name:string,description:string,language:string,created_at:timestamp,forked_from:integer,deleted:boolean,updated_at:timestamp,forked_commit_id:integer
bq load --max_bad_records 1000 --replace $PROJECT:$DATASET_NAME.users gs://ght/users.csv id:integer,login:string,company:string,created_at:timestamp,type:string,fake:boolean,deleted:boolean,long:float,lat:float,country_code:string,state:string,city:string,location:string

# Clean up
#rm commits-not-null.csv  pull_request_history-not-null.csv issue_events-not-null.csv issues-not-null.csv users-not-null.csv pull_requests-not-null.csv projects-not-null.csv pull_request_comments-not-null.csv commit_comments-not-null.csv

gsutil rm -rf gs://ght/
