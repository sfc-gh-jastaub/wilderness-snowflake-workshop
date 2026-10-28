-- =====================================================================================
-- 00_bootstrap.sql  ·  Wilderness Outfitters workshop
-- The only thing you paste. It connects your account to the workshop's GitHub repo and
-- runs the rest of the setup from there.
-- =====================================================================================
USE ROLE ACCOUNTADMIN;
CREATE WAREHOUSE IF NOT EXISTS WILDERNESS_WH WAREHOUSE_SIZE = SMALL AUTO_SUSPEND = 60 AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE;
USE WAREHOUSE WILDERNESS_WH;
CREATE DATABASE IF NOT EXISTS WILDERNESS_HOL;
CREATE SCHEMA IF NOT EXISTS WILDERNESS_HOL.GIT;

CREATE OR REPLACE API INTEGRATION WILDERNESS_GIT_API
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/sfc-gh-jastaub/')
  ENABLED = TRUE;

CREATE OR REPLACE GIT REPOSITORY WILDERNESS_HOL.GIT.WORKSHOP_REPO
  API_INTEGRATION = WILDERNESS_GIT_API
  ORIGIN = 'https://github.com/sfc-gh-jastaub/wilderness-snowflake-workshop.git';

-- Core setup, about 2 minutes: infrastructure, data, feedback, semantic view, Lab 3 assets
EXECUTE IMMEDIATE FROM @WILDERNESS_HOL.GIT.WORKSHOP_REPO/branches/main/setup/10_setup_core.sql;

SELECT STEP, STATUS, ROWS_AFFECTED, LOGGED_AT FROM WILDERNESS_HOL.GIT.SETUP_LOG ORDER BY LOGGED_AT;
