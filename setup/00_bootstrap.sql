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
CREATE SCHEMA IF NOT EXISTS WILDERNESS_HOL.SETUP;

CREATE OR REPLACE API INTEGRATION WILDERNESS_GIT_API
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/sfc-gh-jastaub/')
  ENABLED = TRUE;

CREATE OR REPLACE GIT REPOSITORY WILDERNESS_HOL.SETUP.WORKSHOP_REPO
  API_INTEGRATION = WILDERNESS_GIT_API
  ORIGIN = 'https://github.com/sfc-gh-jastaub/wilderness-snowflake-workshop.git';

-- Core setup, about 2 minutes: infrastructure, data, feedback, semantic view, Lab 3 assets
EXECUTE IMMEDIATE FROM @WILDERNESS_HOL.SETUP.WORKSHOP_REPO/branches/main/setup/10_setup_core.sql;

SELECT STEP, STATUS, ROWS_AFFECTED, LOGGED_AT FROM WILDERNESS_HOL.SETUP.SETUP_LOG ORDER BY LOGGED_AT;

-- Your link to open the workshop repo as a workspace, with the form already filled in
SELECT 'https://app.snowflake.com/' || LOWER(CURRENT_ORGANIZATION_NAME()) || '/' || LOWER(CURRENT_ACCOUNT_NAME())
    || '/#/workspaces?action=create_workspace_from_git_repo'
    || '&remoteUrl=https%3A%2F%2Fgithub.com%2Fsfc-gh-jastaub%2Fwilderness-snowflake-workshop'
    || '&workspaceName=wilderness-snowflake-workshop&apiIntegration=WILDERNESS_GIT_API&authType=NONE'
    AS OPEN_WORKSHOP_REPO;
