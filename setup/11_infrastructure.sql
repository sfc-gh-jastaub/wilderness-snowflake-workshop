-- =====================================================================================
-- 11_infrastructure.sql  ·  Wilderness Outfitters workshop
-- Schemas, stages, the project tag, the account timezone, the CoWork object and the
-- setup log. Safe to run again: nothing here replaces an object that holds data.
-- =====================================================================================
USE ROLE ACCOUNTADMIN;

CREATE WAREHOUSE IF NOT EXISTS WILDERNESS_WH
  WAREHOUSE_SIZE = SMALL AUTO_SUSPEND = 60 AUTO_RESUME = TRUE INITIALLY_SUSPENDED = TRUE;
USE WAREHOUSE WILDERNESS_WH;

CREATE DATABASE IF NOT EXISTS WILDERNESS_HOL;
-- One schema for the data, one per lab, one for the workshop's own plumbing (S27).
CREATE SCHEMA IF NOT EXISTS WILDERNESS_HOL.RAW COMMENT = 'Wilderness data: the source tables and the curated views over them';
CREATE SCHEMA IF NOT EXISTS WILDERNESS_HOL.LAB1_ASSISTANT COMMENT = 'Lab 1: what you build with Cortex Code';
CREATE SCHEMA IF NOT EXISTS WILDERNESS_HOL.LAB2_ANALYTICS COMMENT = 'Lab 2: the notebook outputs, the stock plan and the app';
CREATE SCHEMA IF NOT EXISTS WILDERNESS_HOL.LAB3_PRODUCTION COMMENT = 'Lab 3: the production assistant, its evaluations and controls';
CREATE SCHEMA IF NOT EXISTS WILDERNESS_HOL.SETUP COMMENT = 'Workshop setup: the repository, the setup log and settings';

-- Landing area for the feedback file.
CREATE STAGE IF NOT EXISTS WILDERNESS_HOL.RAW.LANDING;

-- One tag scopes the project budget in Lab 3.
CREATE TAG IF NOT EXISTS WILDERNESS_HOL.SETUP.PROJECT ALLOWED_VALUES 'wilderness_christmas';
ALTER DATABASE WILDERNESS_HOL SET TAG WILDERNESS_HOL.SETUP.PROJECT = 'wilderness_christmas';
ALTER WAREHOUSE WILDERNESS_WH SET TAG WILDERNESS_HOL.SETUP.PROJECT = 'wilderness_christmas';

-- Wilderness trades on Sydney time, so emails and CoWork automations read in local time.
-- @ACCOUNT_LEVEL
ALTER ACCOUNT SET TIMEZONE = 'Australia/Sydney';

-- The CoWork object. Created only if this account has none yet; never replaced.
-- @ACCOUNT_LEVEL
CREATE SNOWFLAKE INTELLIGENCE IF NOT EXISTS SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT;

-- Setup log: one row per step, updated in place on a re-run.
CREATE TABLE IF NOT EXISTS WILDERNESS_HOL.SETUP.SETUP_LOG (
  STEP          VARCHAR,
  STATUS        VARCHAR,
  ROWS_AFFECTED NUMBER,
  LOGGED_AT     TIMESTAMP_LTZ,
  DETAIL        VARCHAR
);

CREATE OR REPLACE PROCEDURE WILDERNESS_HOL.SETUP.LOG_STEP(P_STEP VARCHAR, P_STATUS VARCHAR, P_ROWS NUMBER)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
  MERGE INTO WILDERNESS_HOL.SETUP.SETUP_LOG L
  USING (SELECT :P_STEP AS STEP) S ON L.STEP = S.STEP
  WHEN MATCHED THEN UPDATE SET STATUS = :P_STATUS, ROWS_AFFECTED = :P_ROWS,
                               LOGGED_AT = CURRENT_TIMESTAMP(), DETAIL = NULL
  WHEN NOT MATCHED THEN INSERT (STEP, STATUS, ROWS_AFFECTED, LOGGED_AT)
                        VALUES (:P_STEP, :P_STATUS, :P_ROWS, CURRENT_TIMESTAMP());
  RETURN P_STEP || ' ' || P_STATUS;
END;
$$;

CALL WILDERNESS_HOL.SETUP.LOG_STEP('INFRASTRUCTURE', 'OK', NULL);

-- Lab 2's notebook runs on the account's CPU compute pool. Starting it now, and keeping it up for
-- three hours, means the notebook connects quickly in Lab 2 instead of waiting for the pool to start.
-- A new notebook service then defaults to a 4-hour idle timeout rather than 24 hours, so a notebook
-- left open after the workshop stops on its own. Teardown puts both back.
-- @ACCOUNT_LEVEL
EXECUTE IMMEDIATE $$
BEGIN
  BEGIN
    ALTER ACCOUNT SET NOTEBOOK_VNEXT_IDLE_TIMEOUT_OPTIONS_MINUTES = '240,120,480,1440';
  EXCEPTION WHEN OTHER THEN NULL;  -- parameter not available in this account
  END;
  ALTER COMPUTE POOL SYSTEM_COMPUTE_POOL_CPU SET AUTO_SUSPEND_SECS = 10800;
  BEGIN
    ALTER COMPUTE POOL SYSTEM_COMPUTE_POOL_CPU RESUME;
  EXCEPTION WHEN OTHER THEN NULL;  -- already running
  END;
  CALL WILDERNESS_HOL.SETUP.LOG_STEP('NOTEBOOK_COMPUTE', 'OK', NULL);
  RETURN 'Notebook compute pool started';
EXCEPTION WHEN OTHER THEN
  CALL WILDERNESS_HOL.SETUP.LOG_STEP('NOTEBOOK_COMPUTE', 'NO_CPU_POOL', NULL);
  RETURN 'No SYSTEM_COMPUTE_POOL_CPU in this account';
END;
$$;
