\set issues_csv :data_directory '/issues.csv'
\set commits_csv :data_directory '/commits.csv'
\set project_commits_csv :data_directory '/project_commits.csv'

\timing
copy issues from :'issues_csv' WITH (FORMAT csv, DELIMITER ',', ENCODING 'utf8', NULL "\N");
SELECT setval('issues_id_seq', (SELECT MAX(id) FROM issues));
copy commits from :'commits_csv' WITH (FORMAT csv, DELIMITER ',', ENCODING 'utf8', NULL "\N");
SELECT setval('commits_id_seq', (SELECT MAX(id) FROM commits));
copy project_commits from :'project_commits_csv' WITH (FORMAT csv, DELIMITER ',', ENCODING 'utf8', NULL "\N");
\timing
