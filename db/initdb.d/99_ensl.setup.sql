-- FIXME: this should be somewhere else probably
CREATE DATABASE ensl_test;
GRANT ALL PRIVILEGES ON ensl_test.* TO 'ensl'@'%' WITH GRANT OPTION;

CREATE DATABASE ensl_staging;
GRANT ALL PRIVILEGES ON ensl_staging.* TO 'ensl'@'%' WITH GRANT OPTION;