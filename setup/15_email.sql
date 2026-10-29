-- =====================================================================================
-- 15_email.sql  ·  Wilderness Outfitters workshop
-- The email integration and the report email procedure, used by the report skill in
-- Lab 1 optional Step 10. Reports only ever go to the email on your own Snowflake user.
-- =====================================================================================
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WILDERNESS_WH;

-- Settings the setup writes once: the address reports go to.
CREATE TABLE IF NOT EXISTS WILDERNESS_HOL.SETUP.WORKSHOP_SETTINGS (KEY VARCHAR, VALUE VARCHAR);

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
    CALL WILDERNESS_HOL.SETUP.LOG_STEP('EMAIL', 'NO_EMAIL_ON_USER', NULL);
    RETURN 'No valid email on your Snowflake user. Add one under Settings, then run this file again.';
  END IF;
  MERGE INTO WILDERNESS_HOL.SETUP.WORKSHOP_SETTINGS t USING (SELECT 'REPORT_EMAIL' AS KEY, :v_email AS VALUE) s
    ON t.KEY = s.KEY
    WHEN MATCHED THEN UPDATE SET VALUE = s.VALUE
    WHEN NOT MATCHED THEN INSERT (KEY, VALUE) VALUES (s.KEY, s.VALUE);
  EXECUTE IMMEDIATE 'CREATE OR REPLACE NOTIFICATION INTEGRATION WILDERNESS_EMAIL TYPE = EMAIL ENABLED = TRUE '
                 || 'ALLOWED_RECIPIENTS = (''' || :v_email || ''') '
                 || 'COMMENT = ''Wilderness workshop: reports to your own email only''';
  CALL WILDERNESS_HOL.SETUP.LOG_STEP('EMAIL', 'OK', NULL);
  RETURN 'Email set up for ' || v_email;
END;
$$;

CREATE OR REPLACE PROCEDURE WILDERNESS_HOL.LAB1_ASSISTANT.SEND_REPORT_EMAIL(SUBJECT VARCHAR, HTML_BODY VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
COMMENT = 'Emails an HTML report to your own email address. It takes no recipient, so it cannot send anywhere else.'
AS
$$
DECLARE
  v_email VARCHAR;
BEGIN
  SELECT MAX(VALUE) INTO :v_email FROM WILDERNESS_HOL.SETUP.WORKSHOP_SETTINGS WHERE KEY = 'REPORT_EMAIL';
  IF (v_email IS NULL) THEN
    RETURN 'Not sent: email is not set up. Run setup/15_email.sql again.';
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

CALL WILDERNESS_HOL.SETUP.LOG_STEP('REPORT_EMAIL', 'OK', NULL);
