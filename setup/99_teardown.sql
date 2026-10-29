-- =====================================================================================
-- 99_teardown.sql  ·  Wilderness Outfitters workshop
-- Removes everything the workshop created in this account. Delete the CoWork automation first
-- (CoWork » Automations), because it is personal and this file cannot see it.
-- =====================================================================================
USE ROLE ACCOUNTADMIN;

-- Lab 3 cost controls and governance
DROP SNOWFLAKE.CORE.QUOTA IF EXISTS WILDERNESS_HOL.LAB3_PRODUCTION.WILDERNESS_STORE_QUOTA;
DROP SNOWFLAKE.CORE.BUDGET IF EXISTS WILDERNESS_HOL.LAB3_PRODUCTION.WILDERNESS_PROJECT_BUDGET;
DROP USER IF EXISTS STORE_MANAGER_DEMO;
DROP ROLE IF EXISTS WILDERNESS_STORE_MANAGER;

-- Both assistants leave CoWork, then the database goes (agents, search, semantic views, app, data, tags)
EXECUTE IMMEDIATE $$
BEGIN
  BEGIN
    ALTER SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT DROP AGENT WILDERNESS_HOL.LAB1_ASSISTANT.WILDERNESS_ASSISTANT;
  EXCEPTION WHEN OTHER THEN NULL;
  END;
  BEGIN
    ALTER SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT DROP AGENT WILDERNESS_HOL.LAB3_PRODUCTION.WILDERNESS_ASSISTANT;
  EXCEPTION WHEN OTHER THEN NULL;
  END;
  RETURN 'Removed the Wilderness assistants from CoWork';
END;
$$;
DROP DATABASE IF EXISTS WILDERNESS_HOL;

-- Account-level objects from setup
DROP INTEGRATION IF EXISTS WILDERNESS_EMAIL;
DROP INTEGRATION IF EXISTS WILDERNESS_GIT_API;
DROP WAREHOUSE IF EXISTS WILDERNESS_WH;
ALTER ACCOUNT UNSET TIMEZONE;

SELECT 'Wilderness workshop removed' AS STATUS;
