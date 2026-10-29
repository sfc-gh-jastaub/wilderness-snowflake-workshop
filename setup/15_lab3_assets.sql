-- =====================================================================================
-- 15_lab3_assets.sql  ·  Wilderness Outfitters workshop
-- The Lab 3 evaluation questions and dataset, the email integration and the report email procedure
-- (the procedure is used by the report skill in Lab 1 optional Step 9).
-- =====================================================================================
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WILDERNESS_WH;

-- Eight questions for the Lab 3 agent evaluation. Ground truth comes from this data, with fixed dates.
CREATE OR REPLACE TABLE WILDERNESS_HOL.EVALS.AGENT_EVAL_QUESTIONS (
  QUESTION_ID  INT,
  INPUT_QUERY  VARCHAR,
  GROUND_TRUTH VARIANT
);

INSERT INTO WILDERNESS_HOL.EVALS.AGENT_EVAL_QUESTIONS
SELECT $1, $2, PARSE_JSON($3) FROM VALUES
  (1, 'Which stores will still have too many tents on Boxing Day, and which will run out?',
      '{"ground_truth_output": "A correct answer covers both halves. Too many tents: the overstock is concentrated in Victoria and Tasmania, led by the Summit 2P Tent, where 14 stores hold more than 7.5 weeks of cover (about 1,909 units, AUD 553,164 at cost, left on Boxing Day). Counting other tent lines as well is acceptable if the answer still names Victoria and Tasmania. Run out: 11 stores, all in NSW, QLD, run out of the Summit 3P Tent before Christmas. An answer that misses either half, or puts the overstock outside Victoria and Tasmania, is wrong.", "ground_truth_invocations": [{"tool_name": "retail_analyst"}]}'),
  (2, 'Which stores will run out of sleeping gear before Christmas, and when?',
      '{"ground_truth_output": "31 stores will run short of sleeping gear before 24 December, 23 of them in NSW and QLD. Most run out in the week of 7 December (27 stores); the earliest week is 2026-11-30 and the latest 2026-12-14. The shortfall is about 3,837 units, AUD 435,673 of kit sales at risk.", "ground_truth_invocations": [{"tool_name": "retail_analyst"}]}'),
  (3, 'Customers are bringing the Summit 2P back. What are they saying, and is it worse for some batches than others?',
      '{"ground_truth_output": "Batch B26-07 is the problem: 17.2% of Summit 2P Tents sold from it have come back (702 of 4,087), against 3.5% to 4.0% for every other batch. Customers describe two faults: the pole snapping or cracking at the hub, and the seam tape lifting so the tent leaks in rain.", "ground_truth_invocations": [{"tool_name": "retail_analyst"}, {"tool_name": "customer_feedback"}]}'),
  (4, 'What are customers saying about the Summit 2P tent?',
      '{"ground_truth_output": "Most Summit 2P comments are about faults: seams leaking in rain and poles cracking or snapping at the hub. Some customers praise how quick it is to pitch and how it does in dry weather. The answer quotes customers word for word.", "ground_truth_invocations": [{"tool_name": "customer_feedback"}]}'),
  (5, 'What were net sales over the launch weekend last year?',
      '{"ground_truth_output": "Over the launch weekend last year, 1 to 3 November 2025, net sales were AUD 5,955,928.", "ground_truth_invocations": [{"tool_name": "retail_analyst"}]}'),
  (6, 'What were net sales last financial year?',
      '{"ground_truth_output": "Net sales in the last financial year, FY26 (1 July 2025 to 30 June 2026), were AUD 378,017,732.", "ground_truth_invocations": [{"tool_name": "retail_analyst"}]}'),
  (7, 'How many tents did we sell over the launch weekend last year?',
      '{"ground_truth_output": "Wilderness sold 2,249 tents over the launch weekend last year, 1 to 3 November 2025.", "ground_truth_invocations": [{"tool_name": "retail_analyst"}]}'),
  (8, 'What''s the weather in Byron Bay on Christmas Day?',
      '{"ground_truth_output": "The agent says it has no weather data and does not guess. It offers to answer questions about Wilderness sales, stock, returns or customer feedback instead. It does not send the user to other websites or apps.", "ground_truth_invocations": []}');

-- The dataset the Evaluations tab picks in Lab 3 Step 2 (Existing dataset).
DROP DATASET IF EXISTS WILDERNESS_HOL.EVALS.CHRISTMAS_EVAL_SET;
CALL SYSTEM$CREATE_EVALUATION_DATASET(
  'Cortex Agent',
  'WILDERNESS_HOL.EVALS.AGENT_EVAL_QUESTIONS',
  'WILDERNESS_HOL.EVALS.CHRISTMAS_EVAL_SET',
  OBJECT_CONSTRUCT('query_text', 'INPUT_QUERY', 'expected_tools', 'GROUND_TRUTH'));

-- Where evaluation configuration files live (Lab 3 optional Step 10, and the build's own checks).
CREATE STAGE IF NOT EXISTS WILDERNESS_HOL.EVALS.EVAL_CONFIG
  DIRECTORY = (ENABLE = TRUE)
  COMMENT = 'Wilderness workshop: evaluation config files';

-- Settings the setup writes once: the address reports go to.
CREATE TABLE IF NOT EXISTS WILDERNESS_HOL.GIT.WORKSHOP_SETTINGS (KEY VARCHAR, VALUE VARCHAR);

-- Email: reports only ever go to the email on your own Snowflake user.
-- @ACCOUNT_LEVEL
EXECUTE IMMEDIATE $$
DECLARE
  v_user  VARCHAR DEFAULT CURRENT_USER();
  v_email VARCHAR;
BEGIN
  EXECUTE IMMEDIATE 'DESC USER "' || REPLACE(:v_user, '"', '""') || '"';
  SELECT MAX("value") INTO :v_email FROM TABLE(RESULT_SCAN(LAST_QUERY_ID())) WHERE "property" = 'EMAIL';
  IF (v_email IS NULL OR v_email = 'null'
      OR NOT REGEXP_LIKE(v_email, '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$')) THEN
    CALL WILDERNESS_HOL.GIT.LOG_STEP('EMAIL', 'NO_EMAIL_ON_USER', NULL);
    RETURN 'No valid email on your Snowflake user. Add one under Settings, then run this file again.';
  END IF;
  MERGE INTO WILDERNESS_HOL.GIT.WORKSHOP_SETTINGS t USING (SELECT 'REPORT_EMAIL' AS KEY, :v_email AS VALUE) s
    ON t.KEY = s.KEY
    WHEN MATCHED THEN UPDATE SET VALUE = s.VALUE
    WHEN NOT MATCHED THEN INSERT (KEY, VALUE) VALUES (s.KEY, s.VALUE);
  EXECUTE IMMEDIATE 'CREATE OR REPLACE NOTIFICATION INTEGRATION WILDERNESS_EMAIL TYPE = EMAIL ENABLED = TRUE '
                 || 'ALLOWED_RECIPIENTS = (''' || :v_email || ''') '
                 || 'COMMENT = ''Wilderness workshop: reports to your own email only''';
  CALL WILDERNESS_HOL.GIT.LOG_STEP('EMAIL', 'OK', NULL);
  RETURN 'Email set up for ' || v_email;
END;
$$;

CREATE OR REPLACE PROCEDURE WILDERNESS_HOL.AGENTS.SEND_REPORT_EMAIL(SUBJECT VARCHAR, HTML_BODY VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
COMMENT = 'Emails an HTML report to your own email address. It takes no recipient, so it cannot send anywhere else.'
AS
$$
DECLARE
  v_email VARCHAR;
BEGIN
  SELECT MAX(VALUE) INTO :v_email FROM WILDERNESS_HOL.GIT.WORKSHOP_SETTINGS WHERE KEY = 'REPORT_EMAIL';
  IF (v_email IS NULL) THEN
    RETURN 'Not sent: email is not set up. Run setup/15_lab3_assets.sql again.';
  END IF;
  IF (LENGTH(HTML_BODY) > 60000) THEN
    RETURN 'Not sent: the report is ' || LENGTH(HTML_BODY) || ' characters and the limit is 60,000.';
  END IF;
  CALL SYSTEM$SEND_EMAIL('WILDERNESS_EMAIL', :v_email, :SUBJECT, :HTML_BODY, 'text/html');
  RETURN 'Sent to ' || v_email || ' at ' || TO_VARCHAR(CURRENT_TIMESTAMP(), 'YYYY-MM-DD HH24:MI');
EXCEPTION
  WHEN OTHER THEN
    RETURN 'Not sent: ' || :SQLERRM;
END;
$$;

CALL WILDERNESS_HOL.GIT.LOG_STEP('LAB3_ASSETS', 'OK',
  (SELECT COUNT(*) FROM WILDERNESS_HOL.EVALS.AGENT_EVAL_QUESTIONS));
