-- =====================================================================================
-- 15_lab3_assets.sql  ·  Wilderness Outfitters workshop
-- The agent evaluation questions, the email integration and the report email procedure.
-- (The compute pool and the Lab 3 notebook are added in a later build phase.)
-- =====================================================================================
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WILDERNESS_WH;

-- Eight questions for the Lab 3 agent evaluation. Ground truth comes from this data, with fixed dates.
CREATE OR REPLACE TABLE WILDERNESS_HOL.EVALS.AGENT_EVAL_QUESTIONS (
  QUESTION_ID  INT,
  INPUT_QUERY  VARCHAR,
  GROUND_TRUTH VARIANT,
  NEEDS_DOCS   BOOLEAN
);

INSERT INTO WILDERNESS_HOL.EVALS.AGENT_EVAL_QUESTIONS
SELECT $1, $2, PARSE_JSON($3), $4 FROM VALUES
  (1, 'Which stores will still have too many tents on Boxing Day, and which will run out?',
      '{"ground_truth_output": "14 stores will hold more than 7.5 weeks of Summit 2P Tent stock, 14 of them in Victoria and Tasmania: about 1,909 units (AUD 553,164 at cost) still on shelves on Boxing Day. 11 stores in NSW, QLD will run out of the Summit 3P Tent before Christmas.", "ground_truth_invocations": [{"tool_name": "retail_analyst"}]}', FALSE),
  (2, 'Which stores will run out of sleeping gear before Christmas, and when?',
      '{"ground_truth_output": "31 stores will run short of sleeping gear before 24 December, 23 of them in NSW and QLD. Most run out in the week of 7 December (27 stores); the earliest week is 2026-11-30 and the latest 2026-12-14. The shortfall is about 3,837 units, AUD 435,673 of kit sales at risk.", "ground_truth_invocations": [{"tool_name": "retail_analyst"}]}', FALSE),
  (3, 'Customers are bringing the Summit 2P back. What are they saying, and what does the Kestrel contract let us do with the stock we can''t sell?',
      '{"ground_truth_output": "Needs the supplier documents, which are not loaded yet.", "ground_truth_invocations": []}', TRUE),
  (4, 'What is the last day we can order more sleeping mats for delivery before Christmas?',
      '{"ground_truth_output": "Needs the trading playbook, which is not loaded yet.", "ground_truth_invocations": []}', TRUE),
  (5, 'How did last Christmas trading compare to the Christmas before?',
      '{"ground_truth_output": "Over the Christmas period (1 November to 24 December), net sales were AUD 107,941,622 in 2025 against AUD 94,942,495 in 2024, a change of +13.7%.", "ground_truth_invocations": [{"tool_name": "retail_analyst"}]}', FALSE),
  (6, 'What were net sales last financial year?',
      '{"ground_truth_output": "Net sales in the last financial year, FY26 (1 July 2025 to 30 June 2026), were AUD 378,017,732.", "ground_truth_invocations": [{"tool_name": "retail_analyst"}]}', FALSE),
  (7, 'How is this Christmas tracking against last Christmas so far?',
      '{"ground_truth_output": "Christmas trading started on 1 November. For 1 to 3 November, net sales were AUD 7,988,070 in 2026 against AUD 5,955,928 for the same days in 2025, a change of +34.1%.", "ground_truth_invocations": [{"tool_name": "retail_analyst"}]}', FALSE),
  (8, 'What''s the weather in Byron Bay on Christmas Day?',
      '{"ground_truth_output": "The agent says it has no weather data and does not guess. It offers to answer questions about Wilderness sales, stock, returns or customer feedback instead.", "ground_truth_invocations": []}', FALSE);

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
