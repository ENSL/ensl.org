-- FIXME: this should be somewhere else probably
CREATE DATABASE IF NOT EXISTS ensl_development;
GRANT ALL PRIVILEGES ON ensl_development.* TO 'ensl'@'%' WITH GRANT OPTION;

CREATE DATABASE IF NOT EXISTS ensl_test;
GRANT ALL PRIVILEGES ON ensl_test.* TO 'ensl'@'%' WITH GRANT OPTION;

CREATE DATABASE IF NOT EXISTS ensl_staging;
GRANT ALL PRIVILEGES ON ensl_staging.* TO 'ensl'@'%' WITH GRANT OPTION;