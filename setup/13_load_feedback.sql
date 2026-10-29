-- =====================================================================================
-- 13_load_feedback.sql  ·  Wilderness Outfitters workshop
-- Loads 20,000 customer comments (reviews, return comments, contact centre messages)
-- from the repo's data/ folder into RAW.CUSTOMER_FEEDBACK.
-- =====================================================================================
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WILDERNESS_WH;

CREATE OR REPLACE FILE FORMAT WILDERNESS_HOL.RAW.FF_FEEDBACK_CSV
  TYPE = CSV COMPRESSION = GZIP SKIP_HEADER = 1 FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  EMPTY_FIELD_AS_NULL = TRUE NULL_IF = ('');

COPY FILES INTO @WILDERNESS_HOL.RAW.LANDING/feedback/
  FROM @WILDERNESS_HOL.SETUP.WORKSHOP_REPO/branches/main/data/
  FILES = ('customer_feedback.csv.gz');

CREATE OR REPLACE TABLE WILDERNESS_HOL.RAW.CUSTOMER_FEEDBACK (
  FEEDBACK_ID     VARCHAR,
  FEEDBACK_DATE   DATE,
  FEEDBACK_SOURCE VARCHAR,
  PRODUCT_ID      VARCHAR,
  PRODUCT_NAME    VARCHAR,
  CATEGORY        VARCHAR,
  BATCH_CODE      VARCHAR,
  STORE_ID        VARCHAR,
  STATE           VARCHAR,
  RATING          NUMBER(1,0),
  FEEDBACK_TITLE  VARCHAR,
  FEEDBACK_TEXT   VARCHAR
);

COPY INTO WILDERNESS_HOL.RAW.CUSTOMER_FEEDBACK
  FROM @WILDERNESS_HOL.RAW.LANDING/feedback/
  FILES = ('customer_feedback.csv.gz')
  FILE_FORMAT = (FORMAT_NAME = 'WILDERNESS_HOL.RAW.FF_FEEDBACK_CSV')
  FORCE = TRUE;

CALL WILDERNESS_HOL.SETUP.LOG_STEP('FEEDBACK', 'OK',
  (SELECT COUNT(*) FROM WILDERNESS_HOL.RAW.CUSTOMER_FEEDBACK));
